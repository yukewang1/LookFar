import SwiftUI
import UIKit

struct BreakView: View {
    let store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var now = Date()

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 50)
                    Text(store.breakCompleted ? "Nicely done." : "Look far.")
                        .font(AppTheme.title(48)).multilineTextAlignment(.center)
                        .accessibilityIdentifier(store.breakCompleted ? "restComplete" : "restInstruction")
                    Text(store.breakCompleted ? "One rest. One new tree." : cue)
                        .font(.body).foregroundStyle(AppTheme.secondary)
                        .multilineTextAlignment(.center)
                    RestHorizonView(isComplete: store.breakCompleted)
                        .frame(height: min(270, geometry.size.height * 0.45))
                    if !store.breakCompleted, let session = store.state.activeSession {
                        let remaining = RestLogic.remainingSeconds(session, at: now)
                        let progress = min(1, max(0, 1 - session.deadline.timeIntervalSince(now) / Double(session.durationSeconds)))
                        VStack(spacing: 12) {
                            Text("\(remaining)s remaining")
                                .font(.subheadline).monospacedDigit()
                                .foregroundStyle(AppTheme.secondary)
                                .accessibilityLabel("Time remaining")
                                .accessibilityValue("\(remaining) seconds")
                                .accessibilityIdentifier("restCountdown")
                            SwiftUI.ProgressView(value: progress)
                                .progressViewStyle(.linear).tint(AppTheme.sage)
                                .animation(reduceMotion ? nil : .linear(duration: 0.2), value: progress)
                                .accessibilityLabel("Rest progress")
                                .accessibilityValue("\(Int(progress * 100)) percent")
                                .accessibilityIdentifier("restProgress")
                        }
                        .frame(maxWidth: 210)
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 28)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }.scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Group {
                if store.breakCompleted {
                    PrimaryButton(title: store.state.onboardingComplete ? "Back to my forest" : "Continue") {
                        store.dismissCompletedBreak()
                    }.accessibilityIdentifier("finishRest")
                } else {
                    Button("Skip") { store.skipBreak() }
                        .foregroundStyle(AppTheme.secondary).frame(maxWidth: .infinity, minHeight: 50)
                        .accessibilityIdentifier("skipRest")
                }
            }
            .padding(.horizontal, 28).padding(.vertical, 18)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
            .background(AppTheme.background)
        }
        .background(AppTheme.background).foregroundStyle(AppTheme.cream)
        .interactiveDismissDisabled()
        .task {
            UIApplication.shared.isIdleTimerDisabled = true
            while !Task.isCancelled {
                now = Date()
                store.tick()
                if store.breakCompleted { return }
                do { try await Task.sleep(for: .milliseconds(200)) }
                catch { return }
            }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var cue: String {
        let duration = store.state.activeSession?.durationSeconds ?? store.monitoring.restSeconds
        return store.soundEnabled
            ? "\(duration) seconds. We’ll chime when you’re done."
            : "\(duration) seconds. We’ll vibrate when you’re done."
    }
}

private struct RestHorizonView: View {
    let isComplete: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .fill(AppTheme.sage.opacity(0.035))
                    .frame(width: 220, height: 220)
                Circle()
                    .stroke(AppTheme.sage.opacity(0.10), lineWidth: 1)
                    .frame(width: 174, height: 174)
                    .scaleEffect(expanded ? 1.08 : 0.94)
                Circle()
                    .fill(AppTheme.sage.opacity(isComplete ? 0.32 : 0.17))
                    .frame(width: 120, height: 120)
                    .scaleEffect(expanded ? 1.06 : 0.97)
                Circle()
                    .fill(AppTheme.sage.opacity(isComplete ? 0.75 : 0.6))
                    .frame(width: 70, height: 70)
                    .overlay {
                        if isComplete {
                            Image(systemName: "checkmark")
                                .font(.system(size: 27, weight: .light))
                                .foregroundStyle(AppTheme.background)
                        }
                    }
                    .offset(y: -5)
                Ellipse()
                    .fill(AppTheme.surface)
                    .frame(width: geometry.size.width * 1.2, height: 90)
                    .offset(x: -geometry.size.width * 0.22, y: 110)
                Ellipse()
                    .fill(AppTheme.background)
                    .frame(width: geometry.size.width * 1.3, height: 85)
                    .offset(x: geometry.size.width * 0.26, y: 120)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .animation(reduceMotion || isComplete ? nil : .easeInOut(duration: 4).repeatForever(autoreverses: true), value: expanded)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.7), value: isComplete)
        }
        .accessibilityHidden(true)
        .onAppear { expanded = !reduceMotion }
        .onChange(of: reduceMotion) { _, reduced in expanded = !reduced }
        .onChange(of: isComplete) { _, completed in if completed { expanded = false } }
    }
}

struct PauseView: View {
    let store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionEyebrow(text: "A moment to pause")
                Text("Your eyes deserve\na change of scene.").font(AppTheme.title(35))
                    .fixedSize(horizontal: false, vertical: true)
                Text("You've reached \(store.monitoring.usageMinutes) minutes of app use. Take \(store.monitoring.restSeconds) seconds to look into the distance.")
                    .font(.body).foregroundStyle(AppTheme.secondary).lineSpacing(4)
                PrimaryButton(title: "Take a break") { store.startBreak() }
                    .accessibilityIdentifier("pauseStart")
                Button("Not now · start fresh") { store.skipBreak() }
                    .frame(maxWidth: .infinity, minHeight: 44).foregroundStyle(AppTheme.sage)
                    .accessibilityIdentifier("pauseSkip")
                Button("I already took a break") { store.confirmOwnBreak() }
                    .frame(maxWidth: .infinity, minHeight: 44).foregroundStyle(AppTheme.secondary)
                    .accessibilityIdentifier("pauseConfirm")
            }
            .padding(28).frame(maxWidth: .infinity)
        }
        .background(AppTheme.background).foregroundStyle(AppTheme.cream)
        .presentationDetents([.fraction(0.75), .large])
        .interactiveDismissDisabled()
    }
}
