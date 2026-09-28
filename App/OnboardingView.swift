import SwiftUI

struct OnboardingView: View {
    @Bindable var store: AppStore
    @State private var stage = Stage.introduction
    @State private var startedIntro = false

    private enum Stage { case introduction, permission, membership }

    init(store: AppStore) {
        self.store = store
        _startedIntro = State(initialValue: store.isBreakPresented)
    }

    var body: some View {
        Group {
            if stage == .introduction {
                introduction
            } else if stage == .membership && store.monitoring.isAuthorized {
                PaywallView(onContinue: { store.finishOnboarding() })
            } else {
                ScreenTimeAccessView(store: store) { stage = .membership }
            }
        }
        .background(AppTheme.background).foregroundStyle(AppTheme.cream)
        .onChange(of: store.isBreakPresented) { _, presented in
            guard !presented, startedIntro else { return }
            startedIntro = false
            stage = .permission
        }
        .onChange(of: store.monitoring.isAuthorized) { wasAuthorized, authorized in
            if wasAuthorized && !authorized { stage = .permission }
        }
    }

    private var introduction: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text(Brand.name).font(AppTheme.title(28))
                    LandscapeView(height: min(230, geometry.size.height * 0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Build a habit\nfor your eyes.")
                            .font(AppTheme.title(42)).fixedSize(horizontal: false, vertical: true)
                        Text("Look Far uses Screen Time to pause your apps for regular eye breaks. Start with a 10-second taste.")
                            .foregroundStyle(AppTheme.secondary).lineSpacing(4)
                    }
                }
                .padding(.horizontal, 26).padding(.top, 20).padding(.bottom, 24)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }.scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PrimaryButton(title: "Try a 10-second break") {
                startedIntro = true
                store.startBreak(isOnboardingTrial: true)
            }
            .accessibilityIdentifier("onboardingStartRest")
            .padding(.horizontal, 26).padding(.vertical, 14)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
            .background(AppTheme.background)
        }
    }
}

struct ScreenTimeAccessView: View {
    let store: AppStore
    let onConnected: () -> Void
    @State private var isConnecting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text(Brand.name).font(AppTheme.title(28))
                Image(systemName: "hourglass.circle")
                    .font(.system(size: 64, weight: .ultraLight)).foregroundStyle(AppTheme.sage)
                    .padding(.vertical, 28).accessibilityHidden(true)
                Text("Connect\nScreen Time.")
                    .font(AppTheme.title(42)).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("screenTimeRequired")
                Text(store.monitoring.isAvailable
                     ? "Screen Time access is required for your eye-break habit. Allow access to continue."
                     : "Screen Time access is required. Open Look Far on a physical iPhone to continue.")
                    .foregroundStyle(AppTheme.secondary).lineSpacing(4)
                if store.monitoring.isAvailable {
                    Text("\(store.monitoring.selectionSummary) · 24/7")
                        .font(.footnote).foregroundStyle(AppTheme.sage)
                    if let error = store.monitoring.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(AppTheme.secondary)
                            .accessibilityIdentifier("screenTimeError")
                    }
                }
            }
            .padding(.horizontal, 26).padding(.top, 20).padding(.bottom, 24)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PrimaryButton(title: buttonTitle, action: connect)
                .disabled(isConnecting || !store.monitoring.isAvailable)
                .accessibilityIdentifier("screenTimeConnect")
                .padding(.horizontal, 26).padding(.vertical, 14)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
                .background(AppTheme.background)
        }
        .background(AppTheme.background).foregroundStyle(AppTheme.cream)
    }

    private var buttonTitle: String {
        if !store.monitoring.isAvailable { return "Use a physical iPhone" }
        if isConnecting { return "Connecting…" }
        return store.monitoring.isAuthorized ? "Continue" : "Connect Screen Time"
    }

    private func connect() {
        isConnecting = true
        Task {
            defer { isConnecting = false }
            if !store.monitoring.isAuthorized { await store.monitoring.requestAuthorization() }
            guard store.monitoring.isAuthorized else { return }
            store.monitoring.refresh()
            guard store.monitoring.isEnabled else {
                store.errorMessage = store.monitoring.errorMessage
                return
            }
            onConnected()
        }
    }

}
