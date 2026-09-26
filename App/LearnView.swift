import SwiftUI

struct LearnView: View {
    @State private var showCareAdvice = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("A LITTLE PERSPECTIVE").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(AppTheme.sage)
                    Text("Care for the way\nyou see.").font(AppTheme.title(37))
                    Text("Simple ways to make your screen days feel better.")
                        .font(.subheadline).foregroundStyle(AppTheme.secondary)
                }
                ritualCard
                VStack(alignment: .leading, spacing: 24) {
                    article(symbol: "eye", title: "Comfort is worth a pause.", text: "Long stretches of screen use can bring dry, tired eyes or blurred vision. Regular breaks, comfortable lighting, and gentle, complete blinks may help with discomfort.")
                    Divider().overlay(AppTheme.cream.opacity(0.1))
                    article(symbol: "viewfinder", title: "Myopia deserves ongoing care.", text: "Myopia often develops when an eye grows too long from front to back, so light focuses in front of the retina. High myopia is associated with a greater risk of retinal detachment and other eye problems.")
                    Text("Look Far supports a break habit. It has not been shown to shorten the eye, slow myopia, or prevent retinal disease. Keep following your eye care professional’s advice.")
                        .font(.subheadline).foregroundStyle(AppTheme.sage)
                        .padding(18)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                }
                VStack(alignment: .leading, spacing: 14) {
                    Text("Make it comfortable.").font(AppTheme.title(26))
                    tip("Look beyond the screen", detail: "Choose something far away. Around 6 metres / 20 feet is a useful guide.", symbol: "mountain.2")
                    tip("Blink gently and fully", detail: "Let your eyes close completely. No squeezing or eye exercises needed.", symbol: "eye.closed")
                    tip("Make room for small pauses", detail: "Let regular screen breaks become part of your day, and take an extra pause whenever you need one.", symbol: "water.waves")
                }
                careAdvice
                sources
                Text("General education, not a diagnosis or a treatment plan.")
                    .font(.footnote).foregroundStyle(AppTheme.secondary)
            }
            .padding(24)
            .padding(.bottom, 28)
        }
        .background(AppTheme.background)
        .foregroundStyle(AppTheme.cream)
        .navigationTitle("Perspective")
        .toolbar(.hidden, for: .navigationBar)
    }

    private var ritualCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "sun.horizon").font(.system(size: 36, weight: .ultraLight)).foregroundStyle(AppTheme.sage).accessibilityHidden(true)
            Text("The 20–20–20 ritual").font(AppTheme.title(27))
            HStack(alignment: .top, spacing: 8) {
                ritualNumber("20", unit: "minutes", caption: "of close-up time")
                ritualNumber("20", unit: "seconds", caption: "to pause")
                ritualNumber("20", unit: "feet away", caption: "to look")
            }
            Text("Recommended by the American Optometric Association as a practical break routine. Research on the exact timing is limited; it’s a useful habit, not a guaranteed health outcome.")
                .font(.subheadline).foregroundStyle(AppTheme.secondary)
            Link(destination: URL(string: "https://www.aoa.org/healthy-eyes/eye-and-vision-conditions/computer-vision-syndrome")!) {
                Label("Read the AOA guidance", systemImage: "arrow.up.right").font(.footnote.weight(.medium))
            }
            .tint(AppTheme.sage)
        }
        .padding(24)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 28))
    }

    private func ritualNumber(_ number: String, unit: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(number).font(AppTheme.title(42))
            Text(unit).font(.caption.weight(.medium)).foregroundStyle(AppTheme.sage)
            Text(caption).font(.caption2).foregroundStyle(AppTheme.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func article(symbol: String, title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Image(systemName: symbol).font(.title2.weight(.light)).foregroundStyle(AppTheme.sage).accessibilityHidden(true)
            Text(title).font(AppTheme.title(27))
            Text(text).font(.subheadline).foregroundStyle(AppTheme.secondary).lineSpacing(4)
        }
    }

    private func tip(_ title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title3.weight(.light)).foregroundStyle(AppTheme.sage)
                .frame(width: 34, height: 32).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.subheadline).foregroundStyle(AppTheme.secondary)
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }

    private var careAdvice: some View {
        DisclosureGroup(isExpanded: $showCareAdvice) {
            VStack(alignment: .leading, spacing: 14) {
                Text("If discomfort or blur keeps returning, arrange an eye exam. Screen breaks do not replace a check of your prescription or eye health.")
                Text("Get urgent eye care for sudden flashes, many new floaters, or a curtain or shadow across your vision. These can be signs of retinal detachment, which is a medical emergency.")
                Link("Retinal detachment · National Eye Institute", destination: URL(string: "https://www.nei.nih.gov/eye-health-information/eye-conditions-and-diseases/retinal-detachment")!)
                    .tint(AppTheme.sage)
            }
            .font(.subheadline).foregroundStyle(AppTheme.secondary)
            .padding(.top, 16)
        } label: {
            Label("When to get eye care", systemImage: "cross.case")
                .font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.cream)
        }
        .tint(AppTheme.sage)
        .padding(20)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 22))
    }

    private var sources: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KEEP EXPLORING").font(.caption2.weight(.semibold)).tracking(1.5).foregroundStyle(AppTheme.sage)
            Link(destination: URL(string: "https://www.nei.nih.gov/eye-health-information/eye-conditions-and-diseases/nearsightedness-myopia")!) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Understanding myopia").font(.subheadline)
                        Text("National Eye Institute").font(.caption).foregroundStyle(AppTheme.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption)
                }
            }
            .tint(AppTheme.cream)
        }
    }
}
