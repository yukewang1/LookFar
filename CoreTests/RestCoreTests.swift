import Foundation
import XCTest
@testable import RestCore

final class RestCoreTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_789_800_000)

    func testRoutinePresets() {
        XCTAssertEqual(RestRoutine.allCases.map(\.usageMinutes), [20, 10, 20])
        XCTAssertEqual(RestRoutine.allCases.map(\.restSeconds), [20, 20, 60])
        XCTAssertEqual(RestRoutine.allCases.map(\.title), ["Classic", "Frequent", "Longer"])
    }

    func testStartingTwiceDoesNotReplaceOrExtendActiveSession() throws {
        var state = RestState()
        state.routine = .extended
        RestLogic.start(&state, at: start)
        let original = try XCTUnwrap(state.activeSession)
        RestLogic.start(&state, at: start.addingTimeInterval(10), durationOverride: 5)
        XCTAssertEqual(state.activeSession, original)
        XCTAssertEqual(original.deadline, start.addingTimeInterval(60))
    }

    func testDeadlineRecoveredAfterPersistenceCompletesExactlyOnce() throws {
        var state = RestState()
        state.onboardingComplete = true
        state.routine = .frequent
        RestLogic.start(&state, at: start)
        let session = try XCTUnwrap(state.activeSession)
        state = try JSONDecoder().decode(RestState.self, from: JSONEncoder().encode(state))

        XCTAssertTrue(state.onboardingComplete)
        XCTAssertEqual(state.routine, .frequent)
        XCTAssertFalse(RestLogic.completeIfDue(&state, at: start.addingTimeInterval(19.99)))
        XCTAssertTrue(state.records.isEmpty)
        XCTAssertTrue(RestLogic.completeIfDue(&state, at: start.addingTimeInterval(3_600)))
        XCTAssertNil(state.activeSession)
        XCTAssertEqual(state.records, [RestRecord(
            id: session.id,
            date: start.addingTimeInterval(20),
            durationSeconds: 20,
            kind: .guided
        )])

        state = try JSONDecoder().decode(RestState.self, from: JSONEncoder().encode(state))
        XCTAssertFalse(RestLogic.completeIfDue(&state, at: start.addingTimeInterval(7_200)))
        XCTAssertEqual(state.records.count, 1)
    }

    func testExactDeadlineAndFractionalCountdown() throws {
        var state = RestState()
        RestLogic.start(&state, at: start, durationOverride: 3)
        let session = try XCTUnwrap(state.activeSession)
        XCTAssertEqual(RestLogic.remainingSeconds(session, at: start), 3)
        XCTAssertEqual(RestLogic.remainingSeconds(session, at: start.addingTimeInterval(2.01)), 1)
        XCTAssertEqual(RestLogic.remainingSeconds(session, at: start.addingTimeInterval(3)), 0)
        XCTAssertEqual(RestLogic.remainingSeconds(session, at: start.addingTimeInterval(30)), 0)
        XCTAssertTrue(RestLogic.completeIfDue(&state, at: start.addingTimeInterval(3)))
    }

    func testSkipClearsSessionWithoutRecordingGuidedTime() {
        var state = RestState()
        RestLogic.start(&state, at: start)
        RestLogic.skip(&state, at: start.addingTimeInterval(5))
        XCTAssertNil(state.activeSession)
        XCTAssertFalse(RestLogic.completeIfDue(&state, at: start.addingTimeInterval(100)))
        XCTAssertEqual(state.records.map(\.kind), [.skipped])
        XCTAssertEqual(state.records.map(\.durationSeconds), [0])
    }

    func testConfirmedBreakClearsSessionAndKeepsDistinctCategory() {
        var state = RestState()
        RestLogic.start(&state, at: start)
        RestLogic.confirmBreak(&state, at: start.addingTimeInterval(5))
        XCTAssertNil(state.activeSession)
        XCTAssertFalse(RestLogic.completeIfDue(&state, at: start.addingTimeInterval(100)))
        XCTAssertEqual(state.records.map(\.kind), [.confirmed])
        XCTAssertEqual(state.records.map(\.durationSeconds), [0])
    }

    func testManualBreakAndSkipCanBeRecordedWithoutActiveTimer() {
        var state = RestState()
        RestLogic.confirmBreak(&state, at: start)
        RestLogic.skip(&state, at: start.addingTimeInterval(30))
        XCTAssertEqual(state.records.map(\.kind), [.confirmed, .skipped])
    }

    func testMetricsUseHalfOpenIntervalAndDoNotInflateGuidedTotals() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let day = calendar.startOfDay(for: start)
        let nextDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: day))
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 3, to: day))
        let records = [
            RestRecord(date: day.addingTimeInterval(-1), durationSeconds: 60, kind: .guided),
            RestRecord(date: day, durationSeconds: 20, kind: .guided),
            RestRecord(date: day.addingTimeInterval(60), durationSeconds: 60, kind: .guided),
            RestRecord(date: nextDay, durationSeconds: 20, kind: .guided),
            RestRecord(date: nextDay.addingTimeInterval(60), durationSeconds: 0, kind: .confirmed),
            RestRecord(date: end.addingTimeInterval(-1), durationSeconds: 0, kind: .skipped),
            RestRecord(date: end, durationSeconds: 60, kind: .guided)
        ]
        let metrics = RestMetrics(records: records, start: day, end: end, calendar: calendar)
        XCTAssertEqual(metrics.guidedCount, 3)
        XCTAssertEqual(metrics.guidedSeconds, 100)
        XCTAssertEqual(metrics.confirmedCount, 1)
        XCTAssertEqual(metrics.skippedCount, 1)
        XCTAssertEqual(metrics.activeDays, 2)
    }

    func testActiveDaysFollowProvidedTimeZone() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Vancouver"))
        let formatter = ISO8601DateFormatter()
        let beforeMidnight = try XCTUnwrap(formatter.date(from: "2026-09-19T06:59:00Z"))
        let afterMidnight = try XCTUnwrap(formatter.date(from: "2026-09-19T07:01:00Z"))
        let records = [beforeMidnight, afterMidnight].map {
            RestRecord(date: $0, durationSeconds: 20, kind: .guided)
        }
        let metrics = RestMetrics(
            records: records,
            start: beforeMidnight,
            end: afterMidnight.addingTimeInterval(1),
            calendar: calendar
        )
        XCTAssertEqual(metrics.activeDays, 2)
    }
}
