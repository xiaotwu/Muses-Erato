import XCTest

/// Explicit opt-in only. Every assertion below observes the real iframe; no fixtures/events are injected.
@MainActor final class PublicLivePlaybackCommandUITests: XCTestCase {
    func testQueueSelectionStartsTheSelectedRealVideoOrReportsBrowserBlock() throws {
        guard ProcessInfo.processInfo.environment["MUSES_RUN_LIVE_SERVICE_TESTS"] == "1" else { throw XCTSkip("Live playback requires explicit configuration.") }
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        app.launch()
        func open(_ id: String) {
            XCTAssertTrue(app.buttons["public.add"].waitForExistence(timeout: 15))
            app.buttons["public.add"].tap(); app.buttons["public.add.openLink"].tap()
            let field = app.textFields["public.link"]
            XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap()
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (field.value as? String)?.count ?? 0))
            field.typeText(id)
            tapOpenLinkAfterKeyboardAppears(in: app)
            XCTAssertTrue(app.buttons["Close player"].waitForExistence(timeout: 15))
        }
        open("M7lc1UVf-VE")
        app.buttons["Close player"].tap(); app.tabBars.buttons["Library"].tap()
        let addToQueue = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add ' AND label ENDSWITH ' to queue'")).firstMatch
        for _ in 0..<8 where !addToQueue.isHittable { app.swipeUp() }
        XCTAssertTrue(addToQueue.isHittable); addToQueue.tap()
        app.tabBars.buttons["Home"].tap()
        open("aqz-KE-bpKQ")
        let queue = app.buttons["player.queue"]
        for _ in 0..<6 where !queue.isHittable { app.swipeUp() }
        queue.tap()
        XCTAssertTrue(app.navigationBars["Queue"].waitForExistence(timeout: 5))
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'queue.select.'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        XCTAssertTrue(app.navigationBars["Queue"].waitForNonExistence(timeout: 8))
        let iframe = app.descendants(matching: .any)["public.iframe"]
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (iframe.value as? String)?.contains("M7lc1UVf-VE") == true
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 20), .completed)
        let state = app.staticTexts["public.playbackState"]
        let browserBlock = app.staticTexts["YouTube requires a tap on its visible player controls to start this video."]
        let result = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            state.label == "Playing" || browserBlock.exists
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [result], timeout: 40), .completed,
            "Selecting Queue must request real playback; a browser block must expose recovery")
        if state.label != "Playing" {
            XCTAssertTrue(browserBlock.exists, "A content failure or timeout is not evidence of a browser control block")
            XCTAssertTrue(app.buttons["public.openYouTube"].exists)
            XCTAssertTrue(app.buttons["public.playbackToggle"].isEnabled)
        }
        let observation = XCTAttachment(string: state.label == "Playing" ? "Selected M7lc1UVf-VE confirmed Playing from the real iframe." : "Selected M7lc1UVf-VE received real onAutoplayBlocked; visible controls and Open YouTube are available.")
        observation.name = "Real Queue selection confirmation"; observation.lifetime = .keepAlways; add(observation)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Real Queue selection result"; shot.lifetime = .keepAlways; add(shot)
    }

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
        tapOpenLinkAfterKeyboardAppears(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["public.iframe"].waitForExistence(timeout: 30))
        let state = app.staticTexts["public.playbackState"]
        let toggle = app.buttons["public.playbackToggle"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Ready' OR label == 'Paused'"), object: state)], timeout: 45), .completed)
        var baseline: (main: CGRect, queue: CGRect)?
        var lastSnapshot: (any XCUIElementSnapshot)?
        var observations: [String] = []
        var measurementIndex = 0
        func validFrame(_ frame: CGRect) -> Bool {
            !frame.isEmpty && [frame.minX, frame.minY, frame.maxX, frame.maxY, frame.width, frame.height].allSatisfy { $0.isFinite }
        }
        func sampleControls() -> (main: CGRect, queue: CGRect)? {
            do {
                let snapshot = try app.snapshot()
                lastSnapshot = snapshot
                var pending: [any XCUIElementSnapshot] = [snapshot]
                var nodes: [any XCUIElementSnapshot] = []
                while let node = pending.popLast() {
                    nodes.append(node)
                    pending.append(contentsOf: node.children)
                }
                observations.append("Window: \(snapshot.frame)")
                var controls: [String: CGRect] = [:]
                for identifier in ["public.playbackToggle", "player.queue"] {
                    let matches = nodes.filter { $0.identifier == identifier }
                    observations.append("\(identifier): \(matches.count) matches")
                    for node in matches {
                        observations.append("type=\(node.elementType.rawValue), enabled=\(node.isEnabled), frame=\(node.frame)")
                    }
                    let candidates = matches.filter {
                        $0.elementType == .button && validFrame($0.frame) && validFrame(snapshot.frame)
                            && snapshot.frame.contains($0.frame)
                    }
                    if let frame = candidates.first?.frame,
                       candidates.allSatisfy({ $0.frame == frame }) {
                        controls[identifier] = frame
                    } else {
                        observations.append("No unique finite, nonempty button position inside the window for \(identifier)")
                    }
                }
                guard let main = controls["public.playbackToggle"], let queue = controls["player.queue"] else { return nil }
                return (main, queue)
            } catch {
                observations.append("Snapshot failed: \(error)")
                return nil
            }
        }
        func recordGeometry(_ reason: String, failed: Bool) {
            measurementIndex += 1
            let attachment = XCTAttachment(string: "\(reason)\nBaseline: \(String(describing: baseline))\n" + observations.joined(separator: "\n"))
            attachment.name = "Player control measurement \(measurementIndex)"
            attachment.lifetime = .keepAlways; add(attachment)
            if failed {
                if let snapshot = lastSnapshot {
                    let tree = XCTAttachment(string: String(describing: snapshot.dictionaryRepresentation))
                    tree.name = "Failed control measurement AX tree"; tree.lifetime = .keepAlways; add(tree)
                }
                let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                shot.name = "Failed control measurement screen"; shot.lifetime = .keepAlways; add(shot)
            }
        }
        guard let initial = sampleControls() else {
            recordGeometry("Invalid baseline", failed: true)
            XCTFail("AX must expose finite baseline control frames in the same snapshot")
            return
        }
        baseline = initial
        let toggleFrame = initial.main, queueFrame = initial.queue
        recordGeometry("Baseline", failed: false)
        func assertStableControls() {
            observations.removeAll(keepingCapacity: true)
            var measured: (main: CGRect, queue: CGRect)?
            let frames = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                guard let controls = sampleControls() else { return false }
                measured = controls
                return true
            }, object: nil)
            let result = XCTWaiter.wait(for: [frames], timeout: 2)
            recordGeometry("Same-snapshot sampling result: \(result.rawValue); actual: \(String(describing: measured))", failed: result != .completed || measured == nil)
            guard result == .completed, let measured else {
                XCTFail("AX must expose finite control frames in the same snapshot within 2 seconds")
                return
            }
            let measuredToggle = measured.main, measuredQueue = measured.queue
            XCTAssertEqual(measuredToggle.minY, toggleFrame.minY, accuracy: 1, "State feedback must not move the main control")
            XCTAssertEqual(measuredToggle.midX, toggleFrame.midX, accuracy: 1)
            XCTAssertEqual(measuredToggle.width, 64, accuracy: 0.001)
            XCTAssertEqual(measuredToggle.height, 64, accuracy: 0.001)
            XCTAssertEqual(measuredQueue.minY, queueFrame.minY, accuracy: 1, "Queue must remain in its control slot")
            XCTAssertEqual(measuredQueue.minX, queueFrame.minX, accuracy: 1)
            XCTAssertGreaterThanOrEqual(measuredQueue.width, 44 - 0.000001)
            XCTAssertGreaterThanOrEqual(measuredQueue.height, 44 - 0.000001)
        }
        var timing: [String] = []
        for index in 1...3 {
            XCTAssertTrue(toggle.isEnabled)
            let playAt = Date()
            toggle.tap()
            assertStableControls()
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Playing'"), object: state)], timeout: 30), .completed,
                "The real iframe must confirm Playing. A browser blocked-control notice is a policy result, not confirmed playback.")
            timing.append("cycle \(index) Play confirmation observed after \(Date().timeIntervalSince(playAt))s (UI polling included)")
            assertStableControls()
            XCTAssertTrue(toggle.isEnabled)
            XCTAssertFalse(app.descendants(matching: .any)["public.playbackCommandPending"].exists)
            let pauseAt = Date()
            toggle.tap()
            assertStableControls()
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Paused'"), object: state)], timeout: 10), .completed,
                "Paused must come from the real iframe event, not the host command.")
            timing.append("cycle \(index) Pause confirmation observed after \(Date().timeIntervalSince(pauseAt))s (UI polling included)")
            assertStableControls()
            XCTAssertTrue(toggle.isEnabled)
        }
        let iframe = app.descendants(matching: .any)["public.iframe"]
        let instance = iframe.value as? String
        XCTAssertFalse(instance?.isEmpty ?? true)
        let elapsed = app.descendants(matching: .any)["player.elapsed"].label
        for mode in ["Music", "Video"] {
            app.segmentedControls["player.presentation"].buttons[mode].tap()
            XCTAssertEqual(iframe.value as? String, instance, "Changing layout must retain the adapter and load generation")
            XCTAssertEqual(app.descendants(matching: .any)["player.elapsed"].label, elapsed, "Paused position must survive layout changes")
            XCTAssertEqual(state.label, "Paused")
            XCTAssertGreaterThanOrEqual(iframe.frame.width, 200)
            XCTAssertGreaterThanOrEqual(iframe.frame.height, 200)
            XCTAssertTrue(app.frame.contains(iframe.frame))
        }
        toggle.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Playing'"), object: state)], timeout: 30), .completed)
        for mode in ["Music", "Video"] {
            let before = app.descendants(matching: .any)["player.elapsed"].label
            app.segmentedControls["player.presentation"].buttons[mode].tap()
            XCTAssertEqual(iframe.value as? String, instance, "Playing layout changes must retain the actual WKWebView and generation")
            XCTAssertEqual(state.label, "Playing")
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                app.descendants(matching: .any)["player.elapsed"].label != before
            }, object: nil)], timeout: 8), .completed, "Real playback time must continue advancing after a layout change")
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = "Real playing iframe in \(mode) layout"; shot.lifetime = .keepAlways; add(shot)
            if mode == "Music" {
                XCUIDevice.shared.orientation = .landscapeLeft
                XCTAssertGreaterThan(app.frame.width, app.frame.height)
                XCTAssertEqual(iframe.value as? String, instance)
                XCTAssertGreaterThanOrEqual(iframe.frame.width, 200)
                XCTAssertGreaterThanOrEqual(iframe.frame.height, 200)
                XCTAssertTrue(app.frame.contains(iframe.frame))
                let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                landscape.name = "Real playing Music iframe in landscape"; landscape.lifetime = .keepAlways; add(landscape)
                XCUIDevice.shared.orientation = .portrait
            }
        }
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
