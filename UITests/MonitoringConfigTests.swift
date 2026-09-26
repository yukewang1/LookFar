import XCTest
import DeviceActivity

final class MonitoringConfigTests: XCTestCase {
    func testLegacySettingsKeepCustomIntervalAndPendingBreak() throws {
        let deadline = Date(timeIntervalSince1970: 1_800_000_000)
        var original = MonitoringConfig()
        original.useMinutes = 30
        original.enabled = true
        original.pendingBreak = true
        original.breakDeadline = deadline
        original.activityName = "lookfar.cycle.legacy"
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        legacy.removeValue(forKey: "restSeconds")
        legacy["startHour"] = 8
        legacy["endHour"] = 22

        let restored = try JSONDecoder().decode(MonitoringConfig.self, from: JSONSerialization.data(withJSONObject: legacy))

        XCTAssertEqual(restored.useMinutes, 30)
        XCTAssertEqual(restored.restSeconds, 20)
        XCTAssertTrue(restored.enabled)
        XCTAssertTrue(restored.pendingBreak)
        XCTAssertEqual(restored.breakDeadline, deadline)
        XCTAssertEqual(restored.activityName, "lookfar.cycle.legacy")
        let migrated = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(restored)) as? [String: Any])
        XCTAssertNil(migrated["startHour"])
        XCTAssertNil(migrated["endHour"])
    }

    func testCustomizedRhythmSurvivesRoundTrip() throws {
        var original = MonitoringConfig()
        original.useMinutes = 30
        original.restSeconds = 10

        let restored = try JSONDecoder().decode(MonitoringConfig.self, from: JSONEncoder().encode(original))

        XCTAssertEqual(restored.useMinutes, 30)
        XCTAssertEqual(restored.restSeconds, 10)
    }

    func testMonitoringScheduleCoversTheWholeDay() {
        let schedule = ScreenTimeSupport.allDaySchedule

        XCTAssertEqual(schedule.intervalStart, DateComponents(hour: 0, minute: 0))
        XCTAssertEqual(schedule.intervalEnd, DateComponents(hour: 0, minute: 0))
        XCTAssertTrue(schedule.repeats)
    }

    func testUsageCheckpointHistoryIsSeparateFromMonitoringConfiguration() throws {
        var original = MonitoringConfig()
        original.enabled = true
        original.useMinutes = 30
        original.restSeconds = 10
        original.activityName = "lookfar.cycle.current"
        let originalConfig = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? NSDictionary)
        var tracker = UsageGapTracker()

        XCTAssertEqual(original.recordUsageCheckpoint(minutes: 10, at: checkpointStart, tracker: &tracker), .save)

        let updatedConfig = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? NSDictionary)
        XCTAssertEqual(updatedConfig, originalConfig)
        XCTAssertNil(updatedConfig["usageGapTracker"])
        XCTAssertNil(updatedConfig["tracker"])
        XCTAssertNotEqual(tracker, UsageGapTracker())
    }

    func testSavedUsageHistoryPreservesGapDecisionAfterRoundTrip() throws {
        var original = MonitoringConfig()
        original.enabled = true
        var tracker = UsageGapTracker()
        XCTAssertEqual(original.recordUsageCheckpoint(minutes: 4, at: checkpointStart, tracker: &tracker), .save)
        let state = UsageCheckpointState(activityName: "lookfar.cycle.current", tracker: tracker)
        let restoredState = try JSONDecoder().decode(UsageCheckpointState.self, from: JSONEncoder().encode(state))
        var restoredTracker = restoredState.tracker(for: "lookfar.cycle.current")
        var restoredConfig = original

        XCTAssertEqual(restoredTracker, tracker)
        let resumedAt = checkpointStart.addingTimeInterval(360)
        XCTAssertEqual(original.recordUsageCheckpoint(minutes: 5, at: resumedAt, tracker: &tracker), .restart)
        XCTAssertEqual(restoredConfig.recordUsageCheckpoint(minutes: 5, at: resumedAt, tracker: &restoredTracker), .restart)
        XCTAssertEqual(restoredTracker, tracker)
        XCTAssertFalse(restoredConfig.pendingBreak)
    }

    func testCheckpointHistoryFromAnotherGenerationStartsFresh() {
        var tracker = UsageGapTracker()
        XCTAssertEqual(tracker.record(usageMinutes: 19, at: checkpointStart), .continued)
        let state = UsageCheckpointState(activityName: "lookfar.cycle.old", tracker: tracker)
        var freshTracker = state.tracker(for: "lookfar.cycle.new")

        XCTAssertEqual(freshTracker, UsageGapTracker())
        XCTAssertEqual(freshTracker.record(usageMinutes: 1, at: checkpointStart.addingTimeInterval(600)), .continued)
        XCTAssertEqual(state.tracker(for: "lookfar.cycle.old"), tracker)
    }

    func testMonitoringEventsCoverEveryMinuteOfSupportedIntervals() throws {
        for limit in [1, 5, 20, 30, 120] {
            var config = MonitoringConfig()
            config.useMinutes = limit

            let events = ScreenTimeSupport.monitoringEvents(for: config)

            XCTAssertEqual(events.count, limit)
            for minute in 1...limit {
                let name = minute == limit
                    ? ScreenTimeSupport.thresholdEvent
                    : DeviceActivityEvent.Name("lookfar.usage-minute.\(minute)")
                let event = try XCTUnwrap(events[name])
                XCTAssertEqual(event.threshold, DateComponents(minute: minute))
                XCTAssertEqual(event.applications, config.selection.applicationTokens)
                XCTAssertEqual(event.categories, config.selection.categoryTokens)
                XCTAssertEqual(event.webDomains, config.selection.webDomainTokens)
                XCTAssertFalse(event.includesPastActivity)
                XCTAssertEqual(ScreenTimeSupport.usageMinutes(for: name, limit: limit), minute)
            }
            XCTAssertNil(events[DeviceActivityEvent.Name("lookfar.usage-minute.\(limit)")])
        }
    }

    func testMonitoringEventsRejectNonpositiveIntervals() {
        for limit in [0, -1] {
            var config = MonitoringConfig()
            config.useMinutes = limit

            XCTAssertTrue(ScreenTimeSupport.monitoringEvents(for: config).isEmpty)
        }
    }

    func testUsageEventParserRejectsUnknownInvalidAndOutOfRangeEvents() {
        for name in ["unknown", "lookfar.usage-minute", "lookfar.usage-minute.",
                     "lookfar.usage-minute.invalid", "lookfar.usage-minute.1.5",
                     "lookfar.usage-minute.-1", "lookfar.usage-minute.0",
                     "lookfar.usage-minute.20", "lookfar.usage-minute.21"] {
            XCTAssertNil(ScreenTimeSupport.usageMinutes(for: DeviceActivityEvent.Name(name), limit: 20), name)
        }
        for limit in [0, -1] {
            XCTAssertNil(ScreenTimeSupport.usageMinutes(for: ScreenTimeSupport.thresholdEvent, limit: limit))
            XCTAssertNil(ScreenTimeSupport.usageMinutes(for: DeviceActivityEvent.Name("lookfar.usage-minute.1"), limit: limit))
        }
    }

    func testContinuousCheckpointsSaveUntilTheThresholdBlocks() {
        var config = MonitoringConfig()
        config.enabled = true
        config.useMinutes = 5
        var tracker = UsageGapTracker()

        for minute in 1..<5 {
            XCTAssertEqual(config.recordUsageCheckpoint(minutes: minute, at: checkpointStart.addingTimeInterval(Double(minute - 1) * 60), tracker: &tracker), .save)
            XCTAssertFalse(config.pendingBreak)
        }
        XCTAssertEqual(config.recordUsageCheckpoint(minutes: 5, at: checkpointStart.addingTimeInterval(240), tracker: &tracker), .shield)
        XCTAssertTrue(config.pendingBreak)
        XCTAssertNil(config.breakDeadline)
    }

    func testGapAtFinalCheckpointRestartsBeforeBlocking() {
        var config = MonitoringConfig()
        config.enabled = true
        var tracker = UsageGapTracker()
        XCTAssertEqual(config.recordUsageCheckpoint(minutes: 19, at: checkpointStart, tracker: &tracker), .save)

        XCTAssertEqual(config.recordUsageCheckpoint(minutes: 20, at: checkpointStart.addingTimeInterval(360), tracker: &tracker), .restart)

        XCTAssertFalse(config.pendingBreak)
        XCTAssertNil(config.breakDeadline)
    }

    func testDuplicateAndOlderUsageCheckpointsAreIgnoredWithoutChangingHistory() {
        var config = MonitoringConfig()
        config.enabled = true
        var tracker = UsageGapTracker()
        XCTAssertEqual(config.recordUsageCheckpoint(minutes: 4, at: checkpointStart, tracker: &tracker), .save)
        let savedTracker = tracker

        XCTAssertEqual(config.recordUsageCheckpoint(minutes: 4, at: checkpointStart.addingTimeInterval(600), tracker: &tracker), .ignore)
        XCTAssertEqual(config.recordUsageCheckpoint(minutes: 3, at: checkpointStart.addingTimeInterval(660), tracker: &tracker), .ignore)

        XCTAssertEqual(tracker, savedTracker)
        XCTAssertFalse(config.pendingBreak)
    }

    func testPendingAndActiveBreaksIgnoreCheckpointsAndKeepTheirState() {
        let deadline = checkpointStart.addingTimeInterval(900)
        for (pendingBreak, breakDeadline) in [(true, nil as Date?), (false, deadline), (true, deadline)] {
            var config = MonitoringConfig()
            config.enabled = true
            var tracker = UsageGapTracker()
            XCTAssertEqual(config.recordUsageCheckpoint(minutes: 19, at: checkpointStart, tracker: &tracker), .save)
            config.pendingBreak = pendingBreak
            config.breakDeadline = breakDeadline
            let savedTracker = tracker

            XCTAssertEqual(config.recordUsageCheckpoint(minutes: 20, at: checkpointStart.addingTimeInterval(360), tracker: &tracker), .ignore)

            XCTAssertEqual(config.pendingBreak, pendingBreak)
            XCTAssertEqual(config.breakDeadline, breakDeadline)
            XCTAssertEqual(tracker, savedTracker)
        }
    }

    func testExpiredManualAndPendingGuidedBreaksRequestRestart() {
        let deadline = checkpointStart.addingTimeInterval(20)
        for pendingBreak in [false, true] {
            var config = MonitoringConfig()
            config.enabled = true
            var tracker = UsageGapTracker()
            XCTAssertEqual(config.recordUsageCheckpoint(minutes: 19, at: checkpointStart, tracker: &tracker), .save)
            config.pendingBreak = pendingBreak
            config.breakDeadline = deadline
            let savedTracker = tracker

            for callbackAt in [deadline, deadline.addingTimeInterval(60)] {
                XCTAssertEqual(config.recordUsageCheckpoint(minutes: 20, at: callbackAt, tracker: &tracker), .restart)
                XCTAssertEqual(config.pendingBreak, pendingBreak)
                XCTAssertEqual(config.breakDeadline, deadline)
                XCTAssertEqual(tracker, savedTracker)
            }
        }
    }

    func testDisabledAndInvalidCheckpointsLeaveUsageHistoryUntouched() {
        var config = MonitoringConfig()
        config.enabled = true
        var tracker = UsageGapTracker()
        XCTAssertEqual(config.recordUsageCheckpoint(minutes: 1, at: checkpointStart, tracker: &tracker), .save)
        let savedTracker = tracker
        let later = checkpointStart.addingTimeInterval(600)

        for minute in [-1, 0, config.useMinutes + 1] {
            XCTAssertEqual(config.recordUsageCheckpoint(minutes: minute, at: later, tracker: &tracker), .ignore)
            XCTAssertEqual(tracker, savedTracker)
        }
        config.enabled = false
        XCTAssertEqual(config.recordUsageCheckpoint(minutes: 2, at: later, tracker: &tracker), .ignore)
        XCTAssertEqual(tracker, savedTracker)
        XCTAssertFalse(config.pendingBreak)
    }

    func testFreshTrackerStartsANewCounterAfterGapRestart() {
        var config = MonitoringConfig()
        config.enabled = true
        config.useMinutes = 5
        var tracker = UsageGapTracker()
        XCTAssertEqual(config.recordUsageCheckpoint(minutes: 4, at: checkpointStart, tracker: &tracker), .save)
        XCTAssertEqual(config.recordUsageCheckpoint(minutes: 5, at: checkpointStart.addingTimeInterval(360), tracker: &tracker), .restart)
        tracker = UsageGapTracker()

        XCTAssertEqual(config.recordUsageCheckpoint(minutes: 1, at: checkpointStart.addingTimeInterval(420), tracker: &tracker), .save)
        XCTAssertFalse(config.pendingBreak)
        XCTAssertEqual(config.recordUsageCheckpoint(minutes: 5, at: checkpointStart.addingTimeInterval(660), tracker: &tracker), .shield)
        XCTAssertTrue(config.pendingBreak)
    }

    private var checkpointStart: Date {
        Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000)).addingTimeInterval(12 * 60 * 60)
    }
}
