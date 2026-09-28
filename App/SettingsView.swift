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
                    NavigationLink {
                        RhythmSettingsView(store: store)
                    } label: {
                        LabeledContent("Break timing") {
                            Text("\(store.monitoring.usageMinutes) min / \(store.monitoring.restSeconds) sec")
                                .foregroundStyle(AppTheme.secondary)
                                .accessibilityIdentifier("rhythmSummary")
                        }
                    }.accessibilityIdentifier("editRhythm")
                    Toggle("End sound", isOn: Binding(get: { store.soundEnabled }, set: { store.setSound($0) }))
                } header: { Text("Your rhythm") }

                Section {
                    if store.monitoring.isAvailable {
                        Button("Customize apps") { showPicker = true }.disabled(!store.monitoring.isAuthorized)
                            .accessibilityIdentifier("customizeApps")
                    } else {
                        Label("Physical iPhone required", systemImage: "iphone")
                        Text("Screen Time access requires a physical iPhone.")
                            .font(.footnote).foregroundStyle(AppTheme.secondary)
                    }
                    if let error = store.monitoring.errorMessage { Text(error).font(.footnote).foregroundStyle(.orange) }
                } header: { Text("Break reminders") } footer: {
                    Text("Reminders run all day. All eligible apps are included unless you choose specific apps. You can skip any break.")
                }

                Section {
                    Button { showPaywall = true } label: {
                        HStack { Image(systemName: "sparkle"); Text("Explore Look Far Plus"); Spacer(); Image(systemName: "chevron.right").font(.caption) }
                    }.accessibilityIdentifier("showPlans")
                } header: { Text("Membership") }

                Section {
                    NavigationLink {
                        DiagnosticsView(monitoring: store.monitoring)
                    } label: {
                        Label("Diagnostics", systemImage: "waveform.path.ecg")
                    }.accessibilityIdentifier("openDiagnostics")
                    Button("Delete rest history", role: .destructive) { confirmDelete = true }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Brand.name).font(AppTheme.title(23))
                        Text(Brand.subtitle).font(.footnote).foregroundStyle(AppTheme.secondary)
                        Text("Version \(MonitoringDiagnostics.version)").font(.caption).foregroundStyle(AppTheme.secondary)
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

}

private struct RhythmSettingsView: View {
    let store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var usageMinutes: Int
    @State private var restSeconds: Int
    @State private var errorMessage: String?

    init(store: AppStore) {
        self.store = store
        _usageMinutes = State(initialValue: store.monitoring.usageMinutes)
        _restSeconds = State(initialValue: store.monitoring.restSeconds)
    }

    var body: some View {
        Form {
            Section {
                Picker("Screen use", selection: $usageMinutes) {
                    ForEach(Array(stride(from: 5, through: 120, by: 5)), id: \.self) { minutes in
                        Text("\(minutes) minutes").tag(minutes)
                    }
                }
                .pickerStyle(.wheel)
                .accessibilityIdentifier("usageMinutes")
            } header: { Text("Screen use") }

            Section {
                Picker("Rest", selection: $restSeconds) {
                    ForEach(Array(stride(from: 5, through: 120, by: 5)), id: \.self) { seconds in
                        Text("\(seconds) seconds").tag(seconds)
                    }
                }
                .pickerStyle(.wheel)
                .accessibilityIdentifier("restSeconds")
            } header: { Text("Rest") } footer: {
                Text("Save to apply both durations and start a fresh usage cycle. A rest already in progress keeps its original duration.")
            }
        }
        .scrollContentBackground(.hidden).background(AppTheme.background)
        .foregroundStyle(AppTheme.cream)
        .navigationTitle("Break timing").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save).accessibilityIdentifier("saveRhythm")
            }
        }
        .alert("Timing needs attention", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func save() {
        do {
            if usageMinutes != store.monitoring.usageMinutes || restSeconds != store.monitoring.restSeconds {
                try store.monitoring.saveRhythm(usageMinutes: usageMinutes, restSeconds: restSeconds)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
