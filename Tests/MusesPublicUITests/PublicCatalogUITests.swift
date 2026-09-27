import XCTest

@MainActor final class PublicCatalogUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        app.launchEnvironment["MUSES_UI_TEST_CATALOG"] = "fixtures"
        app.launch()
        return app
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
    func testSearchPaginationIsExplicitAndRetryPreservesRows() {
        let app = launch()
        app.tabBars.buttons["Search"].tap()
        let search = app.textFields["public.search"]
        search.tap(); search.typeText("fixture\n")
        XCTAssertTrue(app.staticTexts["Fixture first video"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Fixture second video"].exists)
        let next = app.buttons["Load next page"]
        reveal(next, in: app); next.tap()
        XCTAssertTrue(app.buttons["Retry"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Fixture first video"].exists)
        app.buttons["Retry"].tap()
        XCTAssertTrue(app.staticTexts["Fixture second video"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Load next page"].exists)
    }
    func testPlaylistAndChannelLinkBrowsing() {
        let app = launch()
        let link = app.textFields["public.link"]
        link.tap(); link.typeText("https://youtube.com/playlist?list=PLfixture")
        app.buttons["public.open"].tap()
        XCTAssertTrue(app.staticTexts["Fixture playlist description"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Fixture playlist video 1"].exists)
        app.buttons["Load playlist videos"].tap()
        XCTAssertTrue(app.staticTexts["Fixture playlist video 1"].waitForExistence(timeout: 5))
        let next = app.buttons["Load next page"].firstMatch
        reveal(next, in: app); next.tap()
        XCTAssertTrue(app.staticTexts["Fixture playlist video 2"].waitForExistence(timeout: 5))
        app.swipeDown()
        app.buttons["View channel"].tap()
        XCTAssertTrue(app.staticTexts["Fixture channel description"].waitForExistence(timeout: 5))
        app.buttons["Load uploads"].tap()
        XCTAssertTrue(app.staticTexts["Fixture playlist video 1"].waitForExistence(timeout: 5))
        let load = app.buttons["Load channel playlists"]
        reveal(load, in: app); load.tap()
        XCTAssertTrue(app.staticTexts["Fixture public playlist"].waitForExistence(timeout: 5))
    }
    func testAccountPlaylistOpensVisiblePlayerFromSettings() {
        let app = launch()
        app.buttons["Settings"].firstMatch.tap()
        app.buttons["Account & YouTube collections"].tap()
        app.buttons["Load my YouTube playlists"].tap()
        app.buttons.containing(.staticText, identifier: "Fixture public playlist").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Fixture playlist description"].waitForExistence(timeout: 5))
        app.buttons["Load playlist videos"].tap()
        app.buttons.containing(.staticText, identifier: "Fixture playlist video 1").firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["public.iframe"].waitForExistence(timeout: 10))
        app.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["Fixture playlist description"].waitForExistence(timeout: 5))
    }
    func testReadOnlyAccountCollectionsAndProfileSeparation() {
        let app = launch()
        app.tabBars.buttons["Discover"].tap()
        app.buttons["Account & YouTube collections"].tap()
        XCTAssertTrue(app.staticTexts["Local Muses profile"].waitForExistence(timeout: 5))
        app.buttons["Load my YouTube profile"].tap()
        XCTAssertTrue(app.staticTexts["Fixture channel"].waitForExistence(timeout: 5))
        app.buttons["Load my YouTube playlists"].tap()
        XCTAssertTrue(app.staticTexts["Fixture public playlist"].waitForExistence(timeout: 5))
        let next = app.buttons["Load next page"].firstMatch
        reveal(next, in: app); next.tap()
        XCTAssertTrue(app.staticTexts["Fixture playlist 2"].waitForExistence(timeout: 5))
        let subscriptions = app.buttons["Load subscriptions"]
        reveal(subscriptions, in: app); subscriptions.tap()
        XCTAssertTrue(app.staticTexts["Fixture subscription 1"].waitForExistence(timeout: 5))
        let more = app.buttons["Load next page"].firstMatch
        reveal(more, in: app); more.tap()
        XCTAssertTrue(app.staticTexts["Fixture subscription 2"].waitForExistence(timeout: 5))
    }
}
