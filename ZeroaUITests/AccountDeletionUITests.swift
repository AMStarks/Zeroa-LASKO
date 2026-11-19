import XCTest

/// Creates a fresh wallet and deletes it against production Halo.
/// Launch with no demo arguments. The phone must be unlocked.
final class AccountDeletionUITests: XCTestCase {
    private let toyWords: Set<String> = [
        "apple", "banana", "cherry", "date", "elder", "fig",
        "grape", "honey", "ice", "juice", "kiwi", "lemon"
    ]

    @MainActor
    func testCreateThenDeleteAccount() throws {
        let app = XCUIApplication()
        app.launchArguments = []
        app.launchEnvironment = [:]
        app.launch()

        if !app.buttons["Create New Account"].waitForExistence(timeout: 4) {
            try logoutToLogin(app)
        }

        app.buttons["Create New Account"].tap()
        let reveal = app.buttons["createAccount.revealPhrase"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 8))
        reveal.tap()

        let phrase = app.staticTexts["createAccount.mnemonic"].label
        let words = phrase.split(separator: " ").map(String.init)
        XCTAssertEqual(words.count, 12, "Recovery phrase should be 12 words, got: \(phrase)")
        XCTAssertGreaterThan(Set(words).count, 6, "Recovery phrase repeats too much: \(phrase)")
        XCTAssertFalse(Set(words).isSubset(of: toyWords), "Recovery phrase is still the placeholder word list: \(phrase)")

        let writtenDown = app.switches["I have written down my recovery phrase securely"]
        writtenDown.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        if (writtenDown.value as? String) != "1" {
            writtenDown.tap()
        }
        let create = app.buttons["Create Account"].firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: 3))
        XCTAssertTrue(create.isEnabled, "Create Account stayed disabled")
        create.tap()
        let alertCreate = app.alerts.buttons["Create Account"]
        XCTAssertTrue(alertCreate.waitForExistence(timeout: 5), "Confirm alert did not appear")
        alertCreate.tap()

        XCTAssertTrue(app.staticTexts["Send"].waitForExistence(timeout: 20), "New account did not reach the wallet")

        app.buttons["bottomNav.menu"].tap()
        let settings = app.staticTexts["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let deleteRow = app.buttons["settings.deleteAccount"]
        if !deleteRow.waitForExistence(timeout: 4) {
            app.staticTexts["Settings"].tap()
        }
        XCTAssertTrue(deleteRow.waitForExistence(timeout: 8), "Settings did not open")
        deleteRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let backup = app.switches["I have written down my recovery phrase"]
        XCTAssertTrue(backup.waitForExistence(timeout: 5))
        backup.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        if (backup.value as? String) != "1" {
            backup.tap()
        }
        let confirmButton = app.buttons["settings.deleteAccount.confirm"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3))
        XCTAssertTrue(confirmButton.isEnabled, "Delete Account stayed disabled")
        confirmButton.tap()
        let confirmDelete = app.alerts.buttons["Delete Account"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5))
        confirmDelete.tap()

        let refused = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Signature verification failed"))
        let backToLogin = app.buttons["Create New Account"].waitForExistence(timeout: 30)
        XCTAssertEqual(refused.count, 0, "Halo refused the signature")
        XCTAssertTrue(backToLogin, "Delete did not return to the login screen")
    }

    @MainActor
    private func logoutToLogin(_ app: XCUIApplication) throws {
        XCTAssertTrue(app.buttons["bottomNav.menu"].waitForExistence(timeout: 20), "Neither login nor the wallet appeared")
        app.buttons["bottomNav.menu"].tap()
        let menuLogout = app.buttons["Logout"]
        XCTAssertTrue(menuLogout.waitForExistence(timeout: 5))
        menuLogout.tap()
        let confirm = app.buttons.matching(NSPredicate(format: "label == %@", "Logout"))
        XCTAssertTrue(confirm.element(boundBy: 0).waitForExistence(timeout: 5))
        let last = confirm.element(boundBy: confirm.count - 1)
        last.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["Create New Account"].waitForExistence(timeout: 10))
    }
}
