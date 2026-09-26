import SwiftUI

@main
struct LookFarApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .preferredColorScheme(.dark)
                .tint(AppTheme.sage)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        store.reconcile()
                    }
                }
        }
    }
}

struct RootView: View {
    @Bindable var store: AppStore
    @State private var tab = 0
    @State private var showSettings = false

    var body: some View {
        Group {
            if store.state.onboardingComplete && store.monitoring.isResolvingAuthorization {
                SwiftUI.ProgressView("Checking Screen Time…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.state.onboardingComplete && !store.monitoring.isAuthorized {
                ScreenTimeAccessView(store: store, onConnected: {})
            } else if store.state.onboardingComplete {
                TabView(selection: $tab) {
                    TodayView(store: store, openSettings: { showSettings = true }, openProgress: { tab = 1 })
                        .tabItem { Label("Today", systemImage: "tree.fill") }.tag(0)
                    ProgressView(store: store)
                        .tabItem { Label("Progress", systemImage: "chart.bar.fill") }.tag(1)
                    LearnView()
                        .tabItem { Label("Learn", systemImage: "book") }.tag(2)
                }
                .toolbarBackground(AppTheme.background, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .sheet(isPresented: $showSettings) {
                    SettingsView(store: store)
                }
            } else {
                OnboardingView(store: store)
            }
        }
        .background(AppTheme.background)
        .foregroundStyle(AppTheme.cream)
        .task { await store.resolveScreenTimeAuthorization() }
        .onChange(of: store.monitoring.isAuthorized) { _, authorized in
            if !authorized { showSettings = false }
        }
        .fullScreenCover(isPresented: $store.isBreakPresented, onDismiss: { store.breakCompleted = false }) {
            BreakView(store: store)
        }
        .sheet(isPresented: $store.showPause) { PauseView(store: store) }
        .alert("Something needs attention", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }
}
