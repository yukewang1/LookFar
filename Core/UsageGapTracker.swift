import Foundation

/// Estimates time outside counted usage from cumulative usage checkpoints.
/// Callback delays and multiple shorter gaps can resemble one continuous break.
public struct UsageGapTracker: Codable, Equatable {
    public enum Result: Equatable {
        case ignored
        case continued
        case reset
    }

    private var highestUsageMinutes = 0
    private var lastCallbackAt: Date?

    public init() {}

    public mutating func record(usageMinutes: Int, at date: Date, calendar: Calendar = .current) -> Result {
        guard usageMinutes > 0 else { return .ignored }
        guard let lastCallbackAt, calendar.isDate(lastCallbackAt, inSameDayAs: date) else {
            highestUsageMinutes = usageMinutes
            self.lastCallbackAt = date
            return .continued
        }
        guard usageMinutes > highestUsageMinutes else { return .ignored }

        let elapsed = date.timeIntervalSince(lastCallbackAt)
        let countedUsage = TimeInterval(usageMinutes - highestUsageMinutes) * 60
        highestUsageMinutes = usageMinutes
        self.lastCallbackAt = date
        return elapsed - countedUsage >= 300 ? .reset : .continued
    }
}
