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
    var notificationPermission = false
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
        soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--skip-onboarding") { state.onboardingComplete = true }
        isBreakPresented = state.activeSession != nil
        reconcile()
    }

    var todayCount: Int {
        state.records.filter { $0.kind == .guided && Calendar.current.isDateInToday($0.date) }.count
    }

    func finishOnboarding() {
        state.onboardingComplete = true
        persist()
    }

    func setRoutine(_ routine: RestRoutine) {
        state.routine = routine
        persist()
        resetMonitoring()
    }

    func startBreak() {
        feedbackMessage = nil
        breakCompleted = false
        showPause = false
        RestLogic.start(&state, at: Date(), durationOverride: isUITesting ? 2 : nil)
        persist()
        isBreakPresented = true
        if monitoring.isEnabled, let session = state.activeSession {
            do { try monitoring.beginBreak(duration: TimeInterval(session.durationSeconds)) }
            catch { errorMessage = error.localizedDescription }
        }
        scheduleEndCue()
    }

    func reconcile() {
        monitoring.refresh()
        let skips: [ShieldSkipEvent]
        do { skips = try monitoring.pendingSkippedBreaks() }
        catch {
            errorMessage = error.localizedDescription
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
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest-end"])
            }
        }
        tick()
        if monitoring.hasPendingBreak && state.activeSession == nil && !breakCompleted {
            showPause = true
        }
        if persist() {
            do { try monitoring.acknowledgeSkippedBreaks(ids: Set(skips.map(\.id))) }
            catch { errorMessage = error.localizedDescription }
        }
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationPermission = settings.authorizationStatus == .authorized
        }
    }

    func tick() {
        guard RestLogic.completeIfDue(&state, at: Date()) else { return }
        persist()
        breakCompleted = true
        resetMonitoring()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest-end"])
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
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest-end"])
        resetMonitoring()
        feedbackMessage = "Skipped. Your next cycle starts fresh."
    }

    func confirmOwnBreak() {
        RestLogic.confirmBreak(&state, at: Date())
        persist()
        isBreakPresented = false
        showPause = false
        breakCompleted = false
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest-end"])
        resetMonitoring()
        feedbackMessage = "A fresh start. Your own break was noted separately."
    }

    func dismissCompletedBreak() {
        isBreakPresented = false
        breakCompleted = false
    }

    func requestNotifications() async {
        do { notificationPermission = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
        catch { errorMessage = error.localizedDescription }
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

    private func resetMonitoring() {
        guard monitoring.isEnabled else { return }
        do { try monitoring.resetCycle(usageMinutes: state.routine.usageMinutes) }
        catch {
            monitoring.release()
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

    private func scheduleEndCue() {
        guard notificationPermission, let session = state.activeSession else { return }
        let content = UNMutableNotificationContent()
        content.title = "Your moment of rest is complete"
        content.body = "Return to \(Brand.name) whenever you're ready."
        if soundEnabled { content.sound = .default }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, session.deadline.timeIntervalSinceNow), repeats: false)
        Task {
            do { try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "rest-end", content: content, trigger: trigger)) }
            catch { errorMessage = "The end notification could not be scheduled: \(error.localizedDescription)" }
        }
    }
}
