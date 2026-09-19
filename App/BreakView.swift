import SwiftUI
import UIKit

struct BreakView: View {
    @Bindable var store: AppStore
    @State private var now = Date()

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        Text(Brand.name).font(AppTheme.title(27))
                        Spacer()
                        Image(systemName: store.breakCompleted ? "checkmark.circle" : "moon")
                            .foregroundStyle(AppTheme.sage).font(.title2)
                    }.padding(.top, 20)
                    Spacer(minLength: 60)
                    SectionEyebrow(text: store.breakCompleted ? "A moment well spent" : "You can look away now")
                    Text(store.breakCompleted ? "A little more\nroom to breathe." : "Let your gaze\ngo a little further.")
                        .font(AppTheme.title(43)).multilineTextAlignment(.center).padding(.top, 24)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(store.breakCompleted ? "Your rest has been recorded.\nCome back at your own pace." : "Look at something about 6 metres / 20 feet away. Blink comfortably.")
                        .font(.body).lineSpacing(5).foregroundStyle(AppTheme.secondary)
                        .multilineTextAlignment(.center).padding(.top, 22)

                    if store.breakCompleted {
                        Image(systemName: "checkmark").font(.system(size: 50, weight: .ultraLight))
                            .foregroundStyle(AppTheme.sage).frame(height: 170)
                            .accessibilityIdentifier("restComplete")
                    } else {
                        Text(remaining.formatted(.number.precision(.integerLength(2))))
                            .font(.system(size: 84, weight: .ultraLight, design: .serif))
                            .monospacedDigit().foregroundStyle(AppTheme.sage.opacity(0.65))
                            .frame(height: 170).accessibilityLabel("\(remaining) seconds remaining")
                        Text(store.soundEnabled ? "We'll play a gentle cue when it's time." : "A gentle haptic marks the end.")
                            .font(.footnote).foregroundStyle(AppTheme.secondary).multilineTextAlignment(.center)
                        Text("No need to watch the countdown.").font(.footnote).foregroundStyle(AppTheme.secondary).padding(.top, 8)
                    }
                    Spacer(minLength: 50)
                    if store.breakCompleted {
                        PrimaryButton(title: "Back to my day") { store.dismissCompletedBreak() }
                            .accessibilityIdentifier("finishRest")
                    } else {
                        Button("Skip this rest") { store.skipBreak() }
                            .foregroundStyle(AppTheme.secondary).frame(minHeight: 50)
                            .accessibilityIdentifier("skipRest")
                        Text("If you lock your phone, return here to finish and release any app pauses.")
                            .font(.caption).foregroundStyle(AppTheme.secondary).multilineTextAlignment(.center)
                    }
                }.padding(.horizontal, 28).padding(.bottom, 30)
                    .frame(minHeight: geometry.size.height)
            }.scrollIndicators(.hidden)
        }
        .background(AppTheme.background).foregroundStyle(AppTheme.cream)
        .interactiveDismissDisabled()
        .task {
            UIApplication.shared.isIdleTimerDisabled = true
            while !Task.isCancelled {
                now = Date()
                store.tick()
                do { try await Task.sleep(for: .milliseconds(200)) }
                catch { return }
            }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var remaining: Int {
        guard let session = store.state.activeSession else { return 0 }
        return RestLogic.remainingSeconds(session, at: now)
    }
}

struct PauseView: View {
    @Bindable var store: AppStore
    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            SectionEyebrow(text: "A moment to pause")
            Text("Your eyes deserve\na change of scene.").font(AppTheme.title(35))
                .fixedSize(horizontal: false, vertical: true)
            Text("You've reached your \(store.state.routine.usageMinutes)-minute routine. Take \(store.state.routine.restSeconds) seconds to look into the distance.")
                .font(.body).foregroundStyle(AppTheme.secondary).lineSpacing(4)
            PrimaryButton(title: "Take a break") { store.startBreak() }.accessibilityIdentifier("pauseStart")
            Button("Not now · start fresh") { store.skipBreak() }
                .frame(maxWidth: .infinity, minHeight: 44).foregroundStyle(AppTheme.sage)
                .accessibilityIdentifier("pauseSkip")
            Button("I already took a break") { store.confirmOwnBreak() }
                .frame(maxWidth: .infinity, minHeight: 44).foregroundStyle(AppTheme.secondary)
        }.padding(28).frame(maxWidth: .infinity)
        }
            .background(AppTheme.background).foregroundStyle(AppTheme.cream)
            .presentationDetents([.fraction(0.75), .large])
            .interactiveDismissDisabled()
    }
}
