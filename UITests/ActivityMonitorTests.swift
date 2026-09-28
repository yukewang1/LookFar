import DeviceActivity
import FamilyControls
import XCTest

#if targetEnvironment(simulator)
/// Exercise the real extension entry points in a fresh, unauthorized process.
/// This verifies our callback handling, not delivery or shielding by iOS.
final class ActivityMonitorTests: XCTestCase {
    private var savedConfig: MonitoringConfig!
    private var config: MonitoringConfig!
    private var monitor: ActivityMonitor!

    override func setUpWithError() throws {
        savedConfig = try ScreenTimeSupport.load()
        config = MonitoringConfig()
        config.enabled = true
        config.useMinutes = 5
        config.activityName = ScreenTimeSupport.activityPrefix + UUID().uuidString
        try ScreenTimeSupport.save(config)
        monitor = ActivityMonitor()
    }

    override func tearDownWithError() throws {
        try ScreenTimeSupport.save(savedConfig)
        try ScreenTimeSupport.acknowledgeStartedRests(ids: Set(ScreenTimeSupport.pendingStartedRests().map(\.id)))
    }

    func testShieldTapStartsRestOnceAndPreservesHandoffAfterRearm() throws {
        config.pendingBreak = true
        config.restSeconds = 10
        try ScreenTimeSupport.save(config)
        let tappedAt = Date.now
        try ScreenTimeSupport.startBreakFromShield(at: tappedAt)
        try ScreenTimeSupport.startBreakFromShield(at: tappedAt.addingTimeInterval(2))
        let starts = try ScreenTimeSupport.pendingStartedRests()
        XCTAssertEqual(starts.count, 1)
        let session = try XCTUnwrap(starts.first)
        XCTAssertEqual(session.startedAt, tappedAt)
        XCTAssertEqual(session.durationSeconds, 10)
        XCTAssertEqual(try ScreenTimeSupport.load().breakDeadline, session.deadline)

        config.activityName = "lookfar.cycle.next"
        config.pendingBreak = false
        config.breakDeadline = nil
        try ScreenTimeSupport.save(config)
        XCTAssertEqual(try ScreenTimeSupport.pendingStartedRests(), starts)
        try ScreenTimeSupport.acknowledgeStartedRests(ids: [session.id])
        XCTAssertTrue(try ScreenTimeSupport.pendingStartedRests().isEmpty)
    }

    func testStaleOrDisabledShieldCannotStartRest() throws {
        try ScreenTimeSupport.startBreakFromShield()
        XCTAssertTrue(try ScreenTimeSupport.pendingStartedRests().isEmpty)
        config.pendingBreak = true
        config.enabled = false
        try ScreenTimeSupport.save(config)
        try ScreenTimeSupport.startBreakFromShield()
        XCTAssertTrue(try ScreenTimeSupport.pendingStartedRests().isEmpty)
    }

    func testFreshExtensionProcessesThresholdWithoutRequestingAuthorization() throws {
        XCTAssertEqual(AuthorizationCenter.shared.authorizationStatus, .notDetermined)
        monitor.eventDidReachThreshold(ScreenTimeSupport.thresholdEvent, activity: DeviceActivityName(config.activityName!))
        XCTAssertTrue(try ScreenTimeSupport.load().pendingBreak)
        XCTAssertTrue(try ScreenTimeSupport.load().enabled)
    }

    func testIntervalStartDoesNotErasePendingBreakInFreshExtension() throws {
        config.pendingBreak = true
        try ScreenTimeSupport.save(config)
        monitor.intervalDidStart(for: DeviceActivityName(config.activityName!))
        XCTAssertTrue(try ScreenTimeSupport.load().pendingBreak)
    }

    func testStaleAndDisabledCallbacksCannotCreateBreaks() throws {
        monitor.eventDidReachThreshold(ScreenTimeSupport.thresholdEvent, activity: DeviceActivityName("lookfar.cycle.old"))
        XCTAssertFalse(try ScreenTimeSupport.load().pendingBreak)
        config.enabled = false
        try ScreenTimeSupport.save(config)
        monitor.eventDidReachThreshold(ScreenTimeSupport.thresholdEvent, activity: DeviceActivityName(config.activityName!))
        XCTAssertFalse(try ScreenTimeSupport.load().pendingBreak)
    }

    func testDisabledIntervalClearsPendingBreak() throws {
        config.enabled = false
        config.pendingBreak = true
        try ScreenTimeSupport.save(config)
        monitor.intervalDidStart(for: DeviceActivityName(config.activityName!))
        XCTAssertFalse(try ScreenTimeSupport.load().pendingBreak)
    }

    func testCompletingOlderLocalRestPreservesNewCycleAndPendingBreak() throws {
        for pending in [false, true] {
            config.pendingBreak = pending
            config.breakDeadline = nil // The extension already rearmed after the old rest.
            try ScreenTimeSupport.save(config)
            try ScreenTimeSupport.rearm(reason: "Guided rest completed", onlyIfRestExpired: true)
            let current = try ScreenTimeSupport.load()
            XCTAssertEqual(current.activityName, config.activityName)
            XCTAssertTrue(current.enabled)
            XCTAssertEqual(current.pendingBreak, pending)
        }
    }

    func testCompletingOlderLocalRestDoesNotShortenCurrentRest() throws {
        config.breakDeadline = .now.addingTimeInterval(60)
        try ScreenTimeSupport.save(config)
        try ScreenTimeSupport.rearm(reason: "Guided rest completed", onlyIfRestExpired: true)
        let current = try ScreenTimeSupport.load()
        XCTAssertEqual(current.activityName, config.activityName)
        XCTAssertEqual(current.breakDeadline, config.breakDeadline)
    }

    @MainActor func testDelayedBreakRegistrationUsesLocalSessionsExactDeadline() throws {
        let manager = ScreenTimeManager()
        config.pendingBreak = true
        try ScreenTimeSupport.save(config)
        var state = RestState()
        // Register after the session has already elapsed to model a delayed persistence step.
        RestLogic.start(&state, at: Date.now.addingTimeInterval(-30), durationOverride: 20)
        let session = try XCTUnwrap(state.activeSession)

        try manager.beginBreak(deadline: session.deadline)

        var shared = try ScreenTimeSupport.load()
        XCTAssertEqual(shared.breakDeadline, session.deadline)
        XCTAssertTrue(shared.pendingBreak)
        XCTAssertTrue(RestLogic.completeIfDue(&state, at: session.deadline))
        var tracker = UsageGapTracker()
        XCTAssertEqual(shared.recordUsageCheckpoint(minutes: shared.useMinutes, at: session.deadline, tracker: &tracker), .restart)
    }

    @MainActor func testCycleResetUsesSavedTimingInsteadOfManagersCachedTiming() throws {
        let manager = ScreenTimeManager()
        XCTAssertEqual(manager.usageMinutes, 5)
        config.enabled = false // Exercise persistence without real Simulator monitoring.
        config.useMinutes = 30
        config.restSeconds = 10
        try ScreenTimeSupport.save(config)

        try manager.resetCycle(reason: "Rest completed after preferences changed")

        let saved = try ScreenTimeSupport.load()
        XCTAssertEqual(saved.useMinutes, 30)
        XCTAssertEqual(saved.restSeconds, 10)
        XCTAssertEqual(manager.usageMinutes, 30)
        XCTAssertEqual(manager.restSeconds, 10)
    }
}
#endif
