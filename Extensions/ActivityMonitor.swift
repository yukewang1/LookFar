import DeviceActivity
import Foundation

final class ActivityMonitor: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        MonitoringDiagnostics.record("usage.callback", "cycle=\(activity.rawValue); event=\(event.rawValue)")
        do {
            var config = try ScreenTimeSupport.load()
            guard config.enabled, config.activityName == activity.rawValue else {
                MonitoringDiagnostics.record("usage.ignored", "Disabled or stale cycle; current=\(config.activityName ?? "none")")
                return
            }
            // System-delivered callbacks must not be gated on the extension's uninitialized
            // AuthorizationCenter. The containing app requests access and iOS enforces it.
            guard let minutes = ScreenTimeSupport.usageMinutes(for: event, limit: config.useMinutes) else {
                MonitoringDiagnostics.record("usage.ignored", "Unknown event")
                return
            }
            var tracker = try ScreenTimeSupport.loadUsageGapTracker(for: activity)
            let action = config.recordUsageCheckpoint(minutes: minutes, at: .now, tracker: &tracker)
            MonitoringDiagnostics.record("usage.decision", "cycle=\(activity.rawValue); minute=\(minutes); action=\(action); pending=\(config.pendingBreak); deadline=\(config.breakDeadline?.ISO8601Format() ?? "none")")
            switch action {
            case .ignore:
                return
            case .save:
                try ScreenTimeSupport.saveUsageGapTracker(tracker, for: activity)
            case .restart:
                // Check the estimated gap before shielding, including at the final usage threshold.
                try ScreenTimeSupport.rearm(reason: config.breakDeadline == nil ? "Estimated usage gap" : "Rest deadline elapsed", afterCheckpointIn: activity)
            case .shield:
                try ScreenTimeSupport.save(config)
                ScreenTimeSupport.applyShield(for: config)
            }
        } catch {
            ScreenTimeSupport.clearShield()
            ScreenTimeSupport.recordFailure(error)
        }
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        MonitoringDiagnostics.record("interval.start", "cycle=\(activity.rawValue)")
        reconcileBreak(for: activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        MonitoringDiagnostics.record("interval.end", "cycle=\(activity.rawValue)")
        reconcileBreak(for: activity)
    }

    private func reconcileBreak(for activity: DeviceActivityName) {
        do {
            let config = try ScreenTimeSupport.load()
            guard config.activityName == activity.rawValue else { return }
            if !config.enabled {
                try ScreenTimeSupport.clearPendingBreak()
            } else if let deadline = config.breakDeadline, deadline <= .now {
                try ScreenTimeSupport.rearm(reason: "Rest deadline elapsed at interval callback")
            }
        } catch {
            ScreenTimeSupport.clearShield()
            ScreenTimeSupport.recordFailure(error)
        }
    }
}
