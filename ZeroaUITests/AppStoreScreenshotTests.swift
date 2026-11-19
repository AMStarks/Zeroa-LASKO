import XCTest
import UIKit

/// Captures wallet-only App Store screenshots in demo mode (`-UI_TEST_SCREENSHOTS`).
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
        return UIDevice.current.userInterfaceIdiom == .pad ? "ipad-13" : "iphone-6.3"
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
    }

    @discardableResult
    private func waitForHomeScreen(in app: XCUIApplication) -> Bool {
        app.staticTexts["Send"].waitForExistence(timeout: 25)
            || app.staticTexts["Receive"].waitForExistence(timeout: 5)
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
            || app.staticTexts["Your Address"].waitForExistence(timeout: 3)
            || app.buttons["Receive"].waitForExistence(timeout: 3)
    }

    private func dismissSheet(in app: XCUIApplication) {
        if app.buttons["Close"].waitForExistence(timeout: 2) {
            app.buttons["Close"].tap()
        } else if app.buttons["Done"].waitForExistence(timeout: 1) {
            app.buttons["Done"].tap()
        } else if app.buttons["Cancel"].waitForExistence(timeout: 1) {
            app.buttons["Cancel"].tap()
        } else {
            app.swipeDown()
        }
        _ = waitForHomeScreen(in: app)
    }

    private func saveScreenshot(named name: String, in app: XCUIApplication) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let url = screenshotDirectory.appendingPathComponent("\(name).png")
        let data = shot.pngRepresentation
        try? data.write(to: url, options: .atomic)
        print("Wrote \(url.path)")
    }
}
