import XCTest

/// Explicit opt-in only. Every assertion below observes the real iframe; no fixtures/events are injected.
@MainActor final class PublicLivePlaybackCommandUITests: XCTestCase {
    func testRealPlayPauseCyclesAndForegroundLifecycleConfirmation() throws {
        guard ProcessInfo.processInfo.environment["MUSES_RUN_LIVE_SERVICE_TESTS"] == "1" else {
            throw XCTSkip("Live playback verification requires an explicitly configured local build.")
        }
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["public.add"].waitForExistence(timeout: 15))
        app.buttons["public.add"].tap()
        app.buttons["public.add.openLink"].tap()
        let field = app.textFields["public.link"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("https://www.youtube.com/watch?v=M7lc1UVf-VE")
        app.buttons["public.open"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["public.iframe"].waitForExistence(timeout: 30))
        let state = app.staticTexts["public.playbackState"]
        let toggle = app.buttons["public.playbackToggle"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Ready' OR label == 'Paused'"), object: state)], timeout: 45), .completed)
        var timing: [String] = []
        for index in 1...3 {
            XCTAssertTrue(toggle.isEnabled)
            let playAt = Date()
            toggle.tap()
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Playing'"), object: state)], timeout: 30), .completed,
                "The real iframe must confirm Playing. A browser blocked-control notice is a policy result, not confirmed playback.")
            timing.append("cycle \(index) Play confirmation observed after \(Date().timeIntervalSince(playAt))s (UI polling included)")
            XCTAssertTrue(toggle.isEnabled)
            XCTAssertFalse(app.descendants(matching: .any)["public.playbackCommandPending"].exists)
            let pauseAt = Date()
            toggle.tap()
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Paused'"), object: state)], timeout: 10), .completed,
                "Paused must come from the real iframe event, not the host command.")
            timing.append("cycle \(index) Pause confirmation observed after \(Date().timeIntervalSince(pauseAt))s (UI polling included)")
            XCTAssertTrue(toggle.isEnabled)
        }
        toggle.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Playing'"), object: state)], timeout: 30), .completed)
        // Exercises RootView's actual scenePhase -> suspendVisiblePlayback route.
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Paused'"), object: state)], timeout: 10), .completed)
        XCTAssertFalse(app.descendants(matching: .any)["public.playbackCommandPending"].exists)
        let unsolicitedPlaying = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Playing'"), object: state)
        unsolicitedPlaying.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [unsolicitedPlaying], timeout: 2), .completed, "Foreground return must not automatically restart playback")
        let attachment = XCTAttachment(string: timing.joined(separator: "\n"))
        attachment.name = "Real iframe control confirmation observations"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
