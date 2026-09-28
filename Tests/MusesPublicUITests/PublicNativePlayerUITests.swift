import XCTest

@MainActor final class PublicNativePlayerUITests: XCTestCase {
    func testNativeControlsMinimizeAndCloudSyncConfirmation() {
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        app.launchEnvironment["MUSES_UI_TEST_CATALOG"] = "fixtures"
        app.launch()
        app.buttons["public.openLinkEntry"].tap()
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
        app.buttons["Close settings"].tap()
        XCTAssertTrue(app.buttons["player.mini.open"].waitForExistence(timeout: 5)); app.buttons["player.mini.open"].tap()
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
    }
}
