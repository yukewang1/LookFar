import Foundation

public enum RestSchedule {
    public static let usageMinutes = 20
    public static let restSeconds = 20
    public static let onboardingRestSeconds = 10
}

public enum RestRecordKind: String, Codable {
    case guided
    case confirmed
    case skipped
}

public struct RestRecord: Identifiable, Codable, Equatable {
    public var id: UUID
    public var date: Date
    public var durationSeconds: Int
    public var kind: RestRecordKind

    public init(id: UUID = UUID(), date: Date, durationSeconds: Int, kind: RestRecordKind) {
        self.id = id
        self.date = date
        self.durationSeconds = durationSeconds
        self.kind = kind
    }
}

public struct RestSession: Codable, Equatable {
    public var id: UUID
    public var startedAt: Date
    public var durationSeconds: Int

    public init(id: UUID = UUID(), startedAt: Date, durationSeconds: Int) {
        self.id = id
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
    }

    public var deadline: Date { startedAt.addingTimeInterval(TimeInterval(durationSeconds)) }
}

public struct RestState: Codable {
    public var onboardingComplete = false
    public var records: [RestRecord] = []
    public var activeSession: RestSession?

    public init() {}
}

public enum RestLogic {
    public static func start(_ state: inout RestState, at date: Date, durationOverride: Int? = nil) {
        guard state.activeSession == nil else { return }
        let duration = durationOverride ?? RestSchedule.restSeconds
        precondition(duration > 0, "A guided rest must have a positive duration.")
        state.activeSession = RestSession(startedAt: date, durationSeconds: duration)
    }

    @discardableResult
    public static func completeIfDue(_ state: inout RestState, at date: Date) -> Bool {
        guard let session = state.activeSession, date >= session.deadline else { return false }
        state.records.append(RestRecord(
            id: session.id,
            date: session.deadline,
            durationSeconds: session.durationSeconds,
            kind: .guided
        ))
        state.activeSession = nil
        return true
    }

    public static func skip(_ state: inout RestState, at date: Date) {
        state.activeSession = nil
        state.records.append(RestRecord(date: date, durationSeconds: 0, kind: .skipped))
    }

    public static func confirmBreak(_ state: inout RestState, at date: Date) {
        state.activeSession = nil
        state.records.append(RestRecord(date: date, durationSeconds: 0, kind: .confirmed))
    }

    public static func remainingSeconds(_ session: RestSession, at date: Date) -> Int {
        max(0, Int(ceil(session.deadline.timeIntervalSince(date))))
    }
}

public struct RestMetrics {
    public let guidedCount: Int
    public let guidedSeconds: Int
    public let confirmedCount: Int
    public let skippedCount: Int
    public let activeDays: Int

    public init(records: [RestRecord], start: Date, end: Date, calendar: Calendar) {
        let included = records.filter { $0.date >= start && $0.date < end }
        let guided = included.filter { $0.kind == .guided }
        guidedCount = guided.count
        guidedSeconds = guided.reduce(0) { $0 + $1.durationSeconds }
        confirmedCount = included.filter { $0.kind == .confirmed }.count
        skippedCount = included.filter { $0.kind == .skipped }.count
        activeDays = Set(guided.map { calendar.startOfDay(for: $0.date) }).count
    }
}

public struct RestGarden {
    public let trees: [RestRecord]
    public let totalTreeCount: Int
    public let currentStreak: Int

    public var treeCount: Int { trees.count }

    public init(records: [RestRecord], asOf date: Date = Date(), calendar: Calendar = .current) {
        let completed = records.filter { $0.kind == .guided && $0.date <= date }
        trees = completed.filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
        totalTreeCount = completed.count
        let days = Set(completed.map { calendar.startOfDay(for: $0.date) })

        var day = calendar.startOfDay(for: date)
        if !days.contains(day) {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var streak = 0
        while days.contains(day) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        currentStreak = streak
    }
}
