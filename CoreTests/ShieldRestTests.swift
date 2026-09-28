import XCTest
@testable import RestCore

final class ShieldRestTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testOpeningAppKeepsTapTimeAndRepeatedHandoffCannotRestartRest() throws {
        var state = RestState()
        let session = RestSession(startedAt: start, durationSeconds: 20)
        for delay in [3.0, 8.0] {
            XCTAssertTrue(RestLogic.restoreStartedRests(&state, sessions: [session], at: start.addingTimeInterval(delay)))
            XCTAssertEqual(state.activeSession, session)
            XCTAssertEqual(RestLogic.remainingSeconds(try XCTUnwrap(state.activeSession), at: start.addingTimeInterval(delay)), 20 - Int(delay))
        }
        XCTAssertTrue(RestLogic.completeIfDue(&state, at: session.deadline))
        XCTAssertFalse(RestLogic.restoreStartedRests(&state, sessions: [session], at: session.deadline))
        XCTAssertEqual(state.records.count, 1)
    }

    func testLateHandoffRecordsCompletedRestOnceAfterMonitoringRearms() {
        var state = RestState()
        let session = RestSession(startedAt: start, durationSeconds: 10)
        XCTAssertTrue(RestLogic.restoreStartedRests(&state, sessions: [session], at: start.addingTimeInterval(30)))
        XCTAssertNil(state.activeSession)
        XCTAssertEqual(state.records.first?.id, session.id)
        XCTAssertEqual(state.records.first?.date, session.deadline)
        XCTAssertEqual(state.records.first?.durationSeconds, 10)
        XCTAssertFalse(RestLogic.restoreStartedRests(&state, sessions: [session], at: start.addingTimeInterval(60)))
        XCTAssertEqual(state.records.count, 1)
    }

    func testShieldSkipBeforeDeadlineDoesNotAwardTreeOnLateHandoff() {
        var state = RestState()
        let session = RestSession(startedAt: start, durationSeconds: 20)
        let skip = RestRecord(date: start.addingTimeInterval(5), durationSeconds: 0, kind: .skipped)
        state.records = [skip]
        XCTAssertFalse(RestLogic.restoreStartedRests(&state, sessions: [session], at: start.addingTimeInterval(30)))
        XCTAssertNil(state.activeSession)
        XCTAssertEqual(state.records, [skip])
    }

    func testOlderHandoffPreservesNewerActiveRest() {
        var state = RestState()
        let old = RestSession(startedAt: start, durationSeconds: 20)
        let current = RestSession(startedAt: start.addingTimeInterval(25), durationSeconds: 20)
        state.activeSession = current
        XCTAssertTrue(RestLogic.restoreStartedRests(&state, sessions: [old], at: start.addingTimeInterval(30)))
        XCTAssertEqual(state.activeSession, current)
        XCTAssertEqual(state.records.map(\.id), [old.id])
    }
}
