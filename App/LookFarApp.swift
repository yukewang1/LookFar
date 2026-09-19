import SwiftUI

@main
struct LookFarApp: App {
    @State private var store = AppStore()
    @State private var subscriptions = SubscriptionManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(store: store, subscriptions: subscriptions)
                .preferredColorScheme(.dark)
                .tint(AppTheme.sage)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        store.reconcile()
                        Task { await subscriptions.refreshEntitlements() }
                    }
                }
                .task { await subscriptions.refreshEntitlements() }
        }
    }
}

struct RootView: View {
    @Bindable var store: AppStore
    let subscriptions: SubscriptionManager
    @State private var tab = 0
    @State private var showSettings = false

    var body: some View {
        Group {
            if store.state.onboardingComplete {
                TabView(selection: $tab) {
                    TodayView(store: store, openSettings: { showSettings = true }, openProgress: { tab = 1 })
                        .tabItem { Label("Today", systemImage: "house.fill") }.tag(0)
                    ProgressView(store: store)
                        .tabItem { Label("Progress", systemImage: "chart.bar.fill") }.tag(1)
                    LearnView()
                        .tabItem { Label("Learn", systemImage: "book") }.tag(2)
                }
                .toolbarBackground(AppTheme.background, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .sheet(isPresented: $showSettings) {
                    SettingsView(store: store, subscriptions: subscriptions)
                }
            } else {
                OnboardingView(store: store)
            }
        }
        .background(AppTheme.background)
        .foregroundStyle(AppTheme.cream)
        .fullScreenCover(isPresented: $store.isBreakPresented) { BreakView(store: store) }
        .sheet(isPresented: $store.showPause) { PauseView(store: store) }
        .alert("Something needs attention", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }
}
