import Foundation
import Observation
import UIKit
import UserNotifications
import AudioToolbox

@MainActor @Observable
final class AppStore {
    var state = RestState()
    var isBreakPresented = false
    var breakCompleted = false
    var showPause = false
    var errorMessage: String?
    var feedbackMessage: String?
    var soundEnabled = true
    let monitoring = ScreenTimeManager()

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var storageBlocked = false
    @ObservationIgnored private let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")

    init() {
        let folder = URL.documentsDirectory
        fileURL = folder.appendingPathComponent("rest-history.json")
        if !isUITesting, FileManager.default.fileExists(atPath: fileURL.path) {
            do { state = try JSONDecoder().decode(RestState.self, from: Data(contentsOf: fileURL)) }
            catch {
                storageBlocked = true
                errorMessage = "Your saved history could not be opened. It has not been overwritten. \(error.localizedDescription)"
            }
        }
        // Remove requests left by builds that offered end notifications.
        if !isUITesting {
            let notifications = UNUserNotificationCenter.current()
            notifications.removePendingNotificationRequests(withIdentifiers: ["rest-end"])
            notifications.removeDeliveredNotifications(withIdentifiers: ["rest-end"])
        }
        soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--skip-onboarding") { state.onboardingComplete = true }
        if isUITesting && arguments.contains("--ui-testing-restored-rest") {
            RestLogic.start(&state, at: .now)
        }
        isBreakPresented = state.activeSession != nil
            && (!state.onboardingComplete || !monitoring.isResolvingAuthorization)
        monitoring.onAuthorizationLost = { [weak self] in self?.interruptForScreenTimeDisconnect() }
        if !isUITesting { MonitoringDiagnostics.record("app.launch", "version=\(MonitoringDiagnostics.version); os=\(ProcessInfo.processInfo.operatingSystemVersionString)") }
        reconcile()
    }

    var todayCount: Int {
        state.records.filter { $0.kind == .guided && Calendar.current.isDateInToday($0.date) }.count
    }

    func finishOnboarding() {
        state.onboardingComplete = true
        persist()
    }

    func startBreak(isOnboardingTrial: Bool = false) {
        monitoring.refreshAuthorization()
        guard !state.onboardingComplete || (!monitoring.isResolvingAuthorization && monitoring.isAuthorized) else { return }
        feedbackMessage = nil
        breakCompleted = false
        showPause = false
        let useShortTimer = isUITesting && !ProcessInfo.processInfo.arguments.contains("--ui-testing-full-rest")
        let duration = isOnboardingTrial ? RestSchedule.onboardingRestSeconds : monitoring.restSeconds
        RestLogic.start(&state, at: Date(), durationOverride: useShortTimer ? 2 : duration)
        persist()
        isBreakPresented = true
        if monitoring.isEnabled, let session = state.activeSession {
            do { try monitoring.beginBreak(deadline: session.deadline) }
            catch { errorMessage = error.localizedDescription }
        }
    }

    func reconcile() {
        monitoring.refresh()
        if state.onboardingComplete && monitoring.isResolvingAuthorization { return }
        if state.onboardingComplete && !monitoring.isAuthorized {
            interruptForScreenTimeDisconnect()
        }
        reconcileShieldEvents()
        presentPendingBreak()
    }

