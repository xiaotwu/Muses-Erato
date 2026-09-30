import XCTest

@MainActor final class KeyboardDismissalTests: XCTestCase {
    func testOutsideTapDismissesHomeAndSearchKeyboard() {
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        app.launchEnvironment["MUSES_UI_TEST_CATALOG"] = "fixtures"
        app.launch()
        XCTAssertTrue(app.buttons["public.openLinkEntry"].waitForExistence(timeout: 10))
        app.buttons["public.openLinkEntry"].tap()
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
        tapNonInputContent(app.staticTexts["Find a video or playlist"])
        expectNoKeyboard(app)
    }

    private func tapNonInputContent(_ content: XCUIElement) {
        XCTAssertTrue(content.waitForExistence(timeout: 3))
        XCTAssertTrue(content.isHittable, "Expected visible non-input content above the keyboard")
        content.tap()
    }

    private func expectNoKeyboard(_ app: XCUIApplication) {
        let gone = NSPredicate(format: "exists == false")
        let dismissed = XCTNSPredicateExpectation(predicate: gone, object: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 3), .completed)
    }
}
