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
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: paper,
            icon: UIImage(systemName: "leaf"),
            title: .init(text: "Look Far", color: ink),
            subtitle: .init(text: "A little room for your eyes.\n\nYour selected apps have reached your routine’s usage interval. Take a moment to look into the distance.", color: ink),
            primaryButtonLabel: .init(text: "Take an eye break", color: paper),
            primaryButtonBackgroundColor: ink,
            secondaryButtonLabel: .init(text: "Skip this break · release apps", color: ink)
        )
    }
}
