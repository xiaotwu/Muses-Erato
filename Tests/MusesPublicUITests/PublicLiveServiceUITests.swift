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
        XCTAssertTrue(app.buttons["public.add"].waitForExistence(timeout: 15))
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
        XCTAssertFalse(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'public.searchError.'")).firstMatch.exists)
    }

    func testRealVisibleYouTubePlayerReportsPlaying() throws {
        let app = try liveApp()
        app.buttons["public.add"].tap()
        app.buttons["public.add.openLink"].tap()
        let field = app.textFields["public.link"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("https://www.youtube.com/watch?v=M7lc1UVf-VE")
        tapOpenLinkAfterKeyboardAppears(in: app)
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

extension XCTestCase {
    @MainActor func tapOpenLinkAfterKeyboardAppears(in app: XCUIApplication) {
        // Typing can finish before the keyboard has moved the sheet from its medium detent.
        // Resolve the button again after keyboard presentation, then send exactly one tap.
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        let button = app.buttons["public.open"]
        XCTAssertTrue(button.isEnabled)
        XCTAssertTrue(button.isHittable)
        let frame = button.frame
        XCTAssertFalse(frame.isEmpty)
        XCTAssertTrue(frame.midX.isFinite && frame.midY.isFinite)
        let window = app.windows.firstMatch
        let windowFrame = window.frame
        let observation = XCTAttachment(string: "Open frame: \(frame); window frame: \(windowFrame); single tap: (\(frame.midX), \(frame.midY))")
        observation.name = "Open link layout before first tap"
        observation.lifetime = .keepAlways
        add(observation)
        window.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.midX - windowFrame.minX, dy: frame.midY - windowFrame.minY))
            .tap()
    }
}
