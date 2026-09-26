import DeviceActivity
import Foundation

final class ActivityMonitor: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        do {
            var config = try ScreenTimeSupport.load()
            guard config.enabled, config.activityName == activity.rawValue else { return }
            guard ScreenTimeSupport.isAuthorized else {
                try ScreenTimeSupport.clearPendingBreak()
                return
            }
            guard let minutes = ScreenTimeSupport.usageMinutes(for: event, limit: config.useMinutes) else { return }
            var tracker = try ScreenTimeSupport.loadUsageGapTracker(for: activity)
            switch config.recordUsageCheckpoint(minutes: minutes, at: .now, tracker: &tracker) {
            case .ignore:
                return
            case .save:
                try ScreenTimeSupport.saveUsageGapTracker(tracker, for: activity)
            case .restart:
                // Check the estimated gap before shielding, including at the final usage threshold.
                try ScreenTimeSupport.rearm(afterCheckpointIn: activity)
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
        reconcileBreak(for: activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        reconcileBreak(for: activity)
    }

    private func reconcileBreak(for activity: DeviceActivityName) {
        do {
            let config = try ScreenTimeSupport.load()
            guard config.activityName == activity.rawValue else { return }
            if !config.enabled || !ScreenTimeSupport.isAuthorized {
                try ScreenTimeSupport.clearPendingBreak()
            } else if let deadline = config.breakDeadline, deadline <= .now {
                try ScreenTimeSupport.rearm()
            }
        } catch {
            ScreenTimeSupport.clearShield()
            ScreenTimeSupport.recordFailure(error)
        }
    }
}
