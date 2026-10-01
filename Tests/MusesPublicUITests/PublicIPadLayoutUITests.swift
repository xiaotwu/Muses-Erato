import XCTest

@MainActor class PublicIPadUITestCase: XCTestCase {
    private let sidebarPrefix = "public.sidebar."
    override func setUpWithError() throws {
        try super.setUpWithError()
        let isIPad = MainActor.assumeIsolated { UIDevice.current.userInterfaceIdiom == .pad }
        guard isIPad else { throw XCTSkip("Requires an iPad simulator for system window and regular sidebar coverage") }
    }
    override func tearDown() {
        MainActor.assumeIsolated { XCUIDevice.shared.orientation = .portrait }
        super.tearDown()
    }

    func launch(largeText: Bool = false, orientation: UIDeviceOrientation = .landscapeLeft) -> XCUIApplication {
        XCUIDevice.shared.orientation = orientation
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        app.launchEnvironment["MUSES_UI_TEST_CATALOG"] = "fixtures"
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCUIDevice.shared.orientation = orientation
        if app.windows.firstMatch.frame.width < 600 {
            let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            system.buttons["window-controls:com.xiaotwu.muses.erato"].tap()
            system.buttons["Zoom-button"].tap()
            app.activate()
        }
        XCTAssertTrue(app.buttons["public.add"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["public.add"].label.contains("Add"))
        return app
    }

    func select(_ destination: String, in app: XCUIApplication, regular: Bool = true) {
        if regular {
            XCTAssertFalse(app.tabBars.buttons[destination].exists, "Regular reconstruction must use NavigationSplitView, not compact tabs")
            let button = app.buttons[sidebarPrefix + destination]
            if !button.isHittable {
                let toggle = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sidebar'")).firstMatch
                if toggle.exists { toggle.tap() }
            }
            XCTAssertTrue(button.waitForExistence(timeout: 5)); XCTAssertTrue(button.isHittable)
            button.tap()
        } else {
            let button = app.buttons[destination].firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 5)); button.tap()
        }
    }

    func capture(_ name: String, app: XCUIApplication) {
        // XCTest idleness does not include SwiftUI's short category crossfade.
        Thread.sleep(forTimeInterval: 0.4)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    func reveal(_ item: XCUIElement, app: XCUIApplication) {
        for _ in 0..<8 where !item.isHittable { app.swipeUp() }
        XCTAssertTrue(item.isHittable)
    }
    func saveVideo(_ app: XCUIApplication) {
        app.buttons["public.add"].tap()
        app.buttons["public.add.openLink"].tap()
        let field = app.textFields["public.link"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText("dQw4w9WgXcQ")
        app.buttons["public.open"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["public.iframe"].waitForExistence(timeout: 10))
        app.buttons["Close player"].tap()
    }
    func createPlaylist(_ app: XCUIApplication) {
        select("Library", in: app)
        app.buttons["library.add"].tap(); app.buttons["public.createPlaylist"].tap()
        app.alerts.textFields.firstMatch.typeText("iPad local collection")
        app.alerts.buttons["Create"].tap()
    }
    func submit(_ query: String, app: XCUIApplication) {
        let field = app.textFields["public.search"]
        reveal(field, app: app); field.tap(); field.typeText(query)
        app.buttons["public.submitSearch"].tap()
    }
    func choose(_ choice: String, picker: String, app: XCUIApplication, largeText: Bool = false) {
        selectSearchFilter(choice, group: picker == "public.searchSource" ? "Source" : "Type", in: app)
    }

}

@MainActor final class PublicIPadLayoutUITests: PublicIPadUITestCase {
    func testRegularSidebarRebuildPreservesSavedVideoPlaylistAndOnlineIdentity() {
        let app = launch(); saveVideo(app); createPlaylist(app)
        select("Search", in: app)
        choose("On this device", picker: "public.searchSource", app: app)
        submit("YouTube", app: app)
        let heading = app.staticTexts["public.searchResultsHeading"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        let videoHeading = heading.label
        XCTAssertTrue(videoHeading.contains("1 result")); XCTAssertTrue(videoHeading.contains("Video"))
        XCTAssertTrue(app.staticTexts["Saved video · On this device"].exists)
        select("Library", in: app); select("Search", in: app)
        XCTAssertEqual(heading.label, videoHeading)
        XCTAssertEqual(app.textFields["public.search"].value as? String, "YouTube")
        XCTAssertTrue(app.staticTexts["Saved video · On this device"].exists)
        capture("iPad regular local video rebuilt", app: app)

        app.buttons["public.clearSearch"].tap()
        choose("Playlists", picker: "public.searchKind", app: app)
        submit("iPad", app: app)
        XCTAssertTrue(app.staticTexts["Local playlist · On this device"].waitForExistence(timeout: 5))
        let playlistHeading = heading.label
        select("Home", in: app); select("Search", in: app)
        XCTAssertEqual(heading.label, playlistHeading)
        XCTAssertTrue(app.staticTexts["iPad local collection"].exists)
        XCTAssertEqual(app.textFields["public.search"].value as? String, "iPad")
        capture("iPad regular local playlist rebuilt", app: app)

        app.buttons["public.clearSearch"].tap()
        choose("YouTube", picker: "public.searchSource", app: app)
        choose("Videos", picker: "public.searchKind", app: app)
        submit("fixture", app: app)
        XCTAssertTrue(app.staticTexts["Fixture first video"].waitForExistence(timeout: 5))
        let onlineHeading = heading.label
        choose("Playlists", picker: "public.searchKind", app: app)
        select("Library", in: app); select("Search", in: app)
        XCTAssertEqual(heading.label, onlineHeading, "Draft kind must not relabel the submitted video results")
        XCTAssertTrue(app.staticTexts["Fixture first video"].exists)
        XCTAssertFalse(app.staticTexts["Local playlist · On this device"].exists)
        capture("iPad regular online rebuilt", app: app)
    }

    func testIPadPortraitLandscapeEntrypointsAndSettings() {
        let app = launch()
        select("Library", in: app)
        for name in ["Videos", "Playlists", "Favorites", "History"] {
            let category = app.buttons["library.category." + name]
            XCTAssertTrue(category.isHittable); category.tap()
        }
        capture("iPad landscape empty Library", app: app)
        XCUIDevice.shared.orientation = .portrait
        select("Home", in: app)
        let addControl = app.buttons["public.add"]
        XCTAssertTrue(addControl.waitForExistence(timeout: 5))
        XCTAssertFalse(addControl.frame.isEmpty)
        // Application bounds use a local origin after windowing; window and
        // descendant frames share screen coordinates, including its offset.
        let windowFrame = app.windows.firstMatch.frame
        let addFrame = addControl.frame
        let controlBounds = XCTAttachment(string: "Application: \(app.frame); window: \(windowFrame); Add: \(addFrame)")
        controlBounds.name = "iPad narrow window Add bounds"; controlBounds.lifetime = .keepAlways; add(controlBounds)
        XCTAssertTrue(windowFrame.contains(addFrame), "Add must fit inside the visible application window")
        addControl.tap()
        for id in ["public.add.openLink", "public.add.import", "public.add.create"] {
            XCTAssertTrue(app.buttons[id].isHittable)
        }
        app.buttons["public.add.openLink"].tap()
        XCTAssertTrue(app.textFields["public.link"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        capture("iPad portrait Home", app: app)
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        capture("iPad portrait Settings", app: app)
        app.buttons["Close settings"].tap()
        select("Search", in: app)
        XCTAssertTrue(app.textFields["public.search"].isHittable)
        XCUIDevice.shared.orientation = .landscapeLeft
        select("Library", in: app)
        XCTAssertTrue(app.buttons["public.start.search"].isHittable)
        app.buttons["public.start.search"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue((app.buttons["public.searchFilters"].value as? String)?.contains("Videos") == true)
        capture("iPad landscape focused Search", app: app)
    }

    func testIPadMaximumTextLandscapeLibrarySearchAndSettings() {
        let app = launch(largeText: true)
        select("Library", in: app, regular: false)
        for name in ["Videos", "Playlists", "Favorites", "History"] {
            let category = app.buttons["library.category." + name]
            for _ in 0..<8 where !category.isHittable { app.swipeDown() }
            XCTAssertTrue(category.isHittable); category.tap()
        }
        capture("iPad maximum text landscape Library", app: app)
        select("Search", in: app, regular: false)
        choose("On this device", picker: "public.searchSource", app: app, largeText: true)
        choose("Playlists", picker: "public.searchKind", app: app, largeText: true)
        submit("nothing-saved", app: app)
        XCTAssertTrue(app.descendants(matching: .any)["public.searchEmpty"].waitForExistence(timeout: 5))
        capture("iPad maximum text landscape Search", app: app)
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        capture("iPad maximum text landscape Settings", app: app)
        app.buttons["Close settings"].tap()
    }

    func testIPadWindowResizeEntrypoints() {
        let app = launch(orientation: .portrait)
        capture("iPad before system window resize", app: app)
        // iPadOS 26 exposes the system resize handle at the bottom-right corner.
        // Exercise that handle, and require an actual window size change.
        let original = app.windows.firstMatch.frame
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.995, dy: 0.995))
            .press(forDuration: 0.2, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)))
        capture("iPad after system window resize", app: app)
        let resized = app.windows.firstMatch.frame
        XCTAssertLessThan(resized.width, original.width * 0.8, "System window must really resize; full-screen is not narrow-window coverage")
        guard resized.width < original.width * 0.8 else { return }
        let bounds = XCTAttachment(string: "Before: \(original); after: \(resized)")
        bounds.name = "iPad system window bounds"; bounds.lifetime = .keepAlways; add(bounds)
        select("Library", in: app, regular: false)
        XCTAssertTrue(app.buttons["library.category.Videos"].isHittable)
        capture("iPad narrow window Library", app: app)
        app.buttons["public.start.search"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        capture("iPad narrow window Search", app: app)
        app.staticTexts["public.searchIdle"].tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists, "Dismiss keyboard before using the bottom tab bar")
        select("Home", in: app, regular: false)
        let addControl = app.buttons["public.add"]
        XCTAssertTrue(addControl.waitForExistence(timeout: 5))
        XCTAssertFalse(addControl.frame.isEmpty)
        // Application uses a local origin; window and control frames use screen coordinates.
        let windowFrame = app.windows.firstMatch.frame
        let addFrame = addControl.frame
        let controlBounds = XCTAttachment(string: "Application: \(app.frame); window: \(windowFrame); Add: \(addFrame)")
        controlBounds.name = "iPad narrow window Add bounds"; controlBounds.lifetime = .keepAlways; add(controlBounds)
        XCTAssertTrue(windowFrame.contains(addFrame), "Add must fit inside the visible application window")
        addControl.tap()
        for id in ["public.add.openLink", "public.add.import", "public.add.create"] {
            XCTAssertTrue(app.buttons[id].isHittable)
        }
        app.buttons["public.add.openLink"].tap()
        XCTAssertTrue(app.textFields["public.link"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        capture("iPad narrow window Settings", app: app)
        app.buttons["Close settings"].tap()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        system.buttons["window-controls:com.xiaotwu.muses.erato"].tap()
        system.buttons["Zoom-button"].tap()
        app.activate()
    }

}

// Optional strict diagnostic: excluded from default functional schemes.
@MainActor final class PublicIPadAccessibilityAuditUITests: PublicIPadUITestCase {
    func testIPadRegularAccessibilityAudit() throws {
        let app = launch(orientation: .portrait)
        XCTAssertLessThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height)
        var findings: [String] = []
        for page in ["Home", "Library", "Search", "Settings"] {
            if page == "Settings" { app.buttons["Settings"].firstMatch.tap() }
            else { select(page, in: app) }
            capture("iPad audit " + page, app: app)
            try app.performAccessibilityAudit { issue in
                findings.append(page + ": " + issue.compactDescription + " | " + issue.detailedDescription + " | " + (issue.element?.debugDescription ?? "no element"))
                return true // Collect every issue across every page; the assertion below fails the test for any finding.
            }
        }
        let report = XCTAttachment(string: findings.isEmpty ? "No accessibility audit issues." : findings.joined(separator: "\n\n"))
        report.name = "iPad all accessibility findings"; report.lifetime = .keepAlways; add(report)
        XCTAssertTrue(findings.isEmpty, findings.joined(separator: "\n\n"))
    }

}
