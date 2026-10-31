import XCTest
import UIKit

/// Captures App Store screenshots in demo mode (`-UI_TEST_SCREENSHOTS`).
/// Run via `scripts/capture-app-store-screenshots.sh` for iPhone 6.9", 6.5", and iPad 13".
///
/// Folder selection uses `app-store-screenshots/.target-folder` (written by the capture script).
final class AppStoreScreenshotTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var deviceFolderName: String {
        let marker = repoRoot
            .appendingPathComponent("app-store-screenshots/.target-folder")
        if let value = try? String(contentsOf: marker, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }
        return UIDevice.current.userInterfaceIdiom == .pad ? "ipad-13" : "iphone-6.9"
    }

    private var screenshotDirectory: URL {
        repoRoot
            .appendingPathComponent("app-store-screenshots", isDirectory: true)
            .appendingPathComponent(deviceFolderName, isDirectory: true)
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
        try FileManager.default.createDirectory(at: screenshotDirectory, withIntermediateDirectories: true)
        print("Zeroa screenshots → \(screenshotDirectory.path)")
    }

    @MainActor
    func testCaptureAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UI_TEST_SCREENSHOTS", "1", "-DEMO_MODE", "1"]
        app.launch()

        guard waitForHomeScreen(in: app) else {
            XCTFail("Home screen did not appear for screenshots")
            return
        }
        saveScreenshot(named: "01-wallet-balances", in: app)

        if openSendSheet(in: app) {
            saveScreenshot(named: "02-send", in: app)
            dismissSheet(in: app)
        }

        if openReceiveSheet(in: app) {
            saveScreenshot(named: "03-receive", in: app)
            dismissSheet(in: app)
        }

        // Messaging before AI so navigation stays on a clean home stack for the AI relaunch.
        if openSwitchboard(in: app) {
            saveScreenshot(named: "04-messages-switchboard", in: app)

            if app.staticTexts["Alice"].waitForExistence(timeout: 5) {
                app.staticTexts["Alice"].tap()
            }

            if app.buttons["switchboard.mediaToggle"].waitForExistence(timeout: 8) {
                app.buttons["switchboard.mediaToggle"].tap()
                _ = app.staticTexts["Photo"].waitForExistence(timeout: 5)
                saveScreenshot(named: "05-message-attachments", in: app)
            }
        } else {
            XCTFail("Could not open Switchboard")
        }

        // Fresh launch for AI so we are not stuck inside the messaging navigation stack.
        app.terminate()
        app.launchArguments += ["-UI_TEST_SCREENSHOTS", "1", "-DEMO_MODE", "1"]
        app.launch()
        if waitForHomeScreen(in: app), openAITab(in: app) {
            saveScreenshot(named: "06-ai-features", in: app)
            if app.alerts.buttons["OK"].waitForExistence(timeout: 3) {
                app.alerts.buttons["OK"].tap()
            }
        }
    }

    @discardableResult
    private func waitForHomeScreen(in app: XCUIApplication) -> Bool {
        app.staticTexts["Send"].waitForExistence(timeout: 25)
            || app.staticTexts["Receive"].waitForExistence(timeout: 5)
    }

    @discardableResult
    private func openSwitchboard(in app: XCUIApplication) -> Bool {
        if app.staticTexts["Switchboard"].waitForExistence(timeout: 2) {
            return true
        }

        for _ in 0..<3 {
            let messaging = app.descendants(matching: .any)["bottomNav.messaging"]
            if messaging.waitForExistence(timeout: 3) {
                messaging.tap()
                if app.staticTexts["Switchboard"].waitForExistence(timeout: 8) {
                    return true
                }
            }

            // Icon-only fallback (SF Symbol name varies by selected state).
            let messageIcon = app.images.matching(NSPredicate(format: "label CONTAINS[c] %@", "message")).firstMatch
            if messageIcon.waitForExistence(timeout: 2) {
                messageIcon.tap()
                if app.staticTexts["Switchboard"].waitForExistence(timeout: 8) {
                    return true
                }
            }
        }

        let menu = app.descendants(matching: .any)["bottomNav.menu"]
        if menu.waitForExistence(timeout: 3) {
            menu.tap()
        } else if app.images["line.3.horizontal.circle"].firstMatch.waitForExistence(timeout: 3) {
            app.images["line.3.horizontal.circle"].firstMatch.tap()
        } else if app.images["line.3.horizontal.circle.fill"].firstMatch.waitForExistence(timeout: 2) {
            app.images["line.3.horizontal.circle.fill"].firstMatch.tap()
        }

        if app.buttons["menu.hybridMessaging"].waitForExistence(timeout: 5) {
            app.buttons["menu.hybridMessaging"].tap()
        } else if app.staticTexts["Hybrid Messaging"].waitForExistence(timeout: 5) {
            app.staticTexts["Hybrid Messaging"].tap()
        }

        return app.staticTexts["Switchboard"].waitForExistence(timeout: 15)
    }

    @discardableResult
    private func openSendSheet(in app: XCUIApplication) -> Bool {
        guard app.staticTexts["Send"].waitForExistence(timeout: 8) else { return false }
        app.staticTexts["Send"].firstMatch.tap()
        return app.staticTexts["Send TLS"].waitForExistence(timeout: 8)
            || app.navigationBars.staticTexts["Send"].waitForExistence(timeout: 3)
            || app.buttons["Send"].waitForExistence(timeout: 3)
    }

    @discardableResult
    private func openReceiveSheet(in app: XCUIApplication) -> Bool {
        guard app.staticTexts["Receive"].waitForExistence(timeout: 8) else { return false }
        app.staticTexts["Receive"].firstMatch.tap()
        return app.staticTexts["Receive TLS"].waitForExistence(timeout: 8)
            || app.navigationBars.staticTexts["Receive"].waitForExistence(timeout: 3)
            || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "address")).firstMatch.waitForExistence(timeout: 3)
    }

    @discardableResult
    private func openAITab(in app: XCUIApplication) -> Bool {
        let aiNav = app.descendants(matching: .any)["bottomNav.ai"]
        if aiNav.waitForExistence(timeout: 3) {
            aiNav.tap()
            return true
        }
        if app.images["atom"].firstMatch.waitForExistence(timeout: 2) {
            app.images["atom"].firstMatch.tap()
            return true
        }
        return false
    }

    private func dismissSheet(in app: XCUIApplication) {
        if app.buttons["Close"].waitForExistence(timeout: 1) {
            app.buttons["Close"].tap()
        } else if app.buttons["Done"].waitForExistence(timeout: 1) {
            app.buttons["Done"].tap()
        } else {
            app.swipeDown()
            app.swipeDown()
        }
        _ = app.staticTexts["Send"].waitForExistence(timeout: 5)
    }

    private func saveScreenshot(named name: String, in app: XCUIApplication) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let fileURL = screenshotDirectory.appendingPathComponent("\(name).png")
        do {
            try screenshot.pngRepresentation.write(to: fileURL)
            print("Wrote \(fileURL.path)")
        } catch {
            XCTFail("Failed writing \(fileURL.path): \(error)")
        }
    }
}
