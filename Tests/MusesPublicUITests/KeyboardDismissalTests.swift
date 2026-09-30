import XCTest

@MainActor final class KeyboardDismissalTests: XCTestCase {
    func testOutsideTapDismissesHomeAndSearchKeyboard() {
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        app.launchEnvironment["MUSES_UI_TEST_CATALOG"] = "fixtures"
        app.launch()
        XCTAssertTrue(app.buttons["public.add"].waitForExistence(timeout: 10))
        app.buttons["public.add"].tap()
        app.buttons["public.add.openLink"].tap()
        let link = app.textFields["public.link"]
        XCTAssertTrue(link.waitForExistence(timeout: 10))
        link.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        tapNonInputContent(app.staticTexts["public.linkHelp"])
        expectNoKeyboard(app)
        app.buttons["Done"].tap()
        app.tabBars.buttons["Search"].tap()
        let search = app.textFields["public.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        tapNonInputContent(app.staticTexts["public.searchIdle"])
        expectNoKeyboard(app)
    }

    private func tapNonInputContent(_ content: XCUIElement) {
        XCTAssertTrue(content.waitForExistence(timeout: 3))
        XCTAssertTrue(content.isHittable, "Expected visible non-input content above the keyboard")
        content.tap()
    }

    private func expectNoKeyboard(_ app: XCUIApplication) {
        // Use XCTest's absence wait, rather than nesting an exists query's
        // internal retries inside a predicate wait with the same deadline.
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3), "The keyboard must disappear after tapping non-input content")
    }
}
