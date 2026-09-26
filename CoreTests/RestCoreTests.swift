import Foundation
import XCTest
@testable import RestCore

final class RestCoreTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_789_800_000)

    func testStandardScheduleStartsTwentySecondRest() {
        XCTAssertEqual(RestSchedule.usageMinutes, 20)
        XCTAssertEqual(RestSchedule.restSeconds, 20)
        var state = RestState()
        RestLogic.start(&state, at: start)
        XCTAssertEqual(state.activeSession?.durationSeconds, 20)
    }

    func testStartingTwiceDoesNotReplaceOrExtendActiveSession() throws {
        var state = RestState()
        RestLogic.start(&state, at: start, durationOverride: 60)
        let original = try XCTUnwrap(state.activeSession)
        RestLogic.start(&state, at: start.addingTimeInterval(10), durationOverride: 5)
        XCTAssertEqual(state.activeSession, original)
        XCTAssertEqual(original.deadline, start.addingTimeInterval(60))
    }

    func testDeadlineRecoveredAfterPersistenceCompletesExactlyOnce() throws {
        var state = RestState()
        state.onboardingComplete = true
        RestLogic.start(&state, at: start)
        let session = try XCTUnwrap(state.activeSession)
        state = try JSONDecoder().decode(RestState.self, from: JSONEncoder().encode(state))

        XCTAssertTrue(state.onboardingComplete)
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

    func testOldSavedRoutineIsIgnoredWithoutLosingHistoryOrActiveDuration() throws {
        let recordID = UUID()
        let sessionID = UUID()
        let oldJSON = """
        {
            "onboardingComplete": true,
            "routine": "extended",
            "records": [{
                "id": "\(recordID.uuidString)",
                "date": \(start.timeIntervalSinceReferenceDate - 100),
                "durationSeconds": 60,
                "kind": "guided"
            }],
            "activeSession": {
                "id": "\(sessionID.uuidString)",
                "startedAt": \(start.timeIntervalSinceReferenceDate),
                "durationSeconds": 60
            }
        }
        """
        var state = try JSONDecoder().decode(RestState.self, from: Data(oldJSON.utf8))
        XCTAssertTrue(state.onboardingComplete)
        XCTAssertEqual(state.records, [RestRecord(
            id: recordID, date: start.addingTimeInterval(-100), durationSeconds: 60, kind: .guided
        )])
        XCTAssertEqual(state.activeSession, RestSession(id: sessionID, startedAt: start, durationSeconds: 60))
        XCTAssertFalse(RestLogic.completeIfDue(&state, at: start.addingTimeInterval(20)))
        XCTAssertTrue(RestLogic.completeIfDue(&state, at: start.addingTimeInterval(60)))
        XCTAssertEqual(state.records.last?.durationSeconds, 60)
        XCTAssertEqual(state.records.last?.id, sessionID)

        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        XCTAssertNil(saved["routine"])
        RestLogic.start(&state, at: start.addingTimeInterval(100))
        XCTAssertEqual(state.activeSession?.durationSeconds, 20)
    }

    func testGardenEarnsOneTreePerGuidedRestAndSortsTodaysCompletions() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let day = calendar.startOfDay(for: start)
        let previousDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: day))
        let records = [
            RestRecord(date: day.addingTimeInterval(200), durationSeconds: 20, kind: .guided),
            RestRecord(date: previousDay, durationSeconds: 60, kind: .guided),
            RestRecord(date: day.addingTimeInterval(100), durationSeconds: 20, kind: .guided),
            RestRecord(date: day.addingTimeInterval(50), durationSeconds: 0, kind: .confirmed),
            RestRecord(date: day.addingTimeInterval(70), durationSeconds: 0, kind: .skipped),
            RestRecord(date: day.addingTimeInterval(400), durationSeconds: 20, kind: .guided)
        ]
        let garden = RestGarden(records: records, asOf: day.addingTimeInterval(300), calendar: calendar)
        XCTAssertEqual(garden.trees, [records[2], records[0]])
        XCTAssertEqual(garden.treeCount, 2)
        XCTAssertEqual(garden.totalTreeCount, 3)
        XCTAssertEqual(garden.currentStreak, 2)

        let futureOnly = RestGarden(records: [records[5]], asOf: day.addingTimeInterval(300), calendar: calendar)
        XCTAssertTrue(futureOnly.trees.isEmpty)
        XCTAssertEqual(futureOnly.treeCount, 0)
        XCTAssertEqual(futureOnly.totalTreeCount, 0)
        XCTAssertEqual(futureOnly.currentStreak, 0)
    }

    func testGardenStartsEmptyNextDayWithoutLosingPersistedHistory() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Vancouver"))
        let today = calendar.startOfDay(for: start)
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: today))
        var state = RestState()
        state.records = [
            RestRecord(date: today.addingTimeInterval(100), durationSeconds: 20, kind: .guided),
            RestRecord(date: today.addingTimeInterval(200), durationSeconds: 20, kind: .guided)
        ]
        XCTAssertEqual(RestGarden(records: state.records, asOf: tomorrow.addingTimeInterval(-1), calendar: calendar).treeCount, 2)

        let restored = try JSONDecoder().decode(RestState.self, from: JSONEncoder().encode(state))
        let garden = RestGarden(records: restored.records, asOf: tomorrow, calendar: calendar)
        XCTAssertTrue(garden.trees.isEmpty)
        XCTAssertEqual(garden.treeCount, 0)
        XCTAssertEqual(garden.totalTreeCount, 2)
        XCTAssertEqual(garden.currentStreak, 1)
        XCTAssertEqual(restored.records, state.records)
    }

    func testGardenCountsCompletionDayAcrossLocalMidnight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Vancouver"))
        let formatter = ISO8601DateFormatter()
        let beforeMidnight = try XCTUnwrap(formatter.date(from: "2026-09-19T06:59:50Z"))
        let afterMidnight = beforeMidnight.addingTimeInterval(20)
        var state = RestState()
        RestLogic.start(&state, at: beforeMidnight)
        XCTAssertTrue(RestLogic.completeIfDue(&state, at: afterMidnight))
        let garden = RestGarden(records: state.records, asOf: afterMidnight, calendar: calendar)
        XCTAssertEqual(garden.treeCount, 1)
        XCTAssertEqual(garden.totalTreeCount, 1)
        XCTAssertEqual(garden.trees.first?.date, afterMidnight)
        XCTAssertEqual(RestGarden(records: state.records, asOf: beforeMidnight, calendar: calendar).treeCount, 0)
    }

    func testGardenUsesLocalDaysAndKeepsYesterdayStreakUntilTodayIsComplete() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Vancouver"))
        let formatter = ISO8601DateFormatter()
        let beforeMidnight = try XCTUnwrap(formatter.date(from: "2026-09-19T06:59:00Z"))
        let afterMidnight = try XCTUnwrap(formatter.date(from: "2026-09-19T07:01:00Z"))
        let records = [beforeMidnight, afterMidnight].map {
            RestRecord(date: $0, durationSeconds: 20, kind: .guided)
        }
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: afterMidnight))
        let dayAfterTomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: afterMidnight))
        let garden = RestGarden(records: records, asOf: tomorrow, calendar: calendar)
        XCTAssertEqual(garden.treeCount, 0)
        XCTAssertEqual(garden.totalTreeCount, 2)
        XCTAssertEqual(garden.currentStreak, 2)
        XCTAssertEqual(RestGarden(records: records, asOf: dayAfterTomorrow, calendar: calendar).currentStreak, 0)

        let firstDay = RestGarden(records: records, asOf: beforeMidnight, calendar: calendar)
        XCTAssertEqual(firstDay.trees, [records[0]])
        let secondDay = RestGarden(records: records, asOf: afterMidnight, calendar: calendar)
        XCTAssertEqual(secondDay.trees, [records[1]])
    }

    func testGardenStreakUsesCalendarDaysAcrossDaylightSavingTransition() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Vancouver"))
        let formatter = ISO8601DateFormatter()
        let dates = try ["2026-03-07T20:00:00Z", "2026-03-08T19:00:00Z", "2026-03-09T19:00:00Z"].map {
            try XCTUnwrap(formatter.date(from: $0))
        }
        let records = dates.map { RestRecord(date: $0, durationSeconds: 20, kind: .guided) }
        let garden = RestGarden(records: records, asOf: dates[2], calendar: calendar)
        XCTAssertEqual(garden.trees, [records[2]])
        XCTAssertEqual(garden.treeCount, 1)
        XCTAssertEqual(garden.totalTreeCount, 3)
        XCTAssertEqual(garden.currentStreak, 3)
    }
}
