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

struct UsageCheckpointState: Codable {
    let activityName: String
    var tracker: UsageGapTracker

    func tracker(for activityName: String) -> UsageGapTracker {
        self.activityName == activityName ? tracker : UsageGapTracker()
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
    var registrationVersion = 0

    var monitorsAllApps: Bool {
        selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case selection, useMinutes, restSeconds, enabled, pendingBreak, breakDeadline, activityName, registrationVersion
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
        registrationVersion = try container.decodeIfPresent(Int.self, forKey: .registrationVersion) ?? 0
    }

    enum CheckpointAction {
        case ignore, save, restart, shield
    }

    mutating func recordUsageCheckpoint(minutes: Int, at date: Date, tracker: inout UsageGapTracker) -> CheckpointAction {
        guard enabled, minutes > 0, minutes <= useMinutes else { return .ignore }
        if let breakDeadline { return breakDeadline <= date ? .restart : .ignore }
        guard !pendingBreak else { return .ignore }
        switch tracker.record(usageMinutes: minutes, at: date) {
        case .ignored:
            return .ignore
        case .reset:
            return .restart
        case .continued:
            if minutes == useMinutes {
                pendingBreak = true
                return .shield
            }
            return .save
        }
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
    static let registrationVersion = 1
    static let appGroup = "group.dev.local.lookfar"
    static let activityPrefix = "lookfar.cycle."
    static let thresholdEvent = DeviceActivityEvent.Name("lookfar.break-due")
    private static let checkpointPrefix = "lookfar.usage-minute."
    private static let configKey = "lookfar.monitoring-config"
    private static let checkpointKey = "lookfar.usage-checkpoint"
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

    static func loadUsageGapTracker(for activity: DeviceActivityName) throws -> UsageGapTracker {
        guard let data = try defaults().data(forKey: checkpointKey) else { return UsageGapTracker() }
        let state = try JSONDecoder().decode(UsageCheckpointState.self, from: data)
        return state.tracker(for: activity.rawValue)
    }

    static func saveUsageGapTracker(_ tracker: UsageGapTracker, for activity: DeviceActivityName) throws {
        // Frequent checkpoints must not overwrite preferences or a concurrently started rest.
        let state = UsageCheckpointState(activityName: activity.rawValue, tracker: tracker)
        try defaults().set(JSONEncoder().encode(state), forKey: checkpointKey)
    }

    static func lastError() throws -> String? { try defaults().string(forKey: errorKey) }

    static func recordFailure(_ error: Error) {
        logger.error("\(error.localizedDescription, privacy: .public)")
        let nsError = error as NSError
        MonitoringDiagnostics.record("error", "\(nsError.domain) (\(nsError.code)): \(error.localizedDescription)")
        // Keep the error readable even when the encoded configuration cannot be decoded.
        UserDefaults(suiteName: appGroup)?.set(error.localizedDescription, forKey: errorKey)
    }

    static func clearError() throws { try defaults().removeObject(forKey: errorKey) }

    static func clearShield() {
        guard isAvailable else { return }
        MonitoringDiagnostics.record("shield.clear")
        ManagedSettingsStore(named: .init("lookfar.break")).clearAllSettings()
    }

    private static func stopActivities() {
        guard isAvailable else { return }
        let center = DeviceActivityCenter()
        center.stopMonitoring(center.activities.filter { $0.rawValue.hasPrefix(activityPrefix) })
    }

    static func stop() throws {
        MonitoringDiagnostics.record("monitoring.stop")
        clearShield()
        defer { stopActivities() }
        var config = try load()
        config.enabled = false
        config.pendingBreak = false
        config.breakDeadline = nil
        config.activityName = nil
        try save(config)
    }

    static func upgradeMonitoringIfNeeded() throws {
        guard isAvailable else { return }
        let config = try load()
        guard config.enabled else { return }
        let center = DeviceActivityCenter()
        let activity = config.activityName.map { DeviceActivityName($0) }
        let schedule = activity.flatMap { center.schedule(for: $0) }
        let events = activity.map { center.events(for: $0) }
        guard config.registrationVersion != registrationVersion
                || schedule != allDaySchedule || events != monitoringEvents(for: config) else { return }
        // Build 2 may have consumed and discarded today's thresholds. Register once again
        // after the fix so those callbacks do not have to wait until the following day.
        try rearm(reason: "Registration missing, outdated, or configuration changed", preservingPendingBreak: true)
    }

    static func monitoringEvents(for config: MonitoringConfig) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        guard config.useMinutes > 0 else { return [:] }
        return Dictionary(uniqueKeysWithValues: (1...config.useMinutes).map { minute in
            let name = minute == config.useMinutes ? thresholdEvent : DeviceActivityEvent.Name(checkpointPrefix + String(minute))
            // Every checkpoint measures the same eligible activity from the start of this cycle.
            let event = DeviceActivityEvent(
                applications: config.selection.applicationTokens,
                categories: config.selection.categoryTokens,
                webDomains: config.selection.webDomainTokens,
                threshold: DateComponents(minute: minute),
                includesPastActivity: false
            )
            return (name, event)
        })
    }

    static func usageMinutes(for event: DeviceActivityEvent.Name, limit: Int) -> Int? {
        if event == thresholdEvent { return limit > 0 ? limit : nil }
        guard event.rawValue.hasPrefix(checkpointPrefix),
              let minute = Int(event.rawValue.dropFirst(checkpointPrefix.count)),
              minute > 0, minute < limit else { return nil }
        return minute
    }

    static func rearm(reason: String, useMinutes: Int? = nil, preservingPendingBreak: Bool = false, afterCheckpointIn activity: DeviceActivityName? = nil, onlyIfRestExpired: Bool = false) throws {
        var config = try load()
        if onlyIfRestExpired {
            // An extension may already have finished this rest and started the next cycle.
            // Completing the older local session must not erase new usage or a new prompt.
            guard let deadline = config.breakDeadline, deadline <= .now else { return }
        }
        if let activity {
            guard config.enabled, config.activityName == activity.rawValue else { return }
            if let deadline = config.breakDeadline {
                guard deadline <= .now else { return }
            } else if config.pendingBreak {
                return
            }
        }
        MonitoringDiagnostics.record("cycle.rearm", "\(reason); previous=\(config.activityName ?? "none"); preserveBreak=\(preservingPendingBreak)")
        if !preservingPendingBreak { clearShield() }
        if let useMinutes { config.useMinutes = useMinutes }
        if !preservingPendingBreak {
            config.pendingBreak = false
            config.breakDeadline = nil
        }
        config.activityName = nil
        try save(config)
        MonitoringDiagnostics.record("monitoring.stop-existing")
        stopActivities()

        guard config.enabled else { return }
        do {
            guard isAvailable else { throw ScreenTimeFailure.simulator }
            guard config.useMinutes > 0 else { throw ScreenTimeFailure.invalidInterval }
            let name = DeviceActivityName(activityPrefix + UUID().uuidString)
            config.activityName = name.rawValue
            config.registrationVersion = registrationVersion
            // Persist the generation before registration: callbacks can arrive immediately.
            try save(config)
            // AuthorizationCenter starts at .notDetermined in each process, including extensions.
            // The app requests access; startMonitoring enforces it and throws .unauthorized.
            MonitoringDiagnostics.record("monitoring.register", "cycle=\(name.rawValue); minutes=\(config.useMinutes); allApps=\(config.monitorsAllApps); events=\(config.useMinutes); includesPastActivity=false")
            try DeviceActivityCenter().startMonitoring(name, during: allDaySchedule, events: monitoringEvents(for: config))
            MonitoringDiagnostics.record("monitoring.registered", "cycle=\(name.rawValue)")
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
        MonitoringDiagnostics.record("shield.apply", "cycle=\(config.activityName ?? "none"); allApps=\(config.monitorsAllApps)")
        guard isAvailable else { return }
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
        MonitoringDiagnostics.record("break.clear-pending")
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
        try rearm(reason: "Skipped from shield")
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
