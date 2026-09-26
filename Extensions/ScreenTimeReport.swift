import DeviceActivity
import ExtensionKit
import SwiftUI

@main
struct ScreenTimeReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TodayTotalActivityReport { configuration in
            ScreenTimeMetric(value: configuration.value, detail: configuration.detail)
        }
    }
}

private struct ScreenTimeTotal {
    let value: String
    let detail: String
}

private struct TodayTotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .todayTotalActivity
    let content: (ScreenTimeTotal) -> ScreenTimeMetric

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ScreenTimeTotal {
        var duration: TimeInterval = 0
        var hasActivity = false
        for await device in data {
            for await segment in device.activitySegments {
                duration += segment.totalActivityDuration
                hasActivity = true
            }
        }
        guard hasActivity else {
            return ScreenTimeTotal(value: "—", detail: "No Screen Time data available for today yet.")
        }

        let minutes = Int(duration / 60)
        let value = minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
        return ScreenTimeTotal(value: value, detail: "All apps on this iPhone · updated by iOS")
    }
}
