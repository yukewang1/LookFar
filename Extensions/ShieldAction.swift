import Foundation
import ManagedSettings

final class LookFarShieldAction: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler: completionHandler)
    }

    private func respond(to action: ShieldAction, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        do {
            if action == .secondaryButtonPressed {
                try ScreenTimeSupport.skipBreak()
                completionHandler(.none)
                return
            }

            let config = try ScreenTimeSupport.load()
            if !config.enabled || !config.isWithinActiveHours() || !ScreenTimeSupport.isAuthorized {
                try ScreenTimeSupport.clearPendingBreak()
                completionHandler(.none)
            } else if let deadline = config.breakDeadline, deadline <= .now {
                try ScreenTimeSupport.rearm()
                completionHandler(.none)
            } else {
                completionHandler(.openParentalControlsApp)
            }
        } catch {
            ScreenTimeSupport.clearShield()
            ScreenTimeSupport.recordFailure(error)
            completionHandler(.none)
        }
    }
}
