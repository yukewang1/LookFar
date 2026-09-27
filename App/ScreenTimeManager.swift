import Combine
import FamilyControls
import Foundation
import Observation
import UIKit

@MainActor @Observable
final class ScreenTimeManager {
    var selection = FamilyActivitySelection()
    private(set) var isAuthorized = false {
        didSet {
            if oldValue && !isAuthorized { onAuthorizationLost?() }
        }
    }
    @ObservationIgnored var onAuthorizationLost: (() -> Void)?
    private(set) var isResolvingAuthorization = false
    private(set) var isEnabled = false
    private(set) var hasPendingBreak = false
    private(set) var usageMinutes = 20
    private(set) var restSeconds = 20
    var errorMessage: String?
    @ObservationIgnored private var authorizationObserver: AnyCancellable?
    #if DEBUG
    private let authorizationFixture = AuthorizationFixture.current
    @ObservationIgnored private var foregroundObserver: AnyCancellable?
    @ObservationIgnored private var fixtureHasBackgrounded = false
    @ObservationIgnored private var fixturePendingBreakAt: Date?
    #endif

    var isUsingTestAuthorization: Bool {
        #if DEBUG
        authorizationFixture != nil
        #else
        false
        #endif
    }
    var isAvailable: Bool { isUsingTestAuthorization || ScreenTimeSupport.isAvailable }
    var monitorsAllApps: Bool {
        selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
    }
    var selectionSummary: String { monitorsAllApps ? "All eligible apps" : "Selected apps and websites" }

