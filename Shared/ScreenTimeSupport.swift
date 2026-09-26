import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import OSLog

struct ShieldSkipEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date

    init(id: UUID = UUID(), date: Date = .now) {
        self.id = id
        self.date = date
    }
}

struct MonitoringConfig: Codable {
    var selection = FamilyActivitySelection()
    var useMinutes = 20
    var restSeconds = 20
    var enabled = false
    var pendingBreak = false
    var breakDeadline: Date?
    var activityName: String?

    var monitorsAllApps: Bool {
        selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case selection, useMinutes, restSeconds, enabled, pendingBreak, breakDeadline, activityName
    }

    init() {}

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selection = try container.decode(FamilyActivitySelection.self, forKey: .selection)
        useMinutes = try container.decode(Int.self, forKey: .useMinutes)
        restSeconds = try container.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 20
        enabled = try container.decode(Bool.self, forKey: .enabled)
        pendingBreak = try container.decode(Bool.self, forKey: .pendingBreak)
        breakDeadline = try container.decodeIfPresent(Date.self, forKey: .breakDeadline)
        activityName = try container.decodeIfPresent(String.self, forKey: .activityName)
    }
}

enum ScreenTimeFailure: LocalizedError {
    case simulator, notAuthorized, invalidRhythm, invalidInterval, sharedStorageUnavailable, invalidSkipEvent

    var errorDescription: String? {
        switch self {
        case .simulator:
            return "Screen Time access requires a physical iPhone."
        case .notAuthorized:
            return "Allow Screen Time access before enabling automatic breaks."
        case .invalidRhythm:
            return "Choose 5–120 minutes of screen use and 5–120 seconds of rest."
        case .invalidInterval:
            return "The usage interval must be at least one minute."
        case .sharedStorageUnavailable:
            return "Look Far’s shared storage is unavailable. Check the App Group signing entitlement."
        case .invalidSkipEvent:
            return "A saved shield skip could not be read. Your existing history has not been changed."
        }
    }
}

enum ScreenTimeSupport {
    static let appGroup = "group.dev.local.lookfar"
    static let activityPrefix = "lookfar.cycle."
    static let thresholdEvent = DeviceActivityEvent.Name("lookfar.break-due")
    private static let configKey = "lookfar.monitoring-config"
    private static let errorKey = "lookfar.monitoring-error"
    private static let skipsPrefix = "lookfar.shield-skip."
    private static let logger = Logger(subsystem: "dev.local.lookfar", category: "ScreenTime")

