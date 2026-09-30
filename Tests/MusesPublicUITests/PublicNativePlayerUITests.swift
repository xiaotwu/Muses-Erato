import XCTest

@MainActor final class PublicNativePlayerUITests: XCTestCase {
    func testNativeControlsMinimizeAndCloudSyncConfirmation() {
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        app.launchEnvironment["MUSES_UI_TEST_CATALOG"] = "fixtures"
        app.launch()
        app.buttons["public.add"].tap()
        app.buttons["public.add.openLink"].tap()
        app.textFields["public.link"].tap(); app.textFields["public.link"].typeText("dQw4w9WgXcQ")
        app.buttons["public.open"].tap()
        XCTAssertTrue(app.buttons["Close player"].waitForExistence(timeout: 8)); app.buttons["Close player"].tap()
        app.buttons["Settings"].firstMatch.tap()
        app.buttons["Library & data"].tap()
        app.buttons["Refresh details"].tap()
        XCTAssertTrue(app.alerts["Sync details from YouTube?"].waitForExistence(timeout: 3))
        app.alerts.buttons["Cancel"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Playback"].tap()
        app.buttons["playback.backgroundAudio"].tap()
        XCTAssertTrue(app.alerts["Enable experimental background playback?"].waitForExistence(timeout: 3))
        app.alerts.buttons["Enable background audio"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let closeSettings = app.buttons["Close settings"]
        closeSettings.tap()
        XCTAssertTrue(closeSettings.waitForNonExistence(timeout: 5), "Settings must finish dismissal before opening the player")
        let openPlayer = app.buttons["player.mini.open"]
        var openFrame = CGRect.zero
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard openPlayer.exists else { return false }
            let frame = openPlayer.frame
            guard !frame.isEmpty && app.frame.contains(frame) else { return false }
            openFrame = frame
            return true
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed,
            "Mini player must expose an on-screen frame before opening")
        // The system tab accessory can expose an invalid AX activation point after a sheet closes.
        // Once its frame is ready, tap its center and still require the real player controls.
        XCTAssertFalse(openFrame.isEmpty)
        XCTAssertTrue(app.frame.contains(openFrame))
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: openFrame.midX, dy: openFrame.midY)).tap()
        XCTAssertTrue(app.buttons["player.toggle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.sliders["Playback position"].exists)
        XCTAssertTrue(app.buttons["player.queue"].isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "Native Now Playing (generated silent audio)"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.buttons["Playback actions"].tap()
        XCTAssertTrue(app.buttons["Website playback"].exists)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.45)).tap()
        app.buttons["Close player"].tap()
        XCTAssertTrue(app.buttons["player.mini.open"].waitForExistence(timeout: 3))
        let mini = app.buttons["player.mini.open"]
        let tabs = app.tabBars.firstMatch
        XCTAssertLessThanOrEqual(mini.frame.maxY, tabs.frame.minY + 2, "Mini player must sit above the tab bar")
        let miniQueue = app.buttons["public.queue"]
        XCTAssertTrue(miniQueue.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(miniQueue.frame.width + 0.000001, 44)
        XCTAssertGreaterThanOrEqual(miniQueue.frame.height + 0.000001, 44)
        XCTAssertTrue(app.frame.contains(miniQueue.frame))
        XCTAssertLessThanOrEqual(mini.frame.maxX, miniQueue.frame.minX, "Queue must leave the Native title/artwork open region intact")
        let miniShot = XCTAttachment(screenshot: app.screenshot()); miniShot.name = "Native mini player with Queue"; miniShot.lifetime = .keepAlways; add(miniShot)
        miniQueue.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars["Queue"].waitForExistence(timeout: 5))
        app.buttons["Open visible player"].tap()
        XCTAssertTrue(app.buttons["player.toggle"].waitForExistence(timeout: 8), "Native mini Queue must dismiss before presenting the Native player")
    }
    func testHomeAndHistoryRowsPlayWithoutDetailsAndHeroCoversRemainPassive() {
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        app.launchEnvironment["MUSES_UI_TEST_CATALOG"] = "fixtures"
        app.launch()
        app.buttons["public.add"].tap()
        app.buttons["public.add.openLink"].tap()
        app.textFields["public.link"].tap(); app.textFields["public.link"].typeText("dQw4w9WgXcQ")
        app.buttons["public.open"].tap()
        XCTAssertTrue(app.buttons["Close player"].waitForExistence(timeout: 8)); app.buttons["Close player"].tap()
        app.buttons["Settings"].firstMatch.tap(); app.buttons["Playback"].tap()
        app.buttons["playback.backgroundAudio"].tap(); app.alerts.buttons["Enable background audio"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap(); app.buttons["Close settings"].tap()
        addSavedVideosToLocalPlaylist(app, name: "Hero cover acceptance")
        app.tabBars.buttons["Home"].tap()
        let homeRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'home.play.'")).firstMatch
        for _ in 0..<8 where !homeRow.exists || !homeRow.isHittable { app.swipeUp() }
        XCTAssertTrue(homeRow.exists); homeRow.tap()
        XCTAssertTrue(app.buttons["player.toggle"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Details"].exists)
        app.buttons["player.queue"].tap()
        let queue = XCTAttachment(screenshot: app.screenshot()); queue.name = "Queue hero covers"; queue.lifetime = .keepAlways; add(queue)
        app.buttons["Done"].tap(); app.buttons["Close player"].tap()
        app.tabBars.buttons["Library"].tap()
        let rail = app.scrollViews["library.categories"]
        let history = app.buttons["library.category.History"]
        for _ in 0..<10 where !history.isHittable { rail.swipeLeft(velocity: .slow) }
        XCTAssertTrue(history.isHittable); history.tap()
        let listMode = app.buttons["library.presentation.List"]
        let count = app.staticTexts["library.itemCount"]
        XCTAssertEqual(listMode.frame.midY, count.frame.midY, accuracy: 12, "Layout selector belongs on the count/delete toolbar row")
        XCTAssertFalse(app.staticTexts["Cards"].exists); XCTAssertFalse(app.staticTexts["List"].exists)
        listMode.tap()
        let historyRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library.row.play.'")).firstMatch
        XCTAssertTrue(historyRow.waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "History hero covers"; shot.lifetime = .keepAlways; add(shot)
        historyRow.tap()
        XCTAssertTrue(app.buttons["player.toggle"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Details"].exists)
    }

}
