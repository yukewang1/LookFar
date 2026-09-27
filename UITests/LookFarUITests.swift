import XCTest

final class LookFarUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testBreakArrivingWhileAppRemainsOpenIsPresented() throws {
        let app = launch(skipOnboarding: true, extraArguments: ["--ui-testing-delayed-break"])
        XCTAssertTrue(app.staticTexts["treeCount"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["pauseStart"].waitForExistence(timeout: 12))
        attach(app, "foreground-break-prompt")
        tap(app.buttons["pauseSkip"], in: app)
        XCTAssertTrue(app.staticTexts["treeCount"].waitForExistence(timeout: 5))
    }

    @MainActor func testDiagnosticsAreReachableAndReportCanBeCopied() throws {
        let app = launch(skipOnboarding: true)
        tap(app.buttons["Settings"], in: app)
        for _ in 0..<6 where !app.buttons["openDiagnostics"].isHittable {
            app.collectionViews.firstMatch.swipeUp()
        }
        tap(app.buttons["openDiagnostics"], in: app)
        XCTAssertTrue(app.staticTexts["diagnosticStatus"].waitForExistence(timeout: 5))
        let bundle = Bundle(for: Self.self)
        let version = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        let build = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        XCTAssertTrue(app.staticTexts["diagnosticStatus"].label.contains("Version: \(version) (\(build))"))
        XCTAssertTrue(app.staticTexts["diagnosticStatus"].label.contains("SIMULATOR FIXTURE"))
        tap(app.buttons["copyDiagnostics"], in: app)
        XCTAssertEqual(app.buttons["copyDiagnostics"].label, "Report copied")
        attach(app, "monitoring-diagnostics")
    }

