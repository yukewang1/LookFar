import SwiftUI
import FamilyControls

struct SettingsView: View {
    @Bindable var store: AppStore
    let subscriptions: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var showPicker = false
    @State private var showRoutine = false
    @State private var showPaywall = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { showRoutine = true } label: {
                        HStack { Text("Break routine"); Spacer(); Text(store.state.routine.title).foregroundStyle(AppTheme.secondary) }
                    }
                    Toggle("End sound", isOn: Binding(get: { store.soundEnabled }, set: { store.setSound($0) }))
                    Button(store.notificationPermission ? "End notifications are enabled" : "Enable end notifications") {
                        Task { await store.requestNotifications() }
                    }.disabled(store.notificationPermission)
                } header: { Text("Your rhythm") }

                Section {
                    if store.monitoring.isAvailable {
                        Button(store.monitoring.isAuthorized ? "Screen Time connected" : "Connect Screen Time") {
                            Task { await store.monitoring.requestAuthorization() }
                        }.disabled(store.monitoring.isAuthorized)
                        Button("Choose apps") { showPicker = true }.disabled(!store.monitoring.isAuthorized)
                        Toggle("Pause selected apps", isOn: Binding(get: { store.monitoring.isEnabled }, set: { enabled in
                            do { try store.monitoring.setEnabled(enabled, usageMinutes: store.state.routine.usageMinutes) }
                            catch { store.errorMessage = error.localizedDescription }
                        })).disabled(!store.monitoring.isAuthorized)
                        Stepper("From \(hour(store.monitoring.startHour))", value: Binding(get: { store.monitoring.startHour }, set: { store.monitoring.startHour = $0 }), in: 0...23)
                        Stepper("Until \(hour(store.monitoring.endHour))", value: Binding(get: { store.monitoring.endHour }, set: { store.monitoring.endHour = $0 }), in: 1...24)
                        Button("Save active hours") {
                            do { try store.monitoring.saveSchedule() }
                            catch { store.errorMessage = error.localizedDescription }
                        }
                    } else {
                        Label("Physical iPhone required", systemImage: "iphone")
                        Text("iOS Simulator cannot monitor or block other apps. You can still use rest timers and track your progress.")
                            .font(.footnote).foregroundStyle(AppTheme.secondary)
                    }
                    if let error = store.monitoring.errorMessage { Text(error).font(.footnote).foregroundStyle(.orange) }
                    Button("Release apps & stop monitoring") { store.monitoring.release() }
                } header: { Text("Automatic pauses") } footer: {
                    Text("Counts selected-app use, not continuous eye strain. iOS does not provide reliable whole-phone idle detection here. Use “I already took a break” for a fresh start.")
                }

                Section {
                    Button { showPaywall = true } label: {
                        HStack { Image(systemName: "sparkle"); Text("Explore Look Far Plus"); Spacer(); Image(systemName: "chevron.right").font(.caption) }
                    }.accessibilityIdentifier("showPlans")
                } header: { Text("Membership") }

                Section {
                    Button("Restart introduction") { store.state.onboardingComplete = false; dismiss() }
                    Button("Delete rest history", role: .destructive) { confirmDelete = true }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Brand.name).font(AppTheme.title(23))
                        Text(Brand.subtitle).font(.footnote).foregroundStyle(AppTheme.secondary)
                        Text("Version 0.1").font(.caption).foregroundStyle(AppTheme.secondary)
                    }.padding(.vertical, 6)
                } header: { Text("About") }
            }
            .scrollContentBackground(.hidden).background(AppTheme.background)
            .foregroundStyle(AppTheme.cream)
            .navigationTitle("Your space").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showRoutine) { RoutinePicker(store: store) }
            .sheet(isPresented: $showPaywall) { PaywallView(subscriptions: subscriptions) }
            .familyActivityPicker(isPresented: $showPicker, selection: Binding(get: { store.monitoring.selection }, set: { store.monitoring.selection = $0 }))
            .onChange(of: showPicker) { _, showing in if !showing { store.monitoring.saveSelection() } }
            .confirmationDialog("Delete your rest history?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete history", role: .destructive) { store.resetHistory() }
            } message: { Text("This removes recorded rests from this device. This cannot be undone.") }
        }
    }

    private func hour(_ value: Int) -> String { value == 24 ? "midnight" : String(format: "%02d:00", value) }
}
