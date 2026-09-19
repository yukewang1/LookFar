import SwiftUI

struct OnboardingView: View {
    @Bindable var store: AppStore
    @State private var page = 0

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Brand.name).font(AppTheme.title(30))
                            Text(Brand.subtitle).font(.caption).foregroundStyle(AppTheme.secondary)
                        }
                        Spacer()
                        Text("\(page + 1) / 3").font(.caption).foregroundStyle(AppTheme.secondary)
                    }.padding(.horizontal, 26).padding(.top, 20)
                    LandscapeView(height: min(260, geometry.size.height * 0.34))
                    VStack(alignment: .leading, spacing: 20) {
                        SectionEyebrow(text: page == 0 ? "Gentle eye breaks" : page == 1 ? "Your rhythm" : "On your terms")
                        Text(page == 0 ? "A little distance.\nA daily kindness." : page == 1 ? "Make rest\npart of your day." : "Less friction.\nMore room to rest.")
                            .font(AppTheme.title(43)).fixedSize(horizontal: false, vertical: true)
                        if page == 0 {
                            Text("For people with myopia, tired eyes, or long screen days. Build a small habit of looking away.")
                                .foregroundStyle(AppTheme.secondary).lineSpacing(4)
                            QuietRow(symbol: "eye", title: "A habit, not a treatment", detail: "Breaks don't correct myopia or prevent retinal disease. Keep your regular eye care.")
                        } else if page == 1 {
                            ForEach(RestRoutine.allCases) { routine in
                                Button { store.setRoutine(routine) } label: {
                                    HStack {
                                        Text(routine.title).font(.headline)
                                        Spacer()
                                        Text("\(routine.usageMinutes)m / \(routine.restSeconds)s").foregroundStyle(AppTheme.secondary)
                                        Image(systemName: store.state.routine == routine ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(AppTheme.sage)
                                    }.padding(.vertical, 12).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                            }
                        } else {
                            QuietRow(symbol: "hand.raised", title: "You stay in control", detail: "Choose apps to pause, skip when needed, or start a rest yourself.")
                            QuietRow(symbol: "chart.bar", title: "See the habit grow", detail: "Track recorded rests and weekly consistency. Your history stays on this device.")
                            Text("Automatic app pauses need Screen Time permission on a physical iPhone. You can set that up later.")
                                .font(.footnote).foregroundStyle(AppTheme.secondary)
                        }
                        PrimaryButton(title: page == 2 ? "Make space for a break" : "Continue") {
                            if page == 2 { store.finishOnboarding() }
                            else { withAnimation(.easeInOut(duration: 0.2)) { page += 1 } }
                        }.accessibilityIdentifier("onboardingContinue")
                        if page > 0 {
                            Button("Back") { page -= 1 }.frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(AppTheme.secondary)
                        }
                    }.padding(.horizontal, 26).padding(.bottom, 28)
                }
            }.scrollIndicators(.hidden).background(AppTheme.background)
        }.foregroundStyle(AppTheme.cream)
    }
}
