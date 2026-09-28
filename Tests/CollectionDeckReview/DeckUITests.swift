import XCTest

@MainActor final class DeckUITests: XCTestCase {
    private func launch(large: Bool = false, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        if large { app.launchEnvironment["DECK_LARGE"] = "1" }
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch(); XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'library.play.'")).firstMatch.waitForExistence(timeout: 20)); return app
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let shot = app.screenshot()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("deck-review-shots")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: folder.appendingPathComponent(name + ".png"))
        print("DECK_SCREENSHOT: " + folder.path)
        let attachment = XCTAttachment(screenshot: shot); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testFanSwipeListVerticalScrollAndPlaylistPlayback() {
        let app = launch()
        sleep(3)
        capture("cards-initial", app)
        let focused = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'library.play.'")).firstMatch
        let initial = focused.label
        focused.swipeLeft()
        XCTAssertNotEqual(focused.label, initial)
        XCTAssertFalse(app.descendants(matching: .any)["public.iframe"].exists)
        capture("cards-after-swipe", app)
        app.buttons["collection.previous"].tap()
        XCTAssertEqual(focused.label, initial)
        app.buttons["library.presentation.List"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library.detail.'")).firstMatch.waitForExistence(timeout: 5))
        capture("compact-list", app)
        app.buttons["library.presentation.Cards"].tap()
        // Vertical drag starting on the deck must still move the surrounding page.
        focused.swipeUp()
        let bottom = app.staticTexts["review.bottom"]
        for _ in 0..<3 where !bottom.isHittable { app.swipeUp() }
        XCTAssertTrue(bottom.isHittable)
        capture("playlist-block", app)
        let strip = app.scrollViews.matching(NSPredicate(format: "identifier BEGINSWITH 'playlist.entries.'")).firstMatch
        XCTAssertTrue(strip.exists)
        strip.swipeLeft()
        capture("playlist-after-swipe", app)
        XCTAssertFalse(app.descendants(matching: .any)["public.iframe"].exists)
        let previousEntries = app.buttons["Previous entries in Late night selections"]
        XCTAssertTrue(previousEntries.isEnabled)
        previousEntries.tap()
        XCTAssertFalse(app.descendants(matching: .any)["public.iframe"].exists)
        capture("playlist-after-arrow", app)
        let card = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'playlist.entry.'")).allElementsBoundByIndex.first { $0.isHittable && $0.isEnabled && $0.frame.minX >= strip.frame.minX && $0.frame.maxX <= strip.frame.maxX }
        XCTAssertNotNil(card)
        card?.tap()
        XCTAssertTrue(app.descendants(matching: .any)["public.iframe"].waitForExistence(timeout: 15))
        capture("visible-playlist-player", app)
    }
    func testAccessibilityTextAndControlTargets() {
        let app = launch(largeText: true)
        capture("cards-accessibility-text", app)
        for identifier in ["library.presentation.Cards", "library.presentation.List"] {
            XCTAssertGreaterThanOrEqual(app.buttons[identifier].frame.height, 44)
        }
        let next = app.buttons["collection.next"]
        if !next.isHittable { app.swipeUp() }
        XCTAssertGreaterThanOrEqual(next.frame.height, 44)
        XCTAssertGreaterThanOrEqual(next.frame.width, 44)
        next.tap()
        XCTAssertTrue(app.staticTexts["collection.position"].label.hasPrefix("2"))
        app.swipeDown()
        app.buttons["library.presentation.List"].tap()
        capture("list-accessibility-text", app)
    }
    func testExposedNeighborFocusesAndCenterOpensPlayer() {
        let app = launch()
        let focused = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'library.play.'")).firstMatch
        let cardWidth = min(260.0, focused.frame.width * 0.62)
        focused.coordinate(withNormalizedOffset: CGVector(dx: 0.5 + cardWidth * 0.55 / focused.frame.width, dy: 0.45)).tap()
        XCTAssertTrue(app.staticTexts["collection.position"].label.hasPrefix("2"))
        XCTAssertFalse(app.descendants(matching: .any)["public.iframe"].exists)
        focused.tap()
        XCTAssertTrue(app.descendants(matching: .any)["public.iframe"].waitForExistence(timeout: 15))
        capture("visible-center-player", app)
    }
    func testFiveThousandItemsRemainNavigable() {
        let app = launch(large: true)
        // Off-center cards are hidden from VoiceOver. The view-window bound is tested directly in DeckUnitTests.
        app.buttons["collection.next"].tap()
        XCTAssertTrue(app.staticTexts["collection.position"].label.replacingOccurrences(of: ",", with: "").contains("5000"))
    }
}