    init() {
        #if DEBUG
        if let authorizationFixture {
            isAuthorized = authorizationFixture == .approved || authorizationFixture == .revokedOnForeground
            isEnabled = isAuthorized
            hasPendingBreak = isAuthorized && ProcessInfo.processInfo.arguments.contains("--ui-testing-pending-break")
            if ProcessInfo.processInfo.arguments.contains("--ui-testing-delayed-break") {
                fixturePendingBreakAt = Date.now.addingTimeInterval(5)
            }
            isResolvingAuthorization = authorizationFixture == .restoringApproved
            if authorizationFixture == .revokedOnForeground {
                foregroundObserver = NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
                    .merge(with: NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification))
                    .sink { [weak self] notification in
                        guard let self else { return }
                        if notification.name == UIApplication.didEnterBackgroundNotification {
                            fixtureHasBackgrounded = true
                        } else if fixtureHasBackgrounded {
                            isAuthorized = false
                            refresh()
                        }
                    }
            }
            return
        }
        #endif
        if isAvailable {
            isResolvingAuthorization = AuthorizationCenter.shared.authorizationStatus == .notDetermined
        }
        refresh()
        if isAvailable {
            authorizationObserver = AuthorizationCenter.shared.$authorizationStatus
                .removeDuplicates()
                .dropFirst()
                // Published emits before its property changes. Read the settled value on the main queue.
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.refresh() }
        }
    }

    func resolveExistingAuthorization() async {
        guard isResolvingAuthorization else { return }
        #if DEBUG
        if authorizationFixture == .restoringApproved {
            do { try await Task.sleep(for: .milliseconds(500)) }
            catch { return } // A canceled view task must not resolve the fixture's access.
        }
        #endif
        await requestAuthorization()
    }

    func requestAuthorization() async {
        #if DEBUG
        if let authorizationFixture {
            isAuthorized = authorizationFixture != .denied
            isResolvingAuthorization = false
            if authorizationFixture == .restoringApproved { isEnabled = true }
            errorMessage = isAuthorized ? nil : "Screen Time access was denied. Allow access to continue."
            refresh()
            return
        }
        #endif
        guard isAvailable else {
            errorMessage = ScreenTimeFailure.simulator.localizedDescription
            return
        }
        MonitoringDiagnostics.record("authorization.request")
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            try ScreenTimeSupport.clearError()
        } catch {
            report(error)
        }
        isResolvingAuthorization = false
        MonitoringDiagnostics.record("authorization.result", "\(AuthorizationCenter.shared.authorizationStatus)")
        refresh()
    }

    func saveSelection() {
        if isUsingTestAuthorization { return }
        do {
            var config = try ScreenTimeSupport.load()
            config.selection = selection
            try ScreenTimeSupport.save(config)
            if config.enabled { try ScreenTimeSupport.rearm(reason: "App selection changed") }
            refresh()
        } catch {
            refresh()
            report(error)
        }
    }

    func saveRhythm(usageMinutes: Int, restSeconds: Int) throws {
        guard (5...120).contains(usageMinutes), (5...120).contains(restSeconds) else {
            let error = ScreenTimeFailure.invalidRhythm
            report(error)
            throw error
        }
        if isUsingTestAuthorization {
            self.usageMinutes = usageMinutes
            self.restSeconds = restSeconds
            errorMessage = nil
            return
        }
        do {
            var config = try ScreenTimeSupport.load()
            config.useMinutes = usageMinutes
            config.restSeconds = restSeconds
            try ScreenTimeSupport.save(config)
            if config.enabled { try ScreenTimeSupport.rearm(reason: "Break timing changed", preservingPendingBreak: true) }
            refresh()
        } catch {
            refresh()
            report(error)
            throw error
        }
    }

    func setEnabled(_ enabled: Bool, usageMinutes: Int) throws {
        refreshAuthorization()
        if enabled && (isResolvingAuthorization || !isAuthorized) {
            let error = ScreenTimeFailure.notAuthorized
            report(error)
            throw error
        }
        if isUsingTestAuthorization {
            isEnabled = enabled
            hasPendingBreak = false
            errorMessage = nil
            return
        }
        do {
            if enabled {
                var config = try ScreenTimeSupport.load()
                config.selection = selection
                config.enabled = true
                try ScreenTimeSupport.save(config)
                try ScreenTimeSupport.rearm(reason: "Automatic pauses enabled", useMinutes: usageMinutes)
            } else {
                try ScreenTimeSupport.stop()
                try ScreenTimeSupport.clearError()
            }
            refresh()
        } catch {
            refresh()
            report(error)
            throw error
        }
    }

    func beginBreak(deadline: Date) throws {
        if isUsingTestAuthorization { return }
        do {
            var config = try ScreenTimeSupport.load()
            // Use the saved session's deadline even if persisting the session took time.
            // A later deadline could leave the shield active after the local timer finishes.
            config.breakDeadline = deadline
            try ScreenTimeSupport.save(config)
            MonitoringDiagnostics.record("break.started", "deadline=\(deadline.ISO8601Format())")
        } catch {
            report(error)
            throw error
        }
    }

    func resetCycle(usageMinutes: Int, reason: String, onlyIfRestExpired: Bool = false) throws {
        if isUsingTestAuthorization {
            hasPendingBreak = false
            return
        }
        do {
            try ScreenTimeSupport.rearm(reason: reason, useMinutes: usageMinutes, onlyIfRestExpired: onlyIfRestExpired)
            refresh()
        } catch {
            refresh()
            report(error)
            throw error
        }
    }

    func release() {
        if isUsingTestAuthorization {
            isEnabled = false
            hasPendingBreak = false
            errorMessage = nil
            return
        }
        do {
            try ScreenTimeSupport.stop()
            try ScreenTimeSupport.clearError()
            refresh()
        } catch {
            ScreenTimeSupport.clearShield()
            isEnabled = false
            hasPendingBreak = false
            report(error)
        }
    }

    func refreshAuthorization() {
        guard !isUsingTestAuthorization else { return }
        guard isAvailable else {
            isResolvingAuthorization = false
            isAuthorized = false
            return
        }
        // An unknown startup value isn't evidence that previously granted access was revoked.
        guard !isResolvingAuthorization else { return }
        let status = AuthorizationCenter.shared.authorizationStatus
        isAuthorized = status == .approved || status == .approvedWithDataAccess
    }

    func refresh() {
        if isUsingTestAuthorization {
            if !isAuthorized {
                isEnabled = false
                hasPendingBreak = false
            }
            return
        }
        refreshAuthorization()
        guard !isResolvingAuthorization else { return }
        do {
            var config = try ScreenTimeSupport.load()
            if config.enabled && !isAuthorized {
                try ScreenTimeSupport.stop()
                config = try ScreenTimeSupport.load()
            }
            try ScreenTimeSupport.upgradeMonitoringIfNeeded()
            config = try ScreenTimeSupport.load()
            if let deadline = config.breakDeadline, deadline <= .now {
                try ScreenTimeSupport.rearm(reason: "Rest deadline elapsed on app refresh")
                config = try ScreenTimeSupport.load()
            }
            selection = config.selection
            isEnabled = config.enabled
            hasPendingBreak = config.pendingBreak
            usageMinutes = config.useMinutes
            restSeconds = config.restSeconds
            errorMessage = try ScreenTimeSupport.lastError()
        } catch {
            ScreenTimeSupport.clearShield()
            isEnabled = false
            hasPendingBreak = false
            report(error)
        }
    }

    /// Read extension state without re-registering or resetting the usage cycle.
    func refreshPendingBreak() {
        #if DEBUG
        if isUsingTestAuthorization {
            if let fixturePendingBreakAt, fixturePendingBreakAt <= .now, isEnabled {
                hasPendingBreak = true
                self.fixturePendingBreakAt = nil
            }
            return
        }
        #endif
        do {
            let config = try ScreenTimeSupport.load()
            isEnabled = config.enabled
            hasPendingBreak = config.enabled && config.pendingBreak
            errorMessage = try ScreenTimeSupport.lastError()
        } catch { report(error) }
    }

    func pendingSkippedBreaks() throws -> [ShieldSkipEvent] {
        if isUsingTestAuthorization { return [] }
        do { return try ScreenTimeSupport.pendingSkippedBreaks() }
        catch {
            report(error)
            throw error
        }
    }

    func acknowledgeSkippedBreaks(ids: Set<UUID>) throws {
        if isUsingTestAuthorization { return }
        do { try ScreenTimeSupport.acknowledgeSkippedBreaks(ids: ids) }
        catch {
            report(error)
            throw error
        }
    }

    private func report(_ error: Error) {
        errorMessage = error.localizedDescription
        if !isUsingTestAuthorization { ScreenTimeSupport.recordFailure(error) }
    }
}

#if DEBUG
private enum AuthorizationFixture: String {
    case approved, denied, notDetermined
    case revokedOnForeground = "revoked-on-foreground"
    case restoringApproved = "restoring-approved"

    static var current: Self? {
        let arguments = ProcessInfo.processInfo.arguments
        let prefix = "--ui-testing-screen-time="
        guard arguments.contains("--ui-testing"),
              let flag = arguments.first(where: { $0.hasPrefix(prefix) }) else { return nil }
        return Self(rawValue: String(flag.dropFirst(prefix.count)))
    }
}
#endif
