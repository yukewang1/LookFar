import DeviceActivity
import SwiftUI

struct TodayScreenTimeView: View {
    let monitoring: ScreenTimeManager
    @ScaledMetric(relativeTo: .largeTitle) private var reportHeight = 84

    private func filter(at date: Date) -> DeviceActivityFilter {
        // Empty app filters include all activity. A nil device filter means this device.
        DeviceActivityFilter(segment: .daily(during: DateInterval(
            start: Calendar.current.startOfDay(for: date), end: date
        )))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Screen time today", systemImage: "iphone")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.sage)
            if monitoring.isUsingTestAuthorization {
                ScreenTimeMetric(value: "—", detail: "Screen Time data is unavailable in UI tests.")
            } else if !monitoring.isAvailable {
                ScreenTimeMetric(value: "—", detail: "Screen Time is available on a physical iPhone.")
            } else if !monitoring.isAuthorized {
                ScreenTimeMetric(value: "—", detail: "Connect Screen Time in Settings to see your daily total.")
            } else {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    DeviceActivityReport(.todayTotalActivity, filter: filter(at: context.date))
                        .frame(height: reportHeight)
                        .background {
                            ScreenTimeMetric(value: "—", detail: "Waiting for Screen Time data…")
                                .accessibilityHidden(true)
                        }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 22))
        .accessibilityIdentifier("todayScreenTime")
    }
}
