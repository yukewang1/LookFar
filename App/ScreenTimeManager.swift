import FamilyControls
import Foundation
import Observation

@MainActor @Observable
final class ScreenTimeManager {
    var selection = FamilyActivitySelection()
    private(set) var isAuthorized = false
    private(set) var isEnabled = false
    private(set) var hasPendingBreak = false
    var errorMessage: String?
    var startHour = 8
    var endHour = 22
    var isAvailable: Bool { ScreenTimeSupport.isAvailable }

    init() { refresh() }

    func requestAuthorization() async {
        guard isAvailable else {
            errorMessage = ScreenTimeFailure.simulator.localizedDescription
            return
        }
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            try ScreenTimeSupport.clearError()
            refresh()
        } catch {
            report(error)
        }
    }

    func saveSelection() {
        do {
            var config = try ScreenTimeSupport.load()
            config.selection = selection
            try ScreenTimeSupport.save(config)
            if config.enabled { try ScreenTimeSupport.rearm() }
            refresh()
        } catch {
            refresh()
            report(error)
        }
    }

    func saveSchedule() throws {
        guard (0...23).contains(startHour), (1...24).contains(endHour), startHour < endHour else {
            let error = ScreenTimeFailure.invalidSchedule
            report(error)
            throw error
        }
        do {
            var config = try ScreenTimeSupport.load()
            config.startHour = startHour
            config.endHour = endHour
            try ScreenTimeSupport.save(config)
            if config.enabled { try ScreenTimeSupport.rearm() }
            refresh()
        } catch {
            refresh()
            report(error)
            throw error
        }
    }

    func setEnabled(_ enabled: Bool, usageMinutes: Int) throws {
        do {
            if enabled {
                var config = try ScreenTimeSupport.load()
                config.selection = selection
                config.startHour = startHour
                config.endHour = endHour
                config.enabled = true
                try ScreenTimeSupport.save(config)
                try ScreenTimeSupport.rearm(useMinutes: usageMinutes)
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

    func beginBreak(duration: TimeInterval) throws {
        do {
            var config = try ScreenTimeSupport.load()
            config.breakDeadline = Date.now.addingTimeInterval(duration)
            try ScreenTimeSupport.save(config)
        } catch {
            report(error)
            throw error
        }
    }

    func resetCycle(usageMinutes: Int) throws {
        do {
            try ScreenTimeSupport.rearm(useMinutes: usageMinutes)
            refresh()
        } catch {
            refresh()
            report(error)
            throw error
        }
    }

    func release() {
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

    func refresh() {
        isAuthorized = ScreenTimeSupport.isAuthorized
        do {
            var config = try ScreenTimeSupport.load()
            if config.enabled && !isAuthorized {
                try ScreenTimeSupport.stop()
                config = try ScreenTimeSupport.load()
            } else if !config.isWithinActiveHours() && config.pendingBreak {
                try ScreenTimeSupport.clearPendingBreak()
                config = try ScreenTimeSupport.load()
            } else if let deadline = config.breakDeadline, deadline <= .now {
                try ScreenTimeSupport.rearm()
                config = try ScreenTimeSupport.load()
            }
            selection = config.selection
            isEnabled = config.enabled
            hasPendingBreak = config.pendingBreak
            startHour = config.startHour
            endHour = config.endHour
            errorMessage = try ScreenTimeSupport.lastError()
        } catch {
            ScreenTimeSupport.clearShield()
            isEnabled = false
            hasPendingBreak = false
            report(error)
        }
    }

    func pendingSkippedBreaks() throws -> [ShieldSkipEvent] {
        do { return try ScreenTimeSupport.pendingSkippedBreaks() }
        catch {
            report(error)
            throw error
        }
    }

    func acknowledgeSkippedBreaks(ids: Set<UUID>) throws {
        do { try ScreenTimeSupport.acknowledgeSkippedBreaks(ids: ids) }
        catch {
            report(error)
            throw error
        }
    }

    private func report(_ error: Error) {
        errorMessage = error.localizedDescription
        ScreenTimeSupport.recordFailure(error)
    }
}
