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
    func testMadeForKidsShowsRestrictionAndExternalAction() {
        let app = launch()
        let entry = app.buttons["public.openLinkEntry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5)); entry.tap()
        let link = app.textFields["public.link"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap(); link.typeText("MFKabcdefgh")
        app.buttons["public.open"].tap()
        XCTAssertTrue(app.staticTexts["Failed"].waitForExistence(timeout: 8))
        let notices = app.staticTexts.matching(identifier: "Made for Kids videos are not supported by this embedded player. Open this video in YouTube.")
        XCTAssertTrue(notices.firstMatch.waitForExistence(timeout: 5))
        // The presenting Home and player both show the shared session failure.
        // Check the visible label rather than requiring one global match.
        XCTAssertTrue(notices.allElementsBoundByIndex.contains { $0.isHittable })
        XCTAssertFalse(app.buttons["Play"].isEnabled)
        XCTAssertTrue(app.buttons["Close player"].isEnabled)
        app.buttons["Playback actions"].tap()
        let external = app.buttons["Website playback"]
        XCTAssertTrue(external.waitForExistence(timeout: 5))
        XCTAssertTrue(external.isEnabled)
        // Dismiss the menu without launching the external website.
        app.navigationBars["Now Playing"].staticTexts["Now Playing"].tap()
        app.buttons["Close player"].tap()
        XCTAssertTrue(app.buttons["public.openLinkEntry"].waitForExistence(timeout: 5))
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
        let entry = app.buttons["public.openLinkEntry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5)); entry.tap()
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
        let account = app.buttons["settings.account"]
        XCTAssertTrue(account.waitForExistence(timeout: 5)); account.tap()
        app.buttons["Account & YouTube collections"].tap()
        app.buttons["Load my YouTube playlists"].tap()
        app.buttons.containing(.staticText, identifier: "Fixture public playlist").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Fixture playlist description"].waitForExistence(timeout: 5))
        app.buttons["Load playlist videos"].tap()
        app.buttons.containing(.staticText, identifier: "Fixture playlist video 1").firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["public.iframe"].waitForExistence(timeout: 10))
        app.buttons["Close player"].tap()
        XCTAssertTrue(app.staticTexts["Fixture playlist description"].waitForExistence(timeout: 5))
    }
    func testReadOnlyAccountCollectionsAndProfileSeparation() {
        let app = launch()
        app.buttons["Settings"].firstMatch.tap()
        let account = app.buttons["settings.account"]
        XCTAssertTrue(account.waitForExistence(timeout: 5)); account.tap()
        let channelID = app.staticTexts["account.channelID"]
        XCTAssertTrue(channelID.waitForExistence(timeout: 5))
        XCTAssertEqual(channelID.label, "UCabcdefghijklmnopqrstuv")
        XCTAssertTrue(app.buttons["Copy Channel ID"].isEnabled)
        app.buttons["Account & YouTube collections"].tap()
        XCTAssertTrue(app.staticTexts["YouTube collections are read-only."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0 saved videos · 0 local playlists"].exists)
        // Settings has already loaded the authenticated channel; collections reuses that page.
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
