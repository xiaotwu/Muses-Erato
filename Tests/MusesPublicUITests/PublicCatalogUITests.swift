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
        let entry = app.buttons["public.add"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5)); entry.tap()
        app.buttons["public.add.openLink"].tap()
        let link = app.textFields["public.link"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap(); link.typeText("MFKabcdefgh")
        app.buttons["public.open"].tap()
        XCTAssertTrue(app.staticTexts["Failed"].waitForExistence(timeout: 8))
        let notices = app.staticTexts.matching(identifier: "Made for Kids videos are not supported by this embedded player. Open this video in YouTube.")
        XCTAssertTrue(notices.firstMatch.waitForExistence(timeout: 5))
        // Playback failure is shown only in its player recovery surface.
        XCTAssertTrue(notices.allElementsBoundByIndex.contains { $0.isHittable })
        XCTAssertFalse(app.buttons["Play"].isEnabled)
        XCTAssertTrue(app.buttons["Close player"].isEnabled)
        let external = app.buttons["public.openYouTube"]
        XCTAssertTrue(external.waitForExistence(timeout: 5))
        XCTAssertTrue(external.isEnabled)
        XCTAssertTrue(app.buttons["public.retryPlayback"].exists)
        app.buttons["Close player"].tap()
        XCTAssertTrue(app.buttons["public.add"].waitForExistence(timeout: 5))
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
        let failedPage = XCTAttachment(screenshot: app.screenshot())
        failedPage.name = "Search retained results and retry"; failedPage.lifetime = .keepAlways; add(failedPage)
        app.buttons["Retry"].tap()
        XCTAssertTrue(app.staticTexts["Fixture second video"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Load next page"].exists)
    }
    func testSearchTypeChangeWaitsForSubmitAndClearReturnsToIdle() {
        let app = launch(); app.tabBars.buttons["Search"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["public.searchIdle"].exists)
        let field = app.textFields["public.search"]
        field.tap(); field.typeText("fixture\n")
        XCTAssertTrue(app.staticTexts["Fixture first video"].waitForExistence(timeout: 5))
        selectSearchFilter("Playlists", group: "Type", in: app)
        XCTAssertTrue(app.staticTexts["Fixture first video"].exists, "Type selection does not replace results or make a request")
        XCTAssertTrue(app.staticTexts["Search filters changed. Submit to update results."].exists)
        app.buttons["public.clearSearch"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["public.searchIdle"].exists)
        XCTAssertFalse(app.staticTexts["Fixture first video"].exists)
        XCTAssertFalse(app.buttons["Load next page"].exists)
    }

    func testSearchVideosEntrySelectsVideoAndFocusesWithoutSubmitting() {
        let app = launch(); app.tabBars.buttons["Search"].tap()
        selectSearchFilter("Channels", group: "Type", in: app)
        app.tabBars.buttons["Library"].tap()
        let entry = app.buttons["public.start.search"]
        reveal(entry, in: app); entry.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue((app.buttons["public.searchFilters"].value as? String)?.contains("Videos") == true)
        XCTAssertTrue(app.descendants(matching: .any)["public.searchIdle"].exists)
        XCTAssertFalse(app.staticTexts["Fixture first video"].exists)
    }

    func testPlaylistAndChannelLinkBrowsing() {
        let app = launch()
        let entry = app.buttons["public.add"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5)); entry.tap()
        app.buttons["public.add.openLink"].tap()
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
        let playlist = app.cells.containing(.staticText, identifier: "Fixture public playlist").firstMatch
        XCTAssertTrue(playlist.waitForExistence(timeout: 5)); playlist.tap()
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
        app.buttons["settings.account"].tap()
        XCTAssertEqual(app.staticTexts["account.nickname"].firstMatch.label, "Fixture channel")
        XCTAssertTrue(app.staticTexts["Read-only YouTube access"].exists)
        app.buttons["Channel details"].tap()
        let channelID = app.staticTexts["account.channelID"]
        XCTAssertEqual(channelID.label, "UCabcdefghijklmnopqrstuv")
        XCTAssertTrue(app.buttons["Copy Channel ID"].isEnabled)
        app.buttons["Channel details"].tap()
        XCTAssertTrue(app.staticTexts["Fixture public playlist"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Fixture playlist 2"].exists)
        let more = app.buttons["account.load.subscriptions"]
        reveal(more, in: app); more.tap()
        XCTAssertTrue(app.staticTexts["Fixture subscription 2"].waitForExistence(timeout: 5))
    }
}


extension PublicCatalogUITests {
    func testSimplifiedHomeAndSearchHierarchy() { checkSimplifiedHierarchy(largeText: false) }
    func testSimplifiedHomeAndSearchHierarchyAtMaximumText() { checkSimplifiedHierarchy(largeText: true) }
    func testSimplifiedEmptyHome() { checkEmptyHome(largeText: false) }
    func testSimplifiedEmptyHomeAtMaximumText() { checkEmptyHome(largeText: true) }

    private func checkEmptyHome(largeText: Bool) {
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        app.launchEnvironment["MUSES_UI_TEST_CATALOG"] = "none"
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.staticTexts["Start your library"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["YouTube Playlists"].exists, "An unsigned account does not add an empty promotional shelf")
        let addControl = app.buttons["public.add"]
        XCTAssertTrue(addControl.waitForExistence(timeout: 5))
        XCTAssertFalse(addControl.frame.isEmpty)
        XCTAssertTrue(app.frame.intersects(addControl.frame))
        addControl.tap()
        for id in ["public.add.openLink", "public.add.import", "public.add.create"] {
            XCTAssertTrue(app.buttons[id].isHittable)
        }
        app.buttons["public.add.openLink"].tap()
        XCTAssertTrue(app.textFields["public.link"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        for id in ["public.start.search", "public.start.link", "public.start.import"] {
            let action = app.buttons[id]
            reveal(action, in: app)
            XCTAssertGreaterThanOrEqual(action.frame.height, 44)
        }
        Thread.sleep(forTimeInterval: 0.4)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = largeText ? "Redesign maximum text Home empty" : "Redesign ordinary Home empty"
        shot.lifetime = .keepAlways; add(shot)
        app.buttons["public.start.search"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["public.searchIdle"].exists)
    }

    private func checkSimplifiedHierarchy(largeText: Bool) {
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        app.launchEnvironment["MUSES_UI_TEST_CATALOG"] = "fixtures"
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.staticTexts["Fixture public playlist"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["public.add"].label.contains("Add"))
        XCTAssertFalse(app.buttons["public.queue"].exists)
        XCTAssertFalse(app.buttons["public.start.search"].exists, "Populated Home prioritizes content, with adding centralized in the toolbar")
        func capture(_ name: String) {
            Thread.sleep(forTimeInterval: 0.4)
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = "Redesign " + (largeText ? "maximum text " : "ordinary ") + name
            shot.lifetime = .keepAlways; add(shot)
        }
        capture("Home populated")
        app.buttons["public.add"].tap()
        XCTAssertTrue(app.buttons["public.add.openLink"].isHittable)
        XCTAssertTrue(app.buttons["public.add.import"].isHittable)
        XCTAssertTrue(app.buttons["public.add.create"].isHittable)
        capture("Home Add menu")
        app.buttons["public.add.import"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["playlistImport.title"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        app.tabBars.buttons["Search"].tap()
        XCTAssertTrue(app.buttons["public.searchFilters"].exists)
        XCTAssertFalse(app.buttons["public.searchSource"].exists)
        XCTAssertFalse(app.buttons["public.searchKind"].exists)
        XCTAssertEqual(app.segmentedControls.count, 0)
        XCTAssertEqual(app.buttons["public.submitSearch"].label, "Search")
        if largeText { XCTAssertGreaterThan(app.textFields["public.search"].frame.width, app.frame.width * 0.6) }
        capture("Search idle")
        selectSearchFilter("On this device", group: "Source", in: app)
        app.buttons["public.searchFilters"].tap()
        XCTAssertFalse(app.buttons["Channels"].exists)
        app.buttons["Playlists"].tap()
        closeSearchFilters(in: app)
        let field = app.textFields["public.search"]
        field.tap(); field.typeText("no-saved-playlist\n")
        XCTAssertTrue(app.descendants(matching: .any)["public.searchEmpty"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["public.searchResultsHeading"].label.contains("On this device"))
        capture("Search saved empty")
    }

    func testHomeRecentAndYouTubeNicknameAndInlineAccountCollections() { checkHomeAndAccount(largeText: false) }
    func testLargeTextHomeAndAccountRemainUsable() { checkHomeAndAccount(largeText: true) }
    private func checkHomeAndAccount(largeText: Bool) {
        let app = launch()
        if largeText {
            app.terminate()
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            app.launch()
        }
        XCTAssertTrue(app.staticTexts["YouTube Playlists"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Recently Played"].exists, "Empty recent history is omitted")
        XCTAssertFalse(app.staticTexts["Public recommendations"].exists)
        XCTAssertFalse(app.staticTexts["Your recommendations"].exists)
        XCTAssertFalse(app.buttons["home.music.video:abcdefghijk"].exists)
        XCTAssertFalse(app.links["home.youtubeMusic"].exists || app.buttons["home.youtubeMusic"].exists)
        XCTAssertTrue(app.staticTexts["YouTube Playlists"].exists)
        let homeImage = XCTAttachment(screenshot: app.screenshot())
        homeImage.name = largeText ? "Home large text" : "Home recent listening and YouTube playlists"; homeImage.lifetime = .keepAlways; add(homeImage)
        app.buttons["Settings"].firstMatch.tap()
        let nickname = app.staticTexts["account.nickname"].firstMatch
        XCTAssertTrue(nickname.waitForExistence(timeout: 5))
        XCTAssertEqual(nickname.label, "Fixture channel")
        let settingsImage = XCTAttachment(screenshot: app.screenshot())
        settingsImage.name = "Settings profile and grouped directory"; settingsImage.lifetime = .keepAlways; add(settingsImage)
        app.buttons["settings.account"].tap()
        XCTAssertFalse(app.buttons["Account & YouTube collections"].exists)
        XCTAssertFalse(app.staticTexts["account.channelID"].exists, "Technical identity stays collapsed")
        let playlist = app.staticTexts["Fixture public playlist"].firstMatch
        XCTAssertTrue(playlist.waitForExistence(timeout: 5))
        reveal(playlist, in: app)
        XCTAssertTrue(playlist.isHittable)
        XCTAssertTrue(app.staticTexts["Fixture playlist 2"].exists, "All account playlists load automatically")
        let accountImage = XCTAttachment(screenshot: app.screenshot())
        accountImage.name = "Account nickname with inline playlists"; accountImage.lifetime = .keepAlways; add(accountImage)
    }
}

extension XCTestCase {
    @MainActor func closeSearchFilters(in app: XCUIApplication) {
        // Tap the blank content inset, outside the anchored system menu.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)).tap()
        // System menu actions can expose their labels without SwiftUI identifiers.
        XCTAssertTrue(app.buttons["On this device"].waitForNonExistence(timeout: 3))
        let filters = app.buttons["public.searchFilters"]
        XCTAssertTrue(filters.exists, "Closing the menu restores the presenting toolbar to accessibility")
        XCTAssertTrue(filters.isHittable)
    }
    @MainActor func selectSearchFilter(_ choice: String, group: String, in app: XCUIApplication) {
        let current = app.buttons["public.searchFilters"].value as? String ?? ""
        let options = group == "Source" ? ["YouTube", "On this device"] : ["Videos", "Playlists", "Channels"]
        app.buttons["public.searchFilters"].tap()
        if !current.contains(choice) { app.buttons[choice].tap() }
        for other in options where other != choice && current.contains(other) { app.buttons[other].tap() }
        closeSearchFilters(in: app)
    }
}

extension PublicCatalogUITests {
    func testMultiselectSearchQueriesSourcesAndKinds() { checkMultiselectSearch(largeText: false) }
    func testMultiselectSearchQueriesSourcesAndKindsAtMaximumText() { checkMultiselectSearch(largeText: true) }

    private func checkMultiselectSearch(largeText: Bool) {
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        app.launchEnvironment["MUSES_UI_TEST_CATALOG"] = "fixtures"
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.buttons["public.add"].waitForExistence(timeout: 10))
        app.buttons["public.add"].tap(); app.buttons["public.add.create"].tap()
        app.alerts.textFields.firstMatch.typeText("Fixture local playlist")
        app.alerts.buttons["Create"].tap()
        app.tabBars.buttons["Search"].tap()
        let filters = app.buttons["public.searchFilters"]
        let settings = app.buttons["Settings"].firstMatch
        XCTAssertLessThan(filters.frame.midX, settings.frame.midX, "Filters precede Settings in the trailing toolbar")
        filters.tap()
        XCTAssertFalse(app.buttons["YouTube"].isEnabled, "The last selected source cannot be cleared")
        XCTAssertFalse(app.buttons["Videos"].isEnabled, "The last selected type cannot be cleared")
        for choice in ["On this device", "Playlists", "Channels"] {
            app.buttons[choice].tap()
            XCTAssertTrue(app.buttons[choice].isHittable, "Keep menu open for consecutive selections")
        }
        closeSearchFilters(in: app)
        let selected = filters.value as? String ?? ""
        for choice in ["YouTube", "On this device", "Videos", "Playlists", "Channels"] { XCTAssertTrue(selected.contains(choice)) }
        let field = app.textFields["public.search"]
        field.tap(); field.typeText("fixture")
        let submit = app.buttons["public.submitSearch"]
        XCTAssertEqual(submit.label, "Search")
        XCTAssertGreaterThanOrEqual(submit.frame.height, 44)
        XCTAssertGreaterThanOrEqual(submit.frame.width, 44)
        submit.tap()
        let heading = app.staticTexts["public.searchResultsHeading"]
        let count = NSPredicate(format: "label CONTAINS '4 results'")
        expectation(for: count, evaluatedWith: heading); waitForExpectations(timeout: 10)
        let originalHeading = heading.label
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = largeText ? "Multiselect maximum text Search results" : "Multiselect ordinary Search results"
        screenshot.lifetime = .keepAlways; add(screenshot)
        for title in ["Fixture local playlist", "Fixture first video", "Fixture public playlist", "Fixture channel"] {
            reveal(app.staticTexts[title].firstMatch, in: app)
            XCTAssertTrue(app.staticTexts[title].firstMatch.exists)
        }
        filters.tap(); app.buttons["YouTube"].tap()
        XCTAssertTrue(app.buttons["On this device"].isHittable, "The source menu remains open while Channels is removed")
        XCTAssertFalse(app.buttons["Channels"].exists)
        XCTAssertFalse(app.buttons["On this device"].isEnabled)
        app.buttons["Videos"].tap()
        XCTAssertFalse(app.buttons["Playlists"].isEnabled)
        closeSearchFilters(in: app)
        // The system menu can hide its presenting toolbar from accessibility.
        XCTAssertFalse((filters.value as? String ?? "").contains("Channels"))
        XCTAssertEqual(heading.label, originalHeading, "Draft changes retain every submitted source and kind")
    }
}