    @MainActor func testOnboardingPlantsFirstTreeAndOpensHistory() throws {
        let app = launch(fullRest: true, screenTime: .notDetermined)
        XCTAssertTrue(app.staticTexts["Build a habit\nfor your eyes."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["onboardingStartRest"].isHittable)
        XCTAssertEqual(app.buttons["onboardingStartRest"].label, "Try a 10-second break")
        XCTAssertFalse(app.buttons["editRhythm"].exists)
        XCTAssertFalse(app.pickerWheels.firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Try a little\ndistance."].exists)
        attach(app, "onboarding-introduction")
        tap(app.buttons["onboardingStartRest"], in: app)
        XCTAssertTrue(app.staticTexts["10 seconds. We’ll chime when you’re done."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["finishRest"].exists)
        XCTAssertTrue(app.buttons["finishRest"].waitForExistence(timeout: 12))
        attach(app, "first-tree-completion")
        tap(app.buttons["finishRest"], in: app)
        assertScreenTimeRequired(app)
        attach(app, "onboarding-permission")
        tap(app.buttons["screenTimeConnect"], in: app)
        XCTAssertTrue(app.staticTexts["paywallPlaceholder"].waitForExistence(timeout: 5))
        tap(app.buttons["paywallContinue"], in: app)
        XCTAssertTrue(app.staticTexts["todayTreeStatus"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["treeCount"].label.contains("1 tree"))
        attach(app, "today-first-tree")
        tap(app.buttons["viewProgress"], in: app)
        XCTAssertTrue(app.staticTexts["completed breaks"].waitForExistence(timeout: 5))
        attach(app, "progress-first-tree")
    }

    @MainActor func testSkippingFirstGuidedRestStillRequiresScreenTime() throws {
        let app = launch(fullRest: true, screenTime: .notDetermined)
        tap(app.buttons["onboardingStartRest"], in: app)
        XCTAssertTrue(app.staticTexts["restInstruction"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["restInstruction"].label, "Look far.")
        XCTAssertTrue(app.staticTexts["restCountdown"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["restProgress"].exists)
        attach(app, "guided-rest-countdown")
        tap(app.buttons["skipRest"], in: app)
        assertScreenTimeRequired(app)
        attach(app, "skipped-rest-permission")
        tap(app.buttons["screenTimeConnect"], in: app)
        XCTAssertTrue(app.staticTexts["paywallPlaceholder"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboardingSkipScreenTime"].exists)
        XCTAssertFalse(app.buttons["onboardingStartRest"].exists)
        attach(app, "skipped-rest-paywall")
        tap(app.buttons["paywallContinue"], in: app)
        XCTAssertTrue(app.staticTexts["treeCount"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["treeCount"].label.contains("0 trees"))
        attach(app, "today-empty-forest")
        app.tabBars.buttons["Progress"].tap()
        attach(app, "progress-skipped-rest")
    }

    @MainActor func testSkippingRestoredFirstRestStillRequiresScreenTime() throws {
        let app = launch(restoredRest: true, screenTime: .notDetermined)
        XCTAssertTrue(app.buttons["skipRest"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["restCountdown"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["restProgress"].exists)
        tap(app.buttons["skipRest"], in: app)
        assertScreenTimeRequired(app)
        tap(app.buttons["screenTimeConnect"], in: app)
        XCTAssertTrue(app.staticTexts["paywallPlaceholder"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboardingStartRest"].exists)
    }

    @MainActor func testEveryCompletedRestGrowsATreeToday() throws {
        let app = launch(skipOnboarding: true)
        for count in 1...2 {
            tap(app.buttons["quickRest"], in: app)
            XCTAssertTrue(app.buttons["finishRest"].waitForExistence(timeout: 8))
            tap(app.buttons["finishRest"], in: app)
            XCTAssertTrue(app.staticTexts["treeCount"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["treeCount"].label.contains("\(count) tree"))
        }
        attach(app, "today-two-trees")
        let breaks = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Breaks today")).firstMatch
        for _ in 0..<4 where !breaks.isHittable { app.swipeUp() }
        XCTAssertTrue(breaks.label.contains("2"))
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["completed breaks"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["progress.completedCount"].label, "2")
        attach(app, "progress-two-breaks")
    }

    @MainActor func testConfirmedBreakDoesNotPlantTree() throws {
        let app = launch(skipOnboarding: true, pendingBreak: true)
        tap(app.buttons["pauseConfirm"], in: app)
        XCTAssertTrue(app.staticTexts["treeCount"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["treeCount"].label.contains("0 trees"))
        app.tabBars.buttons["Progress"].tap()
        let confirmed = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Break confirmed")).firstMatch
        for _ in 0..<6 where !confirmed.isHittable { app.swipeUp() }
        XCTAssertTrue(confirmed.exists)
        attach(app, "progress-confirmed-break")
    }

    @MainActor func testCustomRhythmIsSavedInSettingsAndUsedForManualRest() throws {
        let app = launch(skipOnboarding: true, fullRest: true)
        XCTAssertFalse(app.buttons["editRhythm"].exists)
        XCTAssertFalse(app.pickerWheels.firstMatch.exists)
        tap(app.buttons["Settings"], in: app)
        XCTAssertTrue(app.staticTexts["rhythmSummary"].label.contains("20 min / 20 sec"))
        XCTAssertFalse(app.buttons["confirmOwnBreak"].exists)
        XCTAssertFalse(app.buttons["I already took a break"].exists)
        XCTAssertFalse(app.steppers.firstMatch.exists)
        XCTAssertFalse(app.buttons["Save active hours"].exists)
        attach(app, "settings-before-edit")
        tap(app.buttons["editRhythm"], in: app)

        let usage = app.pickers["usageMinutes"].pickerWheels.firstMatch
        let rest = app.pickers["restSeconds"].pickerWheels.firstMatch
        XCTAssertTrue(usage.waitForExistence(timeout: 5))
        XCTAssertTrue((usage.value as? String)?.contains("20 minutes") == true)
        XCTAssertTrue((rest.value as? String)?.contains("20 seconds") == true)
        attach(app, "rhythm-editor-default")

        usage.adjust(toPickerWheelValue: "30 minutes")
        rest.adjust(toPickerWheelValue: "10 seconds")
        tap(app.navigationBars["Break timing"].buttons["BackButton"], in: app)
        XCTAssertTrue(app.buttons["editRhythm"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["rhythmSummary"].label.contains("20 min / 20 sec"))

        tap(app.buttons["editRhythm"], in: app)
        XCTAssertTrue(usage.waitForExistence(timeout: 5))
        XCTAssertTrue((usage.value as? String)?.contains("20 minutes") == true)
        XCTAssertTrue((rest.value as? String)?.contains("20 seconds") == true)
        usage.adjust(toPickerWheelValue: "30 minutes")
        rest.adjust(toPickerWheelValue: "10 seconds")
        attach(app, "rhythm-editor-custom")
        tap(app.buttons["saveRhythm"], in: app)
        XCTAssertTrue(app.buttons["editRhythm"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["rhythmSummary"].label.contains("30 min / 10 sec"))
        attach(app, "settings-saved-rhythm")
        app.buttons["Done"].tap()

        XCTAssertTrue(app.staticTexts["todayTreeStatus"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["todayTreeStatus"].label, "Your first tree starts with a 10-second rest.")
        XCTAssertFalse(app.buttons["editRhythm"].exists)
        XCTAssertFalse(app.pickerWheels.firstMatch.exists)
        tap(app.buttons["Settings"], in: app)
        XCTAssertTrue(app.staticTexts["rhythmSummary"].label.contains("30 min / 10 sec"))
        tap(app.buttons["editRhythm"], in: app)
        XCTAssertTrue(usage.waitForExistence(timeout: 5))
        XCTAssertTrue((usage.value as? String)?.contains("30 minutes") == true)
        XCTAssertTrue((rest.value as? String)?.contains("10 seconds") == true)
        tap(app.navigationBars["Break timing"].buttons["BackButton"], in: app)
        app.buttons["Done"].tap()

        tap(app.buttons["quickRest"], in: app)
        XCTAssertTrue(app.staticTexts["10 seconds. We’ll chime when you’re done."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["finishRest"].exists)
        XCTAssertTrue(app.buttons["finishRest"].waitForExistence(timeout: 12))
        tap(app.buttons["finishRest"], in: app)
        XCTAssertTrue(app.staticTexts["treeCount"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["treeCount"].label.contains("1 tree"))
    }

    @MainActor func testTimingEditorIsReachableAtLargestDynamicType() throws {
        let app = launch(skipOnboarding: true, extraArguments: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        tap(app.buttons["Settings"], in: app)
        XCTAssertTrue(app.buttons["editRhythm"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["rhythmSummary"].label.contains("20 min / 20 sec"))
        XCTAssertFalse(app.buttons["confirmOwnBreak"].exists)
        XCTAssertFalse(app.buttons["I already took a break"].exists)
        XCTAssertTrue(app.buttons["Done"].isHittable)
        attach(app, "settings-largest-dynamic-type")

        tap(app.buttons["editRhythm"], in: app)
        let form = app.collectionViews.firstMatch
        for identifier in ["usageMinutes", "restSeconds"] {
            let wheel = app.pickers[identifier].pickerWheels.firstMatch
            for _ in 0..<4 where !wheel.exists || !wheel.isHittable {
                // Scroll along the form's edge so the gesture does not spin a picker.
                form.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.8))
                    .press(forDuration: 0.01, thenDragTo: form.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.25)))
            }
            XCTAssertTrue(wheel.exists)
            XCTAssertTrue(wheel.isHittable)
        }
        XCTAssertTrue(app.buttons["saveRhythm"].isHittable)
        attach(app, "rhythm-editor-largest-dynamic-type")
        tap(app.buttons["saveRhythm"], in: app)
        XCTAssertTrue(app.buttons["editRhythm"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["rhythmSummary"].label.contains("20 min / 20 sec"))
    }

    @MainActor func testMembershipPlaceholderAndLearn() throws {
        let app = launch(skipOnboarding: true)
        tap(app.buttons["Settings"], in: app)
        openMembership(in: app)
        XCTAssertTrue(app.staticTexts["paywallPlaceholder"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["paywallPlaceholder"].label, "Coming soon. Free for now.")
        XCTAssertTrue(app.buttons["paywallContinue"].isHittable)
        XCTAssertFalse(app.buttons["subscribe"].exists)
        attach(app, "membership-placeholder")
        tap(app.buttons["paywallContinue"], in: app)
        app.buttons["Done"].tap()
        app.tabBars.buttons["Learn"].tap()
        XCTAssertTrue(app.staticTexts["Care for the way\nyou see."].waitForExistence(timeout: 5))
        attach(app, "learn")
    }

    @MainActor func testDeniedScreenTimeCannotReachPaywallOrTabs() throws {
        let app = launch(fullRest: true, screenTime: .denied)
        tap(app.buttons["onboardingStartRest"], in: app)
        tap(app.buttons["skipRest"], in: app)
        assertScreenTimeRequired(app)
        tap(app.buttons["screenTimeConnect"], in: app)
        XCTAssertTrue(app.staticTexts["screenTimeError"].waitForExistence(timeout: 5))
        assertScreenTimeRequired(app)
        attach(app, "screen-time-denied")
    }

    #if targetEnvironment(simulator)
    @MainActor func testSimulatorCannotBypassScreenTimeWithoutFixture() throws {
        let app = launch(skipOnboarding: true, screenTime: nil)
        assertScreenTimeRequired(app)
        XCTAssertEqual(app.buttons["screenTimeConnect"].label, "Use a physical iPhone")
        XCTAssertFalse(app.buttons["screenTimeConnect"].isEnabled)
        attach(app, "screen-time-unavailable")
    }
    #endif

    @MainActor func testRevokedAccessReturnsOnboardingPaywallToPermission() throws {
        let app = launch(fullRest: true, screenTime: .revokedOnForeground)
        tap(app.buttons["onboardingStartRest"], in: app)
        tap(app.buttons["skipRest"], in: app)
        assertScreenTimeRequired(app)
        tap(app.buttons["screenTimeConnect"], in: app)
        XCTAssertTrue(app.staticTexts["paywallPlaceholder"].waitForExistence(timeout: 5))
        revokeAccessOnForeground(app)
        tap(app.buttons["screenTimeConnect"], in: app)
        XCTAssertTrue(app.staticTexts["paywallPlaceholder"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        attach(app, "onboarding-paywall-reconnected")
    }

    @MainActor func testRevokedAccessReplacesSettingsOnForeground() throws {
        let app = launch(skipOnboarding: true, screenTime: .revokedOnForeground)
        tap(app.buttons["Settings"], in: app)
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        revokeAccessOnForeground(app)
        XCTAssertFalse(app.buttons["Done"].exists)
        attach(app, "screen-time-revoked-settings")
        reconnectScreenTime(app)
    }

    @MainActor func testRevokedAccessReplacesPaywallOnForeground() throws {
        let app = launch(skipOnboarding: true, screenTime: .revokedOnForeground)
        tap(app.buttons["Settings"], in: app)
        openMembership(in: app)
        XCTAssertTrue(app.staticTexts["paywallPlaceholder"].waitForExistence(timeout: 5))
        revokeAccessOnForeground(app)
        XCTAssertFalse(app.buttons["paywallContinue"].exists)
        attach(app, "screen-time-revoked-paywall")
        reconnectScreenTime(app)
    }

    @MainActor func testRevokedAccessReplacesActiveBreakOnForeground() throws {
        let app = launch(skipOnboarding: true, fullRest: true, screenTime: .revokedOnForeground)
        tap(app.buttons["quickRest"], in: app)
        XCTAssertTrue(app.staticTexts["restCountdown"].waitForExistence(timeout: 5))
        revokeAccessOnForeground(app)
        assertBreakIsCovered(app)
        attach(app, "screen-time-revoked-active-break")
        reconnectScreenTime(app)
    }

    @MainActor func testRevokedAccessReplacesRestoredBreakOnForeground() throws {
        let app = launch(skipOnboarding: true, restoredRest: true, screenTime: .revokedOnForeground)
        XCTAssertTrue(app.staticTexts["restCountdown"].waitForExistence(timeout: 5))
        revokeAccessOnForeground(app)
        assertBreakIsCovered(app)
        attach(app, "screen-time-revoked-restored-break")
        reconnectScreenTime(app)
    }

    @MainActor func testInitialAuthorizationResolutionPreservesRestoredRest() throws {
        let app = launch(skipOnboarding: true, fullRest: true, restoredRest: true, screenTime: .restoringApproved)
        XCTAssertTrue(app.staticTexts["restCountdown"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["restProgress"].exists)
        XCTAssertTrue(app.buttons["skipRest"].exists)
        XCTAssertFalse(app.buttons["finishRest"].exists)
        XCTAssertFalse(app.staticTexts["screenTimeRequired"].exists)
        tap(app.buttons["skipRest"], in: app)
        XCTAssertTrue(app.staticTexts["treeCount"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["treeCount"].label.contains("0 trees"))
    }

    @MainActor func testDeniedAccessBlocksRestoredBreakAtLaunch() throws {
        let app = launch(skipOnboarding: true, restoredRest: true, screenTime: .denied)
        assertScreenTimeRequired(app)
        assertBreakIsCovered(app)
        tap(app.buttons["screenTimeConnect"], in: app)
        XCTAssertTrue(app.staticTexts["screenTimeError"].waitForExistence(timeout: 5))
        assertScreenTimeRequired(app)
        assertBreakIsCovered(app)
    }

    private enum ScreenTimeFixture: String {
        case approved, notDetermined, denied
        case revokedOnForeground = "revoked-on-foreground"
        case restoringApproved = "restoring-approved"
    }

    @MainActor private func launch(skipOnboarding: Bool = false, fullRest: Bool = false, restoredRest: Bool = false, pendingBreak: Bool = false,
                                   screenTime: ScreenTimeFixture? = .approved, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        if skipOnboarding { app.launchArguments.append("--skip-onboarding") }
        if fullRest { app.launchArguments.append("--ui-testing-full-rest") }
        if restoredRest { app.launchArguments.append("--ui-testing-restored-rest") }
        if pendingBreak { app.launchArguments.append("--ui-testing-pending-break") }
        if let screenTime { app.launchArguments.append("--ui-testing-screen-time=\(screenTime.rawValue)") }
        app.launchArguments.append(contentsOf: extraArguments)
        app.launch()
        return app
    }

    @MainActor private func assertScreenTimeRequired(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["screenTimeRequired"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["screenTimeConnect"].exists)
        XCTAssertFalse(app.buttons["onboardingSkipScreenTime"].exists)
        XCTAssertFalse(app.buttons["Not now"].exists)
        XCTAssertFalse(app.staticTexts["paywallPlaceholder"].exists)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
    }

    @MainActor private func revokeAccessOnForeground(_ app: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        app.activate()
        assertScreenTimeRequired(app)
    }

    @MainActor private func assertBreakIsCovered(_ app: XCUIApplication) {
        XCTAssertFalse(app.staticTexts["restCountdown"].exists)
        XCTAssertFalse(app.buttons["skipRest"].exists)
        XCTAssertFalse(app.buttons["finishRest"].exists)
    }

    @MainActor private func reconnectScreenTime(_ app: XCUIApplication) {
        tap(app.buttons["screenTimeConnect"], in: app)
        XCTAssertTrue(app.staticTexts["treeCount"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["treeCount"].label.contains("0 trees"))
        XCTAssertFalse(app.staticTexts["screenTimeRequired"].exists)
        XCTAssertTrue(app.tabBars.buttons["Today"].exists)
        assertBreakIsCovered(app)
    }

    @MainActor private func openMembership(in app: XCUIApplication) {
        let settings = app.collectionViews.firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        let membership = app.buttons["showPlans"]
        for _ in 0..<6 {
            if membership.exists && membership.isHittable { break }
            settings.swipeUp()
        }
        tap(membership, in: app)
    }

    @MainActor private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        for _ in 0..<6 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
        element.tap()
    }

    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        // Let short presentation transitions settle before capturing the layout.
        Thread.sleep(forTimeInterval: 0.4)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
