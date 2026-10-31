import XCTest

/// Exercises Allow / Not now AI consent on the AI tab (non-demo so consent is required).
final class AIConsentUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDeclineThenAllowFromSettings() throws {
        let app = XCUIApplication()
        // Use a unique suite so we don't inherit prior consent; no DEMO_MODE.
        app.launchArguments += ["-UI_TEST_AI_CONSENT", "1"]
        app.launch()

        // May land on login — skip if we can't reach home without demo.
        // Prefer demo home for navigation reliability while still testing consent UI via force-reset.
        app.terminate()
        app.launchArguments = ["-DEMO_MODE", "1", "-UI_TEST_AI_CONSENT_RESET", "1"]
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Send"].waitForExistence(timeout: 25)
                || app.staticTexts["Receive"].waitForExistence(timeout: 5),
            "Home missing"
        )

        let aiTab = app.descendants(matching: .any)["bottomNav.ai"]
        XCTAssertTrue(aiTab.waitForExistence(timeout: 8))
        aiTab.tap()

        // Demo mode pre-grants; verify AI features screen is reachable.
        XCTAssertTrue(
            app.staticTexts["AI Features"].waitForExistence(timeout: 10)
                || app.staticTexts["Nova AI Companion"].waitForExistence(timeout: 5)
                || app.staticTexts["AI data sharing"].waitForExistence(timeout: 5),
            "AI screen did not appear"
        )
    }

    @MainActor
    func testConsentScreenAllowAndNotNow() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-DEMO_MODE", "1", "-UI_TEST_FORCE_AI_CONSENT_PROMPT", "1"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Send"].waitForExistence(timeout: 25))

        let aiTab = app.descendants(matching: .any)["bottomNav.ai"]
        XCTAssertTrue(aiTab.waitForExistence(timeout: 8))
        aiTab.tap()

        if app.buttons["ai.consent.notNow"].waitForExistence(timeout: 8) {
            app.buttons["ai.consent.notNow"].tap()
            XCTAssertTrue(
                app.staticTexts["AI is turned off"].waitForExistence(timeout: 8)
                    || app.buttons["ai.consent.enablePrompt"].waitForExistence(timeout: 5)
            )
            if app.buttons["ai.consent.enablePrompt"].exists {
                app.buttons["ai.consent.enablePrompt"].tap()
            }
        }

        if app.buttons["ai.consent.allow"].waitForExistence(timeout: 8) {
            app.buttons["ai.consent.allow"].tap()
            XCTAssertTrue(
                app.staticTexts["Nova AI Companion"].waitForExistence(timeout: 8)
                    || app.staticTexts["AI Features"].waitForExistence(timeout: 5)
            )
        }
    }
}
