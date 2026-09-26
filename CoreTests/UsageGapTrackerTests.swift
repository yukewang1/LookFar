import Foundation
import XCTest
@testable import RestCore

final class UsageGapTrackerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testFirstCheckpointEstablishesBaselineWithoutInferringEarlierIdleTime() {
        var tracker = UsageGapTracker()

        XCTAssertEqual(tracker.record(usageMinutes: 10, at: start, calendar: calendar), .continued)
        XCTAssertEqual(tracker.record(usageMinutes: 11, at: start.addingTimeInterval(60), calendar: calendar), .continued)
    }

    func testContinuousUseDoesNotReset() {
        var tracker = UsageGapTracker()

        for minute in 1...20 {
            XCTAssertEqual(tracker.record(
                usageMinutes: minute,
                at: start.addingTimeInterval(TimeInterval(minute * 60)),
                calendar: calendar
            ), .continued)
        }
    }

    func testTenMinutesThenLongIdleResetsWhenUseResumes() {
        var tracker = UsageGapTracker()
        XCTAssertEqual(tracker.record(usageMinutes: 10, at: start, calendar: calendar), .continued)

        XCTAssertEqual(tracker.record(usageMinutes: 11, at: start.addingTimeInterval(3_660), calendar: calendar), .reset)
    }

    func testExactlyFiveMinutesOfInferredGapResets() {
        var tracker = UsageGapTracker()
        XCTAssertEqual(tracker.record(usageMinutes: 10, at: start, calendar: calendar), .continued)

        XCTAssertEqual(tracker.record(usageMinutes: 11, at: start.addingTimeInterval(360), calendar: calendar), .reset)
    }

    func testGapBelowFiveMinutesDoesNotReset() {
        var tracker = UsageGapTracker()
        XCTAssertEqual(tracker.record(usageMinutes: 10, at: start, calendar: calendar), .continued)

        XCTAssertEqual(tracker.record(usageMinutes: 11, at: start.addingTimeInterval(359.99), calendar: calendar), .continued)
    }

    func testSkippedCheckpointsSubtractAllNewUsage() {
        var tracker = UsageGapTracker()
        XCTAssertEqual(tracker.record(usageMinutes: 2, at: start, calendar: calendar), .continued)
        XCTAssertEqual(tracker.record(usageMinutes: 10, at: start.addingTimeInterval(480), calendar: calendar), .continued)

        XCTAssertEqual(tracker.record(usageMinutes: 20, at: start.addingTimeInterval(1_380), calendar: calendar), .reset)
    }

    func testIgnoredCheckpointsDoNotMoveTheBaseline() {
        var tracker = UsageGapTracker()
        XCTAssertEqual(tracker.record(usageMinutes: 10, at: start, calendar: calendar), .continued)
        let baseline = tracker

        for minute in [10, 9, 0, -1] {
            XCTAssertEqual(tracker.record(usageMinutes: minute, at: start.addingTimeInterval(350), calendar: calendar), .ignored)
            XCTAssertEqual(tracker, baseline)
        }
        XCTAssertEqual(tracker.record(usageMinutes: 11, at: start.addingTimeInterval(360), calendar: calendar), .reset)
    }

    func testNonpositiveFirstCheckpointDoesNotEstablishBaseline() {
        var tracker = UsageGapTracker()

        XCTAssertEqual(tracker.record(usageMinutes: 0, at: start, calendar: calendar), .ignored)
        XCTAssertEqual(tracker, UsageGapTracker())
        XCTAssertEqual(tracker.record(usageMinutes: 1, at: start.addingTimeInterval(3_600), calendar: calendar), .continued)
    }

    func testPersistenceRetainsCheckpointForGapInference() throws {
        var tracker = UsageGapTracker()
        XCTAssertEqual(tracker.record(usageMinutes: 10, at: start, calendar: calendar), .continued)
        var restored = try JSONDecoder().decode(UsageGapTracker.self, from: JSONEncoder().encode(tracker))

        XCTAssertEqual(restored, tracker)
        XCTAssertEqual(restored.record(usageMinutes: 11, at: start.addingTimeInterval(360), calendar: calendar), .reset)
    }

    func testNewLocalDayRebasesWithoutInferringAnOvernightGap() throws {
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Vancouver"))
        let formatter = ISO8601DateFormatter()
        let beforeMidnight = try XCTUnwrap(formatter.date(from: "2026-09-19T06:59:00Z"))
        let afterMidnight = beforeMidnight.addingTimeInterval(3_660)
        var tracker = UsageGapTracker()
        XCTAssertEqual(tracker.record(usageMinutes: 19, at: beforeMidnight, calendar: localCalendar), .continued)

        XCTAssertEqual(tracker.record(usageMinutes: 1, at: afterMidnight, calendar: localCalendar), .continued)
        XCTAssertEqual(tracker.record(usageMinutes: 2, at: afterMidnight.addingTimeInterval(360), calendar: localCalendar), .reset)
    }

    func testClockRollbackRebasesForwardCheckpoint() {
        var tracker = UsageGapTracker()
        XCTAssertEqual(tracker.record(usageMinutes: 10, at: start, calendar: calendar), .continued)
        let rolledBack = start.addingTimeInterval(-60)

        XCTAssertEqual(tracker.record(usageMinutes: 11, at: rolledBack, calendar: calendar), .continued)
        XCTAssertEqual(tracker.record(usageMinutes: 12, at: rolledBack.addingTimeInterval(360), calendar: calendar), .reset)
    }
}
