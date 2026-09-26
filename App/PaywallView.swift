import SwiftUI

struct PaywallView: View {
    var onContinue: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Look Far Plus")
                .font(AppTheme.title(38))
            Text("Coming soon. Free for now.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondary)
                .accessibilityIdentifier("paywallPlaceholder")
            Spacer()
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PrimaryButton(title: "Continue") {
                if let onContinue { onContinue() }
                else { dismiss() }
            }
            .accessibilityIdentifier("paywallContinue")
            .padding(.horizontal, 26).padding(.top, 14).padding(.bottom, 12)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
            .background(AppTheme.background)
        }
        .background(AppTheme.background)
        .foregroundStyle(AppTheme.cream)
        .preferredColorScheme(.dark)
    }
}
