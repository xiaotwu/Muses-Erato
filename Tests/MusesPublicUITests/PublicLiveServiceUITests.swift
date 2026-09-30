import XCTest

/// Opt-in checks against Google and YouTube. Ordinary CI runs explicitly skip these.
@MainActor final class PublicLiveServiceUITests: XCTestCase {
    private func liveApp() throws -> XCUIApplication {
        guard ProcessInfo.processInfo.environment["MUSES_RUN_LIVE_SERVICE_TESTS"] == "1" else {
            throw XCTSkip("Live service verification requires an explicitly configured local build.")
        }
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        // Deliberately omit the fixture catalog: requests and player events must be real.
        app.launch()
        XCTAssertTrue(app.buttons["public.openLinkEntry"].waitForExistence(timeout: 15))
        return app
    }

    func testRealYouTubeSearchReturnsVideoResults() throws {
        let app = try liveApp()
        app.tabBars.buttons["Search"].tap()
        let field = app.textFields["public.search"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("YouTube Developers")
        app.buttons["public.submitSearch"].tap()
        let result = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'catalog.actions.'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 45), "Real video results must appear; a fixture or error page does not satisfy this check.")
        XCTAssertFalse(app.descendants(matching: .any)["public.searchError"].exists)
    }

    func testRealVisibleYouTubePlayerReportsPlaying() throws {
        let app = try liveApp()
        app.buttons["public.openLinkEntry"].tap()
        let field = app.textFields["public.link"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("https://www.youtube.com/watch?v=M7lc1UVf-VE")
        app.buttons["public.open"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["public.iframe"].waitForExistence(timeout: 30))
        let state = app.staticTexts["public.playbackState"]
        let playing = NSPredicate(format: "label == 'Playing'")
        let expectation = XCTNSPredicateExpectation(predicate: playing, object: state)
        if XCTWaiter.wait(for: [expectation], timeout: 15) != .completed {
            let play = app.buttons["Play"]
            if play.exists && play.isEnabled { play.tap() }
            let afterInteraction = XCTNSPredicateExpectation(predicate: playing, object: state)
            XCTAssertEqual(XCTWaiter.wait(for: [afterInteraction], timeout: 30), .completed,
                "The real iframe must report playing, not merely exist on screen.")
        }
        XCTAssertTrue(app.buttons["Pause"].isEnabled)
        app.buttons["Pause"].tap()
        let paused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Paused'"), object: state)
        XCTAssertEqual(XCTWaiter.wait(for: [paused], timeout: 10), .completed)
    }
}
