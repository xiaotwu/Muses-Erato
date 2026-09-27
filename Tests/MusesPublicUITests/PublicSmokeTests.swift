import XCTest

final class PublicSmokeTests: XCTestCase {
    func testNewInstallNavigationAndVisiblePlayerRoute() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.textFields["public.link"].waitForExistence(timeout: 10))
        app.textFields["public.link"].tap()
        app.textFields["public.link"].typeText("dQw4w9WgXcQ")
        app.buttons["public.open"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["public.iframe"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["public.playbackState"].exists)
        app.buttons["Close"].tap()
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.staticTexts["public.libraryHeader"].waitForExistence(timeout: 5))
    }
}
