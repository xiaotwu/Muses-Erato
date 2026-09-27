import XCTest

final class PublicSmokeTests: XCTestCase {
    func testNewInstallNavigationAndVisiblePlayerRoute() {
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.textFields["public.link"].waitForExistence(timeout: 10))
        app.textFields["public.link"].tap()
        app.textFields["public.link"].typeText("dQw4w9WgXcQ")
        app.buttons["public.open"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["public.iframe"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["public.playbackState"].exists)
        app.buttons["Close"].tap()
        if app.tabBars.buttons["Library"].exists { app.tabBars.buttons["Library"].tap() }
        else { app.buttons["Library"].firstMatch.tap() }
        XCTAssertTrue(app.staticTexts["public.libraryHeader"].waitForExistence(timeout: 5))
    }
}

@MainActor final class PublicLocalLibraryUITests: XCTestCase {
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
    private func openVideo(_ id: String, app: XCUIApplication) {
        app.launch()
        XCTAssertTrue(app.textFields["public.link"].waitForExistence(timeout: 10))
        app.textFields["public.link"].tap()
        app.textFields["public.link"].typeText(id)
        app.buttons["public.open"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["public.iframe"].waitForExistence(timeout: 15))
    }
    private func playlists(_ app: XCUIApplication) {
        app.tabBars.buttons["Library"].tap()
        let category = app.buttons["library.category.Playlists"]
        reveal(category, in: app)
        category.tap()
        reveal(app.buttons["public.createPlaylist"], in: app)
    }
    func testEmptyLibraryAndPlaylistCreation() {
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.textFields["public.link"].waitForExistence(timeout: 10))
        if app.tabBars.buttons["Library"].exists { app.tabBars.buttons["Library"].tap() }
        else { app.buttons["Library"].firstMatch.tap() }
        let category = app.buttons["library.category.Playlists"]
        reveal(category, in: app)
        category.tap()
        reveal(app.buttons["public.createPlaylist"], in: app)
        app.buttons["public.createPlaylist"].tap()
        app.alerts.textFields.firstMatch.typeText("Empty playlist")
        app.alerts.buttons["Create"].tap()
        let playlist = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Empty playlist")).firstMatch
        reveal(playlist, in: app)
        playlist.tap()
        XCTAssertTrue(app.staticTexts["This playlist is empty. Add videos from your saved collection."].exists)
        XCTAssertFalse(app.buttons["Add playlist to queue"].isEnabled)
        app.buttons["Add videos"].tap()
        XCTAssertTrue(app.staticTexts["No saved videos. Open a YouTube link on Home first."].exists)
    }
    func testLocalPlaylistFavoriteQueueEditingAndRelaunch() {
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        openVideo("dQw4w9WgXcQ", app: app)
        app.buttons["Favorite"].tap()
        XCTAssertTrue(app.buttons["Remove favorite"].exists)
        app.buttons["Close"].tap()
        app.terminate()
        openVideo("M7lc1UVf-VE", app: app)
        app.buttons["Close"].tap()
        playlists(app)
        XCTAssertTrue(app.staticTexts["No local playlists"].exists)
        app.buttons["public.createPlaylist"].tap()
        app.alerts.textFields.firstMatch.typeText("Evening")
        app.alerts.buttons["Create"].tap()
        let evening = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Evening")).firstMatch
        reveal(evening, in: app)
        evening.tap()
        app.buttons["Add videos"].tap()
        app.buttons["YouTube video dQw4w9WgXcQ"].tap()
        app.buttons["YouTube video M7lc1UVf-VE"].tap()
        XCTAssertFalse(app.buttons["YouTube video dQw4w9WgXcQ"].isEnabled)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["2 videos · On this device"].exists)
        app.buttons["Edit"].tap()
        let handles = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reorder'"))
        XCTAssertEqual(handles.count, 2)
        if handles.count == 2 { handles.element(boundBy: 1).press(forDuration: 0.5, thenDragTo: handles.element(boundBy: 0)) }
        app.buttons["Done"].tap()
        app.buttons["Rename playlist"].tap()
        let field = app.alerts.textFields.firstMatch
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7) + "Night")
        app.alerts.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Night"].exists)
        app.buttons["Add playlist to queue"].tap()
        app.terminate()
        app.launch()
        playlists(app)
        let night = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Night")).firstMatch
        reveal(night, in: app)
        night.tap()
        XCTAssertTrue(app.staticTexts["2 videos · On this device"].exists)
        let firstRow = app.cells.containing(.staticText, identifier: "YouTube video M7lc1UVf-VE").firstMatch
        let secondRow = app.cells.containing(.staticText, identifier: "YouTube video dQw4w9WgXcQ").firstMatch
        XCTAssertLessThan(firstRow.frame.minY, secondRow.frame.minY, "Reordered playlist survives relaunch")
        // Swipe deletion is the same intent as Edit mode's delete control.
        let videoRow = app.cells.containing(.staticText, identifier: "YouTube video M7lc1UVf-VE").firstMatch
        videoRow.swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["1 videos · On this device"].exists)
        app.buttons["Delete playlist"].tap()
        app.sheets.buttons["Delete playlist"].tap()
        XCTAssertTrue(app.staticTexts["No local playlists"].waitForExistence(timeout: 5))
        app.buttons["public.queue"].tap()
        XCTAssertTrue(app.navigationBars["Queue"].exists)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'queue.entry.'")).count, 2)
        app.buttons["Edit"].tap()
        let queueHandles = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reorder'"))
        XCTAssertEqual(queueHandles.count, 2)
        if queueHandles.count == 2 { queueHandles.element(boundBy: 1).press(forDuration: 0.5, thenDragTo: queueHandles.element(boundBy: 0)) }
        app.buttons["Done"].tap()
        let queuedRows = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'queue.entry.'"))
        XCTAssertEqual(queuedRows.element(boundBy: 0).label, "YouTube video dQw4w9WgXcQ")
        queuedRows.element(boundBy: 0).swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertEqual(queuedRows.count, 1)
        app.buttons["Clear upcoming queue"].tap()
        app.sheets.buttons["Clear upcoming queue"].tap()
        XCTAssertTrue(app.staticTexts["The queue is empty. Add videos from video details or a local playlist."].exists)
        app.terminate()
        app.launch()
        app.tabBars.buttons["Library"].tap()
        app.buttons["library.category.Favorites"].tap()
        let saved = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "YouTube video dQw4w9WgXcQ")).firstMatch
        reveal(saved, in: app)
        saved.tap()
        XCTAssertTrue(app.buttons["Remove favorite"].exists)
        app.buttons["Remove favorite"].tap()
        XCTAssertTrue(app.buttons["Favorite"].exists)
    }
}
