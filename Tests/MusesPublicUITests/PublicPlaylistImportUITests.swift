import XCTest

@MainActor final class PublicPlaylistImportUITests: XCTestCase {
    func testAccountAndMusicLinkAutomaticallyLoadAllPagesAndKeepOriginalName() { runImportAndLibrary(largeText: false) }
    func testLargeTextImportAndLibraryDeckRemainUsable() { runImportAndLibrary(largeText: true) }
    private func runImportAndLibrary(largeText: Bool) {
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        app.launchEnvironment["MUSES_UI_TEST_CATALOG"] = "fixtures"
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        let library = app.buttons["Library"].firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: 10)); library.tap()
        let rail = app.scrollViews["library.categories"]
        let playlists = app.buttons["library.category.Playlists"]
        for _ in 0..<6 {
            if playlists.isHittable { break }
            rail.swipeLeft(velocity: .slow)
        }
        playlists.tap()
        let add = app.buttons["library.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5)); add.tap()
        let entry = app.buttons["library.importPlaylist"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        XCTAssertTrue(entry.label.contains("Import"))
        entry.tap()
        let importTitle = app.descendants(matching: .any)["playlistImport.title"]
        XCTAssertTrue(importTitle.waitForExistence(timeout: 5))
        XCTAssertEqual(importTitle.frame.midX, app.frame.midX, accuracy: 2, "Import title must remain centered independently of the Cancel control")
        XCTAssertFalse(app.buttons["playlistImport.accountLoad"].exists)
        XCTAssertTrue(app.buttons["playlistImport.account.PLsecond"].waitForExistence(timeout: 5))
        let owned = app.buttons["playlistImport.account.PLfixture"]
        XCTAssertTrue(owned.waitForExistence(timeout: 5)); owned.tap()
        XCTAssertTrue(app.buttons["playlistImport.save"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["playlistImport.save"].isEnabled)
        XCTAssertEqual(app.textFields["playlistImport.name"].value as? String, "Fixture public playlist")
        app.buttons["playlistImport.chooseAnother"].tap()
        let sources = app.segmentedControls["playlistImport.source"]
        XCTAssertTrue(sources.waitForExistence(timeout: 5))
        sources.buttons["Playlist link"].tap()
        let link = app.textFields["playlistImport.link"]
        reveal(link, app: app)
        link.tap(); link.typeText("https://music.youtube.com/playlist?list=PLfixture")
        app.buttons["playlistImport.readLink"].tap()
        if app.buttons["playlistImport.readLink"].exists { app.buttons["playlistImport.readLink"].tap() }
        let save = app.buttons["playlistImport.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5)); XCTAssertTrue(save.isEnabled)
        XCTAssertFalse(app.buttons["playlistImport.loadPage"].exists)
        XCTAssertFalse(app.buttons["playlistImport.loadAll"].exists)
        XCTAssertEqual(app.textFields["playlistImport.name"].value as? String, "Fixture public playlist")
        save.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'playlist.open.' AND label CONTAINS 'Fixture public playlist'")).firstMatch.waitForExistence(timeout: 5))
        capture("Library playlist blocks", app)
        let songs = app.buttons["library.category.Songs"]
        for _ in 0..<8 where !songs.isHittable { rail.swipeRight(velocity: .slow) }
        songs.tap()
        XCTAssertTrue(app.staticTexts["collection.position"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["collection.position"].label, "1 / 2")
        capture("Library Songs cards", app)
        let focused = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'library.play.'")).firstMatch
        reveal(focused, app: app)
        focused.swipeLeft()
        XCTAssertFalse(app.descendants(matching: .any)["public.iframe"].exists, "Browsing cards must not open playback")
        XCTAssertEqual(app.staticTexts["collection.position"].label, "2 / 2")
        let list = app.buttons["library.presentation.List"]
        for _ in 0..<6 where !list.isHittable { app.swipeDown() }
        list.tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library.detail.'")).count, 2)
        capture("Library Songs list", app)
        app.terminate(); app.launch()
        app.buttons["Library"].firstMatch.tap()
        for _ in 0..<6 {
            if playlists.isHittable { break }
            rail.swipeLeft(velocity: .slow)
        }
        playlists.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'playlist.open.' AND label CONTAINS 'Fixture public playlist'")).firstMatch.waitForExistence(timeout: 5))
    }
    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

}
