import DeviceActivity
import Foundation

final class ActivityMonitor: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        guard event == ScreenTimeSupport.thresholdEvent else { return }
        do {
            var config = try ScreenTimeSupport.load()
            guard config.enabled, config.activityName == activity.rawValue else { return }
            guard config.isWithinActiveHours(), ScreenTimeSupport.isAuthorized else {
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
        clearBreak(for: activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        clearBreak(for: activity)
    }

    private func clearBreak(for activity: DeviceActivityName) {
        do {
            let config = try ScreenTimeSupport.load()
            guard config.activityName == activity.rawValue else { return }
            try ScreenTimeSupport.clearPendingBreak()
        } catch {
            ScreenTimeSupport.clearShield()
            ScreenTimeSupport.recordFailure(error)
        }
    }
}
