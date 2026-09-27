import DeviceActivity
import FamilyControls
import SwiftUI
import UIKit

struct DiagnosticsView: View {
    let monitoring: ScreenTimeManager
    @State private var snapshot = ""
    @State private var events: [DiagnosticEvent] = []
    @State private var copied = false

    var body: some View {
        Form {
            Section {
                Button(copied ? "Report copied" : "Copy diagnostic report") {
                    UIPasteboard.general.string = report
                    copied = true
                }.accessibilityIdentifier("copyDiagnostics")
                Button("Refresh", action: refresh)
            } footer: {
                Text("Saved on this device. Includes monitoring events and usage checkpoints, but no app names, website names, or selection tokens. Nothing is uploaded automatically.")
            }
            Section("Current status") {
                Text(snapshot).font(.footnote.monospaced()).textSelection(.enabled)
                    .accessibilityIdentifier("diagnosticStatus")
            }
            Section("Recent events · newest first") {
                if events.isEmpty {
                    Text("No diagnostic events recorded yet.")
                }
                ForEach(events.reversed()) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.name).font(.subheadline.bold())
                        Text("\(event.date.formatted(date: .abbreviated, time: .standard)) · \(event.source)")
                            .font(.caption).foregroundStyle(AppTheme.secondary)
                        if !event.details.isEmpty { Text(event.details).font(.caption.monospaced()) }
                    }.textSelection(.enabled)
                }
            }
        }
        .scrollContentBackground(.hidden).background(AppTheme.background)
        .navigationTitle("Diagnostics").navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refresh)
    }

    private var report: String {
        (["Look Far diagnostics", snapshot, "Events (oldest first)"] + events.map {
            "\($0.date.ISO8601Format()) [\($0.source)] \($0.name): \($0.details)"
        }).joined(separator: "\n")
    }

    private func refresh() {
        copied = false
        var lines = [
            "Version: \(MonitoringDiagnostics.version)",
            "System: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Captured: \(Date.now.ISO8601Format())",
            "Time zone: \(TimeZone.current.identifier)",
            "Authorization: \(String(describing: AuthorizationCenter.shared.authorizationStatus))",
            "App resolving authorization: \(monitoring.isResolvingAuthorization)"
        ]
        if monitoring.isUsingTestAuthorization { lines.append("SIMULATOR FIXTURE — not real Screen Time authorization") }
        do {
            let config = try ScreenTimeSupport.load()
            lines += [
                "Shared preferences: readable",
                "Automatic pauses: \(config.enabled)",
                "Timing: \(config.useMinutes) min / \(config.restSeconds) sec",
                "Scope: \(config.monitorsAllApps ? "All eligible apps" : "Custom selection")",
                "Selection counts: \(config.selection.applicationTokens.count) apps, \(config.selection.categoryTokens.count) categories, \(config.selection.webDomainTokens.count) domains",
                "Cycle: \(config.activityName ?? "none")",
                "Registration version: \(config.registrationVersion) / \(ScreenTimeSupport.registrationVersion)",
                "Pending break: \(config.pendingBreak)",
                "Rest deadline: \(config.breakDeadline?.ISO8601Format() ?? "none")",
                "Last error: \(try ScreenTimeSupport.lastError() ?? "none")"
            ]
            if ScreenTimeSupport.isAvailable {
                let center = DeviceActivityCenter()
                let activities = center.activities.filter { $0.rawValue.hasPrefix(ScreenTimeSupport.activityPrefix) }
                lines.append("Registered cycles: \(activities.count)")
                if let name = config.activityName {
                    let activity = DeviceActivityName(name)
                    let schedule = center.schedule(for: activity)
                    let registered = center.events(for: activity)
                    lines += [
                        "Current cycle registered: \(activities.contains(activity))",
                        "Schedule: \(String(describing: schedule))",
                        "Events: \(registered.count) / \(config.useMinutes) expected",
                        "Break threshold registered: \(registered[ScreenTimeSupport.thresholdEvent] != nil)"
                    ]
                }
            } else {
                lines.append("Device Activity unavailable in Simulator")
            }
        } catch { lines.append("STATUS READ FAILED: \(error.localizedDescription)") }
        do { events = try MonitoringDiagnostics.events() }
        catch {
            events = []
            lines.append("DIAGNOSTIC STORAGE FAILED: \(error.localizedDescription)")
        }
        let callback = events.last { $0.name == "usage.callback" }
        lines.append("Last usage callback: \(callback?.date.ISO8601Format() ?? "none recorded")")
        lines.append("Registration does not prove callback delivery. Simulator cannot validate it.")
        snapshot = lines.joined(separator: "\n")
    }
}
