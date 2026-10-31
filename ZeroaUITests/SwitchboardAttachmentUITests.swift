import XCTest

/// Smoke-tests Switchboard Photo / Camera / Document / Location / Audio controls.
final class SwitchboardAttachmentUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAttachmentButtonsRespond() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-DEMO_MODE", "1", "-UI_TEST_SCREENSHOTS", "1"]
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Send"].waitForExistence(timeout: 25)
                || app.staticTexts["Receive"].waitForExistence(timeout: 5),
            "Demo home did not appear"
        )

        openSwitchboard(in: app)
        XCTAssertTrue(app.staticTexts["Switchboard"].waitForExistence(timeout: 15), "Switchboard missing")

        if app.staticTexts["Alice"].waitForExistence(timeout: 8) {
            app.staticTexts["Alice"].tap()
        }

        expandMediaOptions(in: app)

        for id in [
            "switchboard.attach.photo",
            "switchboard.attach.camera",
            "switchboard.attach.document",
            "switchboard.attach.location",
            "switchboard.attach.audio"
        ] {
            XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 5), "Missing \(id)")
        }

        // Photo → PHPicker
        app.buttons["switchboard.attach.photo"].tap()
        XCTAssertTrue(dismissSystemPicker(in: app), "Photo picker did not present")
        expandMediaOptions(in: app)

        // Camera → on simulator falls back to the photo picker
        app.buttons["switchboard.attach.camera"].tap()
        if app.alerts["Camera Unavailable"].waitForExistence(timeout: 3) {
            app.alerts.buttons["OK"].tap()
        } else if app.alerts["Camera Access Needed"].waitForExistence(timeout: 1) {
            app.alerts.buttons["Cancel"].tap()
        }
        XCTAssertTrue(dismissSystemPicker(in: app), "Camera control did not present a picker")
        expandMediaOptions(in: app)

        // Document → UIDocumentPicker
        app.buttons["switchboard.attach.document"].tap()
        XCTAssertTrue(dismissSystemPicker(in: app), "Document picker did not present")
        expandMediaOptions(in: app)

        // Location → permission / attach / alert
        app.buttons["switchboard.attach.location"].tap()
        acceptSpringboardPermissionIfNeeded()
        if app.alerts.firstMatch.waitForExistence(timeout: 6) {
            if app.alerts.buttons["OK"].exists {
                app.alerts.buttons["OK"].tap()
            } else if app.alerts.buttons["Cancel"].exists {
                app.alerts.buttons["Cancel"].tap()
            }
        }
        expandMediaOptions(in: app)

        // Audio → recorder sheet or mic permission
        app.buttons["switchboard.attach.audio"].tap()
        acceptSpringboardPermissionIfNeeded()
        let audioHandled =
            app.navigationBars["Audio"].waitForExistence(timeout: 8)
            || app.staticTexts["Record a voice note"].waitForExistence(timeout: 2)
            || app.alerts["Microphone Access Needed"].waitForExistence(timeout: 2)
            || app.buttons["Start Recording"].waitForExistence(timeout: 2)
        XCTAssertTrue(audioHandled, "Audio recorder / permission UI did not present")
        if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].firstMatch.tap()
        } else if app.navigationBars.buttons["Cancel"].exists {
            app.navigationBars.buttons["Cancel"].tap()
        } else if app.alerts.buttons["Cancel"].exists {
            app.alerts.buttons["Cancel"].tap()
        }
    }

    private func openSwitchboard(in app: XCUIApplication) {
        let messaging = app.buttons["bottomNav.messaging"]
        if messaging.waitForExistence(timeout: 5) {
            messaging.tap()
            return
        }
        let menu = app.images["line.3.horizontal.circle"].firstMatch
        if menu.waitForExistence(timeout: 3) {
            menu.tap()
            let hybrid = app.buttons["menu.hybridMessaging"]
            if hybrid.waitForExistence(timeout: 5) {
                hybrid.tap()
            }
        }
    }

    private func expandMediaOptions(in app: XCUIApplication) {
        let mediaToggle = app.buttons["switchboard.mediaToggle"]
        XCTAssertTrue(mediaToggle.waitForExistence(timeout: 10), "Media toggle missing")
        if !app.buttons["switchboard.attach.photo"].exists {
            mediaToggle.tap()
        }
        XCTAssertTrue(app.buttons["switchboard.attach.photo"].waitForExistence(timeout: 5))
    }

    @discardableResult
    private func dismissSystemPicker(in app: XCUIApplication) -> Bool {
        let cancel =
            app.navigationBars.buttons["Cancel"].waitForExistence(timeout: 8)
            || app.buttons["Cancel"].waitForExistence(timeout: 2)
            || app.buttons["Done"].waitForExistence(timeout: 1)
            || app.otherElements["Photos"].waitForExistence(timeout: 1)
            || app.collectionViews.firstMatch.waitForExistence(timeout: 1)
            || app.buttons["Browse"].waitForExistence(timeout: 1)

        guard cancel else { return false }

        if app.navigationBars.buttons["Cancel"].exists {
            app.navigationBars.buttons["Cancel"].tap()
        } else if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].firstMatch.tap()
        } else if app.buttons["Done"].exists {
            app.buttons["Done"].firstMatch.tap()
        } else {
            app.swipeDown()
        }
        return true
    }

    private func acceptSpringboardPermissionIfNeeded() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowWhile = springboard.alerts.buttons["Allow While Using App"]
        let allowOnce = springboard.alerts.buttons["Allow Once"]
        let allow = springboard.alerts.buttons["Allow"]
        if allowWhile.waitForExistence(timeout: 3) {
            allowWhile.tap()
        } else if allowOnce.waitForExistence(timeout: 1) {
            allowOnce.tap()
        } else if allow.waitForExistence(timeout: 1) {
            allow.tap()
        }
    }
}
