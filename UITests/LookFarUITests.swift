import XCTest

final class LookFarUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testOnboardingRestAndHistory() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        for page in 0..<3 {
            let next = app.buttons["onboardingContinue"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            if page == 0 { attach(app, "onboarding") }
            if !next.isHittable { app.swipeUp() }
            next.tap()
        }
        XCTAssertTrue(app.buttons["startRest"].waitForExistence(timeout: 5))
        attach(app, "today-empty")
        app.buttons["startRest"].tap()
        XCTAssertTrue(app.buttons["finishRest"].waitForExistence(timeout: 8))
        attach(app, "rest-completed")
        app.buttons["finishRest"].tap()
        XCTAssertTrue(app.staticTexts["1 timed rest today"].waitForExistence(timeout: 4))
        app.buttons["viewProgress"].tap()
        XCTAssertTrue(app.staticTexts["recorded rests"].firstMatch.waitForExistence(timeout: 3))
        attach(app, "progress-real")
    }

    @MainActor func testRoutineAndConfirmedBreak() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-onboarding"]
        app.launch()
        app.buttons["Change routine"].tap()
        app.buttons["routine-extended"].tap()
        XCTAssertTrue(app.staticTexts["20 min of use · 60 sec to rest"].waitForExistence(timeout: 3))
        app.buttons["confirmOwnBreak"].tap()
        app.buttons["Yes, reset my cycle"].tap()
        XCTAssertTrue(app.staticTexts["0 timed rests today"].exists)
        app.tabBars.buttons["Progress"].tap()
        let confirmedBreaks = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Breaks you confirmed")
        ).firstMatch
        for _ in 0..<4 where !confirmedBreaks.isHittable { app.swipeUp() }
        XCTAssertTrue(confirmedBreaks.waitForExistence(timeout: 3))
        XCTAssertTrue(
            NSPredicate(format: "SELF MATCHES %@", #"1[\s,]+Breaks you confirmed"#)
                .evaluate(with: confirmedBreaks.label),
            "A confirmed break is counted separately from timed rests."
        )
        let skips = app.staticTexts["0 skips"]
        for _ in 0..<3 where !skips.isHittable { app.swipeUp() }
        XCTAssertTrue(skips.waitForExistence(timeout: 3), "Confirming a break must not record a skip.")
        attach(app, "confirmed-break-history")
    }

    @MainActor func testPlansAndLearning() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-onboarding"]
        app.launch()
        app.buttons["confirmOwnBreak"].tap()
        app.buttons["Yes, reset my cycle"].tap()
        attach(app, "today")
        app.tabBars.buttons["Progress"].tap()
        attach(app, "progress")
        app.tabBars.buttons["Learn"].tap()
        attach(app, "learn")
        app.tabBars.buttons["Today"].tap()
        app.buttons["Settings"].tap()
        let plans = app.buttons["showPlans"]
        if !plans.isHittable { app.swipeUp() }
        plans.tap()
        XCTAssertTrue(app.buttons["plan-annual"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["plan-monthly"].exists)
        app.buttons["plan-monthly"].tap()
        XCTAssertTrue(app.buttons["plan-monthly"].isSelected)
        app.buttons["plan-annual"].tap()
        XCTAssertTrue(app.buttons["plan-annual"].isSelected)
        attach(app, "plans")
    }

    @MainActor func testRevenueCatPurchaseAndRestore() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-onboarding"]
        app.launchEnvironment["REVENUECAT_TEST_USER_ID"] = "lookfar-ui-\(UUID().uuidString)"
        app.launch()
        openPlans(app)
        XCTAssertTrue(app.buttons["subscribe"].waitForExistence(timeout: 20), "RevenueCat must return purchasable packages.")
        XCTAssertTrue(app.staticTexts["plan-price-annual"].label.contains("39.99"))
        XCTAssertTrue(app.staticTexts["plan-price-monthly"].label.contains("7.99"))
        attach(app, "revenuecat-plans")

        app.buttons["subscribe"].tap()
        let purchaseAlert = app.alerts["Test Store Purchase"]
        XCTAssertTrue(purchaseAlert.waitForExistence(timeout: 6), "Only the RevenueCat Test Store may run this test.")
        purchaseAlert.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Purchase canceled")).firstMatch.waitForExistence(timeout: 6))

        app.buttons["subscribe"].tap()
        XCTAssertTrue(purchaseAlert.waitForExistence(timeout: 6))
        purchaseAlert.buttons["Test failed purchase"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Couldn’t confirm the purchase")).firstMatch.waitForExistence(timeout: 6))
        XCTAssertFalse(app.staticTexts["Look Far Plus is active"].exists)

        app.buttons["subscribe"].tap()
        XCTAssertTrue(purchaseAlert.waitForExistence(timeout: 6))
        purchaseAlert.buttons["Test valid purchase"].tap()
        XCTAssertTrue(app.staticTexts["Look Far Plus is active"].waitForExistence(timeout: 15))
        attach(app, "revenuecat-active")

        let restore = app.buttons["restorePurchases"]
        for _ in 0..<3 where !restore.isHittable { app.swipeUp() }
        XCTAssertTrue(restore.isHittable)
        restore.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Your subscription has been restored")).firstMatch.waitForExistence(timeout: 15))

        app.terminate()
        app.launch()
        openPlans(app)
        XCTAssertTrue(app.staticTexts["Look Far Plus is active"].waitForExistence(timeout: 15))
        attach(app, "revenuecat-restored")
    }

    @MainActor private func openPlans(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        let plans = app.buttons["showPlans"]
        if !plans.isHittable { app.swipeUp() }
        plans.tap()
    }

    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
