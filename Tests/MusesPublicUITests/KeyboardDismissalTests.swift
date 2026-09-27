import XCTest

final class KeyboardDismissalTests: XCTestCase {
    func testOutsideTapDismissesHomeAndSearchKeyboard() {
        let app = XCUIApplication()
        app.launch()
        let link = app.textFields["public.link"]
        XCTAssertTrue(link.waitForExistence(timeout: 10))
        link.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.staticTexts["YOUR LISTENING SPACE"].tap()
        expectNoKeyboard(app)
        app.tabBars.buttons["Search"].tap()
        let search = app.textFields["public.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.staticTexts["FIND A VIDEO"].tap()
        expectNoKeyboard(app)
    }

    private func expectNoKeyboard(_ app: XCUIApplication) {
        let gone = NSPredicate(format: "exists == false")
        let dismissed = XCTNSPredicateExpectation(predicate: gone, object: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 3), .completed)
    }
}
