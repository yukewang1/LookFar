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
}
#endif
