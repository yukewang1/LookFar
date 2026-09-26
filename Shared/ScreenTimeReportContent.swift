import DeviceActivity
import SwiftUI

extension DeviceActivityReport.Context {
    static let todayTotalActivity = Self("lookfar.today-total-activity")
}

struct ScreenTimeMetric: View {
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.system(.largeTitle, design: .rounded, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(AppTheme.cream)
            Text(detail)
                .font(.caption)
                .foregroundStyle(AppTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.surface)
        .accessibilityElement(children: .combine)
    }
}
