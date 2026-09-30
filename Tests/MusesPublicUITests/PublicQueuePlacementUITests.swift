import XCTest

@MainActor final class PublicQueuePlacementUITests: XCTestCase {
    private func launch(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        app.launchEnvironment["MUSES_UI_TEST_CATALOG"] = "fixtures"
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        return app
    }
    private func openPlayer(_ app: XCUIApplication, videoID: String = "M7lc1UVf-VE") {
        XCTAssertTrue(app.buttons["public.add"].waitForExistence(timeout: 8))
        app.buttons["public.add"].tap(); app.buttons["public.add.openLink"].tap()
        let field = app.textFields["public.link"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText(videoID)
        app.buttons["public.open"].tap()
        XCTAssertTrue(app.buttons["Close player"].waitForExistence(timeout: 10))
    }
    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<7 {
            if element.isHittable, element.frame.minY.isFinite, app.frame.contains(element.frame) { return }
            app.scrollViews["player.details"].swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
    private func assertBounds(_ control: XCUIElement, app: XCUIApplication) {
        // AX CGRects can represent 44pt as 43.99999999999994. This tolerance is far
        // below a display pixel and still rejects any materially undersized target.
        let epsilon: CGFloat = 0.000001
        XCTAssertGreaterThanOrEqual(control.frame.width + epsilon, 44)
        XCTAssertGreaterThanOrEqual(control.frame.height + epsilon, 44)
        XCTAssertTrue(app.frame.contains(control.frame))
    }
    private func checkPlacement(largeText: Bool) {
        let app = launch(largeText: largeText)
        openPlayer(app)
        let playerQueue = app.buttons["player.queue"]
        reveal(playerQueue, app: app); assertBounds(playerQueue, app: app)
        let toggle = app.buttons["public.playbackToggle"]
        assertBounds(toggle, app: app)
        XCTAssertTrue(toggle.isHittable)
        XCTAssertEqual(toggle.frame.midY, playerQueue.frame.midY, accuracy: 1)
        XCTAssertLessThan(toggle.frame.maxX, app.buttons["Next"].frame.minX)
        XCTAssertLessThanOrEqual(app.buttons["Next"].frame.maxX, playerQueue.frame.minX)
        let iframe = app.descendants(matching: .any)["public.iframe"]
        for mode in ["Music", "Video"] {
            app.segmentedControls["player.presentation"].buttons[mode].tap()
            XCTAssertGreaterThanOrEqual(iframe.frame.width, 200)
            XCTAssertGreaterThanOrEqual(iframe.frame.height, 200)
            XCTAssertTrue(app.frame.contains(iframe.frame))
        }
        let playerShot = XCTAttachment(screenshot: app.screenshot())
        playerShot.name = "Queue in player controls " + (largeText ? "maximum text" : "ordinary")
        playerShot.lifetime = .keepAlways; add(playerShot)
        playerQueue.tap()
        XCTAssertTrue(app.navigationBars["Queue"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["player.queue.close"].exists, "Queue opens directly as its own sheet")
        app.buttons["player.queue.close"].tap()
        XCTAssertTrue(app.buttons["Close player"].waitForExistence(timeout: 5))
        app.buttons["Close player"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["Close player"].waitForNonExistence(timeout: 5))
        app.tabBars.buttons["Library"].tap()
        let miniQueue = app.buttons["public.queue"]
        XCTAssertTrue(miniQueue.waitForExistence(timeout: 5)); assertBounds(miniQueue, app: app)
        let miniOpen = app.buttons["player.mini.open"]
        assertBounds(miniOpen, app: app)
        XCTAssertLessThanOrEqual(miniOpen.frame.maxX, miniQueue.frame.minX, "Queue must not overlap the cover/title open region")
        XCTAssertFalse(app.navigationBars["Library"].buttons["public.queue"].exists)
        let miniShot = XCTAttachment(screenshot: app.screenshot())
        miniShot.name = "Queue in mini player " + (largeText ? "maximum text" : "ordinary")
        miniShot.lifetime = .keepAlways; add(miniShot)
        miniQueue.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars["Queue"].waitForExistence(timeout: 5))
        app.buttons["Open visible player"].tap()
        XCTAssertTrue(app.buttons["Close player"].waitForExistence(timeout: 8), "Queue must dismiss before Now Playing is presented")
        XCTAssertTrue(app.descendants(matching: .any)["public.iframe"].waitForExistence(timeout: 5))
        app.buttons["Close player"].tap()
        XCTAssertTrue(miniOpen.waitForExistence(timeout: 5))
        miniOpen.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["player.queue"].waitForExistence(timeout: 5), "Opening queue must not steal the mini-player's Now Playing region")
    }
    func testQueueLivesInPlayerAndMiniPlayer() { checkPlacement(largeText: false) }
    func testQueueBoundsAtMaximumText() { checkPlacement(largeText: true) }

    func testLandscapeKeepsVideoAndControlsReachable() {
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch()
        openPlayer(app)
        XCTAssertGreaterThan(app.frame.width, app.frame.height, "The app must have actually rotated")
        let iframe = app.descendants(matching: .any)["public.iframe"]
        for mode in ["Video", "Music"] {
            app.segmentedControls["player.presentation"].buttons[mode].tap()
            XCTAssertGreaterThanOrEqual(iframe.frame.width, 200)
            XCTAssertGreaterThanOrEqual(iframe.frame.height, 200)
            XCTAssertTrue(app.frame.contains(iframe.frame))
            let queue = app.buttons["player.queue"]
            reveal(queue, app: app); assertBounds(queue, app: app)
            let toggle = app.buttons["public.playbackToggle"]
            XCTAssertTrue(toggle.isHittable)
            XCTAssertLessThanOrEqual(iframe.frame.maxX, toggle.frame.minX, "Landscape media and transport must occupy separate columns")
        }
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "Landscape Music and visible YouTube"; shot.lifetime = .keepAlways; add(shot)
    }

    func testFailureRecoveryRemainsReachableAtMaximumText() {
        let app = launch(largeText: true)
        openPlayer(app, videoID: "MFKabcdefgh")
        let retry = app.buttons["public.retryPlayback"]
        reveal(retry, app: app)
        XCTAssertTrue(retry.exists)
        retry.tap()
        XCTAssertEqual(app.staticTexts["public.playbackState"].label, "Failed", "A new status check must preserve the content restriction")
        let website = app.buttons["public.openYouTube"]
        reveal(website, app: app); assertBounds(website, app: app)
        XCTAssertTrue(website.isHittable)
        let queue = app.buttons["player.queue"]
        for _ in 0..<5 {
            if queue.isHittable, queue.frame.minY.isFinite, app.frame.contains(queue.frame) { break }
            app.scrollViews["player.details"].swipeDown()
        }
        XCTAssertTrue(queue.isHittable); queue.tap()
        XCTAssertTrue(app.navigationBars["Queue"].waitForExistence(timeout: 5))
        app.buttons["player.queue.close"].tap()
        app.buttons["Playback actions"].tap(); app.buttons["Playback info"].tap()
        XCTAssertTrue(app.navigationBars["Playback info"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["YouTube plays while this player is visible and Muses is in the foreground. Leaving the player or app pauses playback."].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Player info at maximum text"; shot.lifetime = .keepAlways; add(shot)
    }

    func testQueuedOnlyLibraryHasQueueAndCanOpenFirstVideo() {
        let app = launch()
        app.tabBars.buttons["Search"].tap()
        let field = app.textFields["public.search"]
        field.tap(); field.typeText("fixture")
        app.buttons["public.submitSearch"].tap()
        let actions = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'catalog.actions.'")).firstMatch
        XCTAssertTrue(actions.waitForExistence(timeout: 8)); actions.tap(); app.buttons["Add to queue"].tap()
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.buttons["public.queue"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["player.mini.open"].isEnabled)
        let openFirst = app.buttons["Open queued video"]
        XCTAssertTrue(openFirst.isEnabled); assertBounds(openFirst, app: app)
        app.buttons["public.queue"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars["Queue"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'queue.entry.'")).count, 1)
        app.buttons["player.queue.close"].tap()
        openFirst.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["Close player"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["player.queue"].exists)
        XCTAssertNotEqual(app.staticTexts["public.playbackState"].label, "Playing", "Opening the queued video does not synthesize playback")
    }
}
