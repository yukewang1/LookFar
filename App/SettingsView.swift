import SwiftUI
import FamilyControls

struct SettingsView: View {
    @Bindable var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var showPicker = false
    @State private var showPaywall = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Screen use: \(store.monitoring.usageMinutes) minutes", value: Binding(
                        get: { store.monitoring.usageMinutes },
                        set: { saveRhythm(usageMinutes: $0, restSeconds: store.monitoring.restSeconds) }
                    ), in: 5...120, step: 5)
                    .accessibilityIdentifier("usageMinutes")
                    Stepper("Rest: \(store.monitoring.restSeconds) seconds", value: Binding(
                        get: { store.monitoring.restSeconds },
                        set: { saveRhythm(usageMinutes: store.monitoring.usageMinutes, restSeconds: $0) }
                    ), in: 5...120, step: 5)
                    .accessibilityIdentifier("restSeconds")
                    Button("I already took a break") { store.confirmOwnBreak() }
                        .accessibilityIdentifier("confirmOwnBreak")
                    Toggle("End sound", isOn: Binding(get: { store.soundEnabled }, set: { store.setSound($0) }))
                    Button(store.notificationPermission ? "End notifications are enabled" : "Enable end notifications") {
                        Task { await store.requestNotifications() }
                    }.disabled(store.notificationPermission)
                } header: { Text("Your rhythm") } footer: {
                    Text("Changes start a fresh usage cycle. A rest already in progress keeps its original duration.")
                }

                Section {
                    if store.monitoring.isAvailable {
                        Button(store.monitoring.isAuthorized ? "Screen Time connected" : "Connect Screen Time") {
                            Task { await store.monitoring.requestAuthorization() }
                        }.disabled(store.monitoring.isAuthorized)
                        Button("Customize apps") { showPicker = true }.disabled(!store.monitoring.isAuthorized)
                        Text("All eligible apps are included by default. Choose specific apps to narrow the scope; clear your selection to include everything again.")
                            .font(.footnote).foregroundStyle(AppTheme.secondary)
                        Toggle("Automatic app pauses", isOn: Binding(get: { store.monitoring.isEnabled }, set: { enabled in
                            do { try store.monitoring.setEnabled(enabled, usageMinutes: store.monitoring.usageMinutes) }
                            catch { store.errorMessage = error.localizedDescription }
                        })).disabled(!store.monitoring.isAuthorized)
                        Text("Runs 24/7. You can skip any break when it appears.")
                            .font(.footnote).foregroundStyle(AppTheme.secondary)
                    } else {
                        Label("Physical iPhone required", systemImage: "iphone")
                        Text("Screen Time access requires a physical iPhone.")
                            .font(.footnote).foregroundStyle(AppTheme.secondary)
                    }
                    if let error = store.monitoring.errorMessage { Text(error).font(.footnote).foregroundStyle(.orange) }
                    Button("Release apps & stop monitoring") { store.monitoring.release() }
                } header: { Text("Automatic pauses") } footer: {
                    Text("App use adds up throughout the day and night. Use “I already took a break” to reset your cycle after time away. The Today total always includes all eligible apps on this iPhone.")
                }

                Section {
                    Button { showPaywall = true } label: {
                        HStack { Image(systemName: "sparkle"); Text("Explore Look Far Plus"); Spacer(); Image(systemName: "chevron.right").font(.caption) }
                    }.accessibilityIdentifier("showPlans")
                } header: { Text("Membership") }

                Section {
                    Button("Restart introduction") { store.restartOnboarding(); dismiss() }
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
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .familyActivityPicker(isPresented: $showPicker, selection: Binding(get: { store.monitoring.selection }, set: { store.monitoring.selection = $0 }))
            .onChange(of: showPicker) { _, showing in if !showing { store.monitoring.saveSelection() } }
            .confirmationDialog("Delete your rest history?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete history", role: .destructive) { store.resetHistory() }
            } message: { Text("This removes all recorded rests and earned trees from this device. This cannot be undone.") }
        }
    }

    private func saveRhythm(usageMinutes: Int, restSeconds: Int) {
        do { try store.monitoring.saveRhythm(usageMinutes: usageMinutes, restSeconds: restSeconds) }
        catch { store.errorMessage = error.localizedDescription }
    }
}
