import SwiftUI

struct TodayView: View {
    @Bindable var store: AppStore
    let openSettings: () -> Void
    let openProgress: () -> Void
    @State private var confirmReset = false
    @State private var showRoutine = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(Brand.name).font(AppTheme.title(30))
                        Spacer()
                        Button(action: openSettings) {
                            Image(systemName: "slider.horizontal.3").font(.title3)
                                .frame(width: 46, height: 46).background(AppTheme.cream.opacity(0.09), in: Circle())
                        }.accessibilityLabel("Settings")
                    }.padding(.horizontal, 24).padding(.top, 12)

                    HStack(spacing: 8) {
                        Circle().fill(AppTheme.sage).frame(width: 8, height: 8)
                        Text(store.monitoring.isEnabled ? "Your routine is active" : "A little space, whenever you need it")
                            .font(.subheadline).foregroundStyle(AppTheme.secondary)
                    }.padding(.horizontal, 24).padding(.top, 10)

                    LandscapeView(height: min(205, geometry.size.height * 0.27)).padding(.top, 7)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Make space\nto look away.")
                            .font(AppTheme.title(54)).tracking(-1.8).lineSpacing(-3)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Button { showRoutine = true } label: {
                            VStack(spacing: 5) {
                                Text("\(store.state.routine.usageMinutes) / \(store.state.routine.restSeconds)")
                                    .font(AppTheme.title(37)).tracking(2)
                                HStack(spacing: 6) {
                                    Text("\(store.state.routine.usageMinutes) min of use · \(store.state.routine.restSeconds) sec to rest")
                                    Image(systemName: "chevron.down").font(.caption2)
                                }.font(.subheadline).foregroundStyle(AppTheme.secondary)
                            }.frame(maxWidth: .infinity).padding(.vertical, 18).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel("Change routine")

                        PrimaryButton(title: "Start an eye rest", action: store.startBreak)
                            .accessibilityIdentifier("startRest")
                        Button("I already took a break") { confirmReset = true }
                            .font(.subheadline).underline().foregroundStyle(AppTheme.sage)
                            .frame(maxWidth: .infinity).frame(minHeight: 52)
                            .accessibilityIdentifier("confirmOwnBreak")

                        if let feedback = store.feedbackMessage {
                            Text(feedback).font(.caption).foregroundStyle(AppTheme.sage)
                                .frame(maxWidth: .infinity).padding(.bottom, 10)
                        }
                        Divider().overlay(AppTheme.secondary.opacity(0.25))
                        Button(action: openProgress) {
                            HStack(spacing: 13) {
                                Image(systemName: "chart.bar.fill").font(.title2).foregroundStyle(AppTheme.sage)
                                Text("\(store.todayCount) timed \(store.todayCount == 1 ? "rest" : "rests") today").font(.subheadline)
                                Spacer()
                                Text("View progress").font(.caption)
                                Image(systemName: "arrow.right").font(.caption)
                            }.foregroundStyle(AppTheme.cream).padding(.vertical, 18).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("viewProgress")
                    }.padding(.horizontal, 24)
                }.padding(.bottom, 12)
            }.scrollIndicators(.hidden).background(AppTheme.background)
        }
        .confirmationDialog("Already had time away?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Yes, reset my cycle") { store.confirmOwnBreak() }
        } message: {
            Text("Confirm that you took a break from close-up screens. We'll start fresh and note it separately from a timed rest.")
        }
        .sheet(isPresented: $showRoutine) { RoutinePicker(store: store) }
    }
}

struct RoutinePicker: View {
    @Bindable var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Find your rhythm.").font(AppTheme.title(36)).padding(.top, 20)
                Text("Choose a rhythm you can keep. Each rest invites you to look into the distance.")
                    .foregroundStyle(AppTheme.secondary)
                ForEach(RestRoutine.allCases) { routine in
                    Button {
                        store.setRoutine(routine)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(routine.title).font(.headline)
                                Text("\(routine.usageMinutes) min use · \(routine.restSeconds) sec rest")
                                    .font(.subheadline).foregroundStyle(AppTheme.secondary)
                            }
                            Spacer()
                            Image(systemName: store.state.routine == routine ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(AppTheme.sage)
                        }.padding(20).background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain).accessibilityIdentifier("routine-\(routine.rawValue)")
                }
                Text("These are habit preferences, not medical prescriptions.").font(.footnote).foregroundStyle(AppTheme.secondary)
                Spacer()
            }.padding(.horizontal, 24).background(AppTheme.background).foregroundStyle(AppTheme.cream)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.presentationDetents([.large])
    }
}