    private func reconcileShieldEvents() {
        let starts: [RestSession]
        let skips: [ShieldSkipEvent]
        do {
            starts = try monitoring.pendingStartedRests()
            skips = try monitoring.pendingSkippedBreaks()
        } catch {
            errorMessage = error.localizedDescription
            tick()
            return
        }
        guard !starts.isEmpty || !skips.isEmpty else {
            tick()
            return
        }
        for event in skips {
            if !state.records.contains(where: { $0.id == event.id }) {
                state.records.append(RestRecord(id: event.id, date: event.date, durationSeconds: 0, kind: .skipped))
            }
            if let session = state.activeSession, event.date >= session.startedAt, event.date < session.deadline {
                state.activeSession = nil
                isBreakPresented = false
                breakCompleted = false
            }
        }
        tick()
        if monitoring.isAuthorized,
           RestLogic.restoreStartedRests(&state, sessions: starts, at: .now) {
            feedbackMessage = nil
            showPause = false
            breakCompleted = state.activeSession == nil
            isBreakPresented = true
        }
        if persist() {
            do {
                try monitoring.acknowledgeStartedRests(ids: Set(starts.map(\.id)))
                try monitoring.acknowledgeSkippedBreaks(ids: Set(skips.map(\.id)))
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func pollForPendingBreak() {
        guard state.onboardingComplete, !monitoring.isResolvingAuthorization else { return }
        monitoring.refreshAuthorization()
        guard monitoring.isAuthorized else {
            interruptForScreenTimeDisconnect()
            return
        }
        monitoring.refreshPendingBreak()
        reconcileShieldEvents()
        presentPendingBreak()
    }

    private func presentPendingBreak() {
        if !monitoring.hasPendingBreak {
            showPause = false
        } else if state.activeSession == nil && !breakCompleted && !showPause {
            if !isUITesting { MonitoringDiagnostics.record("break.prompt-presented") }
            showPause = true
        }
    }

    func resolveScreenTimeAuthorization() async {
        guard state.onboardingComplete, monitoring.isResolvingAuthorization else { return }
        await monitoring.resolveExistingAuthorization()
        if monitoring.isAuthorized { isBreakPresented = state.activeSession != nil }
        reconcile()
    }

    private func interruptForScreenTimeDisconnect() {
        let hadSession = state.activeSession != nil
        state.activeSession = nil
        isBreakPresented = false
        breakCompleted = false
        showPause = false
        if hadSession { persist() }
    }

    func tick() {
        if state.onboardingComplete {
            monitoring.refreshAuthorization()
            guard !monitoring.isResolvingAuthorization else { return }
            guard monitoring.isAuthorized else {
                interruptForScreenTimeDisconnect()
                return
            }
        }
        guard RestLogic.completeIfDue(&state, at: Date()) else { return }
        persist()
        breakCompleted = true
        resetMonitoring(reason: "Guided rest completed", onlyIfRestExpired: true)
        if UIApplication.shared.applicationState == .active {
            if soundEnabled { AudioServicesPlaySystemSound(1007) }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    func skipBreak() {
        RestLogic.skip(&state, at: Date())
        persist()
        isBreakPresented = false
        showPause = false
        breakCompleted = false
        resetMonitoring(reason: "Break skipped in app")
        feedbackMessage = "Skipped. Your next cycle starts fresh."
    }

    func confirmOwnBreak() {
        RestLogic.confirmBreak(&state, at: Date())
        persist()
        isBreakPresented = false
        showPause = false
        breakCompleted = false
        resetMonitoring(reason: "Own break confirmed")
        feedbackMessage = "A fresh start. Your own break was noted separately."
    }

    func dismissCompletedBreak() {
        isBreakPresented = false
    }

    func setSound(_ enabled: Bool) {
        soundEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "soundEnabled")
    }

    func resetHistory() {
        state.records = []
        storageBlocked = false
        persist()
    }

    private func resetMonitoring(reason: String, onlyIfRestExpired: Bool = false) {
        guard monitoring.isEnabled else { return }
        do { try monitoring.resetCycle(usageMinutes: monitoring.usageMinutes, reason: reason, onlyIfRestExpired: onlyIfRestExpired) }
        catch {
            monitoring.stopAfterFailure()
            errorMessage = "Monitoring paused and apps released because a new cycle could not start. \(error.localizedDescription)"
        }
    }

    @discardableResult private func persist() -> Bool {
        guard !isUITesting else { return true }
        guard !storageBlocked else { return false }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(state).write(to: fileURL, options: .atomic)
            return true
        } catch {
            errorMessage = "Your progress could not be saved: \(error.localizedDescription)"
            return false
        }
    }

}
