import ManagedSettings
import ManagedSettingsUI
import UIKit

final class LookFarShieldConfiguration: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration { makeConfiguration() }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { makeConfiguration() }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { makeConfiguration() }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { makeConfiguration() }

    private func makeConfiguration() -> ShieldConfiguration {
        let ink = UIColor(red: 0.13, green: 0.21, blue: 0.18, alpha: 1)
        let paper = UIColor(red: 0.97, green: 0.96, blue: 0.93, alpha: 1)
        let subtitle: String
        do {
            let config = try ScreenTimeSupport.load()
            subtitle = "A little room for your eyes.\n\nYou've had \(config.useMinutes) minutes of screen time. Look into the distance for \(config.restSeconds) seconds. We'll let you know when your rest is done."
        } catch {
            ScreenTimeSupport.recordFailure(error)
            subtitle = "A little room for your eyes.\n\nTake a moment to look into the distance. Open Look Far to start your rest."
        }
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: paper,
            icon: UIImage(systemName: "leaf"),
            title: .init(text: "Look Far", color: ink),
            subtitle: .init(text: subtitle, color: ink),
            primaryButtonLabel: .init(text: "Take an eye break", color: paper),
            primaryButtonBackgroundColor: ink,
            secondaryButtonLabel: .init(text: "Skip this break · release apps", color: ink)
        )
    }
}
