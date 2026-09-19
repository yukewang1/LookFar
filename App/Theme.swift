import SwiftUI

enum Brand {
    static let name = "Look Far"
    static let subtitle = "Eye Strain Relief & Breaks"
}

enum AppTheme {
    static let background = Color(red: 0.098, green: 0.157, blue: 0.125)
    static let surface = Color(red: 0.145, green: 0.216, blue: 0.176)
    static let cream = Color(red: 0.949, green: 0.914, blue: 0.847)
    static let sage = Color(red: 0.659, green: 0.784, blue: 0.627)
    static let secondary = Color(red: 0.686, green: 0.722, blue: 0.675)
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif) }
}

struct PrimaryButton: View {
    let title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(.headline, design: .rounded))
                .frame(maxWidth: .infinity).padding(.vertical, 19)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.background)
        .background(AppTheme.cream, in: Capsule())
        .contentShape(Capsule())
    }
}

struct SectionEyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(2).foregroundStyle(AppTheme.sage)
    }
}

struct LandscapeView: View {
    var height: CGFloat = 230
    var body: some View {
        GeometryReader { geometry in
            Image("Landscape").resizable().scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                .overlay {
                    LinearGradient(stops: [.init(color: .clear, location: 0.70),
                                           .init(color: AppTheme.background, location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
        }
        .frame(height: height).accessibilityHidden(true)
    }
}

struct QuietRow: View {
    let symbol: String
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol).font(.title3).foregroundStyle(AppTheme.sage).frame(width: 25)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline).foregroundStyle(AppTheme.cream)
                Text(detail).font(.subheadline).foregroundStyle(AppTheme.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(.vertical, 12)
    }
}
