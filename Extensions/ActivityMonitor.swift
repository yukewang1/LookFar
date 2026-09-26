import DeviceActivity
import Foundation

final class ActivityMonitor: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        guard event == ScreenTimeSupport.thresholdEvent else { return }
        do {
            var config = try ScreenTimeSupport.load()
            guard config.enabled, config.activityName == activity.rawValue else { return }
            guard ScreenTimeSupport.isAuthorized else {
                try ScreenTimeSupport.clearPendingBreak()
                return
            }
            guard !config.pendingBreak else { return }
            config.pendingBreak = true
            config.breakDeadline = nil
            try ScreenTimeSupport.save(config)
            ScreenTimeSupport.applyShield(for: config)
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
