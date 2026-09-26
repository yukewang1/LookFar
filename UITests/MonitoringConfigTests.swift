import XCTest

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
}
