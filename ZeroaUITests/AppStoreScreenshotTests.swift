import XCTest

final class AppStoreScreenshotTests: XCTestCase {
    private var screenshotDirectory: URL {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return repoRoot.appendingPathComponent("app-store-screenshots/ipad-13", isDirectory: true)
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
        try FileManager.default.createDirectory(at: screenshotDirectory, withIntermediateDirectories: true)
    }

    @MainActor
    func testCaptureAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UI_TEST_SCREENSHOTS", "1"]
        app.launch()

        guard waitForHomeScreen(in: app) else {
            XCTFail("Home screen did not appear")
            return
        }
        saveScreenshot(named: "01-wallet-home", in: app)

        guard openSwitchboard(in: app) else {
            XCTFail("Could not open Switchboard")
            return
        }
        saveScreenshot(named: "02-switchboard", in: app)

        app.staticTexts["Alice"].tap()

        guard app.buttons["switchboard.mediaToggle"].waitForExistence(timeout: 10) else {
            XCTFail("Switchboard media toggle was not visible")
            return
        }
        app.buttons["switchboard.mediaToggle"].tap()

        guard app.staticTexts["Photo"].waitForExistence(timeout: 10) else {
            XCTFail("Switchboard media options did not appear")
            return
        }
        saveScreenshot(named: "03-switchboard-media-attachments", in: app)

        dismissConversationAndSwitchboard(in: app)
        if openSendSheet(in: app) {
            saveScreenshot(named: "04-send-tls", in: app)
        }
    }

    private func dismissConversationAndSwitchboard(in app: XCUIApplication) {
        if app.buttons["switchboard.mediaToggle"].waitForExistence(timeout: 2) {
            app.buttons["Back"].firstMatch.tap()
        }
        if app.staticTexts["Switchboard"].waitForExistence(timeout: 3) {
            app.staticTexts["Back"].firstMatch.tap()
        }
    }

    @discardableResult
    private func waitForHomeScreen(in app: XCUIApplication) -> Bool {
        app.staticTexts["Send"].waitForExistence(timeout: 20)
    }

    @discardableResult
    private func openSwitchboard(in app: XCUIApplication) -> Bool {
        if app.staticTexts["Switchboard"].waitForExistence(timeout: 2) {
            return true
        }

        let messagingTab = app.buttons["bottomNav.messaging"]
        if messagingTab.waitForExistence(timeout: 5) {
            messagingTab.tap()
            if app.staticTexts["Switchboard"].waitForExistence(timeout: 10) {
                return true
            }
        }

        let menuTab = app.images["line.3.horizontal.circle"].firstMatch
        if menuTab.waitForExistence(timeout: 5) {
            menuTab.tap()
            let hybridMessaging = app.buttons["menu.hybridMessaging"]
            if hybridMessaging.waitForExistence(timeout: 5) {
                hybridMessaging.tap()
            } else if app.staticTexts["Hybrid Messaging"].waitForExistence(timeout: 5) {
                app.staticTexts["Hybrid Messaging"].tap()
            }
        }

        return app.staticTexts["Switchboard"].waitForExistence(timeout: 15)
    }

    @discardableResult
    private func seedSwitchboardContact(in app: XCUIApplication) -> Bool {
        app.staticTexts["Contacts"].tap()

        let addContact = app.buttons["Add Contact"]
        guard addContact.waitForExistence(timeout: 10) else { return false }
        addContact.tap()

        let addressField = app.textFields["Enter TLS wallet address"]
        guard addressField.waitForExistence(timeout: 5) else { return false }
        addressField.tap()
        addressField.typeText("ThGNWv22Mb89YwMKo8hAgTEL5ChWcnNuRJ")

        let nameField = app.textFields["Enter contact name"]
        guard nameField.waitForExistence(timeout: 5) else { return false }
        nameField.tap()
        nameField.typeText("Review Contact")

        app.buttons["Add"].tap()

        if app.alerts.buttons["OK"].waitForExistence(timeout: 5) {
            app.alerts.buttons["OK"].tap()
        }

        return app.staticTexts["Review Contact"].waitForExistence(timeout: 10)
    }

    @discardableResult
    private func openFirstConversation(in app: XCUIApplication) -> Bool {
        let contactRow = app.staticTexts["Review Contact"]
        guard contactRow.waitForExistence(timeout: 10) else { return false }
        contactRow.tap()

        let messageField = app.textFields["Message"]
        return messageField.waitForExistence(timeout: 10)
    }

    @discardableResult
    private func expandMediaOptions(in app: XCUIApplication) -> Bool {
        let toggle = app.buttons["switchboard.mediaToggle"]
        guard toggle.waitForExistence(timeout: 10) else { return false }
        toggle.tap()

        return app.staticTexts["Photo"].waitForExistence(timeout: 5)
            && app.staticTexts["Camera"].waitForExistence(timeout: 2)
            && app.staticTexts["Document"].waitForExistence(timeout: 2)
            && app.staticTexts["Location"].waitForExistence(timeout: 2)
            && app.staticTexts["Audio"].waitForExistence(timeout: 2)
    }

    @discardableResult
    private func openSendSheet(in app: XCUIApplication) -> Bool {
        guard app.staticTexts["Send"].waitForExistence(timeout: 10) else { return false }
        app.staticTexts["Send"].firstMatch.tap()
        return app.staticTexts["Send TLS"].waitForExistence(timeout: 10)
    }

    private func saveScreenshot(named name: String, in app: XCUIApplication) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let fileURL = screenshotDirectory.appendingPathComponent("\(name).png")
        try? screenshot.pngRepresentation.write(to: fileURL)
    }
}