    // Apple's daily schedule runs midnight to midnight: developer.apple.com/videos/play/wwdc2021/10123/.
    static var allDaySchedule: DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 0, minute: 0),
            repeats: true
        )
    }

    static var isAvailable: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }

    static var isAuthorized: Bool {
        guard isAvailable else { return false }
        let status = AuthorizationCenter.shared.authorizationStatus
        return status == .approved || status == .approvedWithDataAccess
    }

    private static func defaults() throws -> UserDefaults {
        #if !targetEnvironment(simulator)
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) != nil else {
            throw ScreenTimeFailure.sharedStorageUnavailable
        }
        #endif
        guard let defaults = UserDefaults(suiteName: appGroup) else {
            throw ScreenTimeFailure.sharedStorageUnavailable
        }
        return defaults
    }

    static func load() throws -> MonitoringConfig {
        guard let data = try defaults().data(forKey: configKey) else { return MonitoringConfig() }
        return try JSONDecoder().decode(MonitoringConfig.self, from: data)
    }

    static func save(_ config: MonitoringConfig) throws {
        let data = try JSONEncoder().encode(config)
        try defaults().set(data, forKey: configKey)
    }

    static func lastError() throws -> String? { try defaults().string(forKey: errorKey) }

    static func recordFailure(_ error: Error) {
        logger.error("\(error.localizedDescription, privacy: .public)")
        // Keep the error readable even when the encoded configuration cannot be decoded.
        UserDefaults(suiteName: appGroup)?.set(error.localizedDescription, forKey: errorKey)
    }

    static func clearError() throws { try defaults().removeObject(forKey: errorKey) }

    static func clearShield() {
        guard isAvailable else { return }
        ManagedSettingsStore(named: .init("lookfar.break")).clearAllSettings()
    }

    private static func stopActivities() {
        guard isAvailable else { return }
        let center = DeviceActivityCenter()
        center.stopMonitoring(center.activities.filter { $0.rawValue.hasPrefix(activityPrefix) })
    }

    static func stop() throws {
        clearShield()
        defer { stopActivities() }
        var config = try load()
        config.enabled = false
        config.pendingBreak = false
        config.breakDeadline = nil
        config.activityName = nil
        try save(config)
    }

    static func upgradeScheduleIfNeeded() throws {
        guard isAvailable else { return }
        let config = try load()
        guard config.enabled else { return }
        let schedule = config.activityName.flatMap { DeviceActivityCenter().schedule(for: .init($0)) }
        guard schedule != allDaySchedule else { return }
        try rearm(preservingPendingBreak: true)
    }

    static func rearm(useMinutes: Int? = nil, preservingPendingBreak: Bool = false) throws {
        if !preservingPendingBreak { clearShield() }
        var config = try load()
        if let useMinutes { config.useMinutes = useMinutes }
        if !preservingPendingBreak {
            config.pendingBreak = false
            config.breakDeadline = nil
        }
        config.activityName = nil
        try save(config)
        stopActivities()

        guard config.enabled else { return }
        do {
            guard isAvailable else { throw ScreenTimeFailure.simulator }
            guard isAuthorized else { throw ScreenTimeFailure.notAuthorized }
            guard config.useMinutes > 0 else { throw ScreenTimeFailure.invalidInterval }
            let name = DeviceActivityName(activityPrefix + UUID().uuidString)
            config.activityName = name.rawValue
            // Persist the generation before registration: callbacks can arrive immediately.
            try save(config)
            // Apple's empty token sets count all activity; selecting tokens narrows the scope.
            let event = DeviceActivityEvent(
                applications: config.selection.applicationTokens,
                categories: config.selection.categoryTokens,
                webDomains: config.selection.webDomainTokens,
                threshold: DateComponents(minute: config.useMinutes),
                includesPastActivity: false
            )
            try DeviceActivityCenter().startMonitoring(name, during: allDaySchedule, events: [thresholdEvent: event])
            try clearError()
        } catch {
            clearShield()
            config.enabled = false
            config.pendingBreak = false
            config.breakDeadline = nil
            config.activityName = nil
            try save(config)
            stopActivities()
            recordFailure(error)
            throw error
        }
    }

    static func applyShield(for config: MonitoringConfig) {
        let store = ManagedSettingsStore(named: .init("lookfar.break"))
        if config.monitorsAllApps {
            store.shield.applications = nil
            store.shield.applicationCategories = .all()
            store.shield.webDomains = nil
            store.shield.webDomainCategories = .all()
            return
        }
        store.shield.applications = config.selection.applicationTokens.isEmpty ? nil : config.selection.applicationTokens
        store.shield.applicationCategories = config.selection.categoryTokens.isEmpty ? nil : .specific(config.selection.categoryTokens)
        store.shield.webDomains = config.selection.webDomainTokens.isEmpty ? nil : config.selection.webDomainTokens
        store.shield.webDomainCategories = config.selection.categoryTokens.isEmpty ? nil : .specific(config.selection.categoryTokens)
    }

    static func clearPendingBreak() throws {
        clearShield()
        var config = try load()
        config.pendingBreak = false
        config.breakDeadline = nil
        try save(config)
    }

    /// A shield skip releases access first; monitoring errors can never prevent release.
    static func skipBreak() throws {
        clearShield()
        let defaults = try defaults()
        let event = ShieldSkipEvent()
        let data = try JSONEncoder().encode(event)
        // Separate keys let the app acknowledge an older batch without overwriting a new skip.
        defaults.set(data, forKey: skipsPrefix + event.id.uuidString)
        try rearm()
    }

    static func pendingSkippedBreaks() throws -> [ShieldSkipEvent] {
        let defaults = try defaults()
        var events: [ShieldSkipEvent] = []
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(skipsPrefix) {
            guard let data = defaults.data(forKey: key) else { throw ScreenTimeFailure.invalidSkipEvent }
            let event = try JSONDecoder().decode(ShieldSkipEvent.self, from: data)
            guard key == skipsPrefix + event.id.uuidString else { throw ScreenTimeFailure.invalidSkipEvent }
            events.append(event)
        }
        return events.sorted { $0.date < $1.date }
    }

    static func acknowledgeSkippedBreaks(ids: Set<UUID>) throws {
        let defaults = try defaults()
        for id in ids { defaults.removeObject(forKey: skipsPrefix + id.uuidString) }
    }
}
