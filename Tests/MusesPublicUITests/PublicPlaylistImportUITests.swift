import XCTest

@MainActor final class PublicPlaylistImportUITests: XCTestCase {
    func testAccountAndMusicLinkAutomaticallyLoadAllPagesAndKeepOriginalName() {
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        app.launchEnvironment["MUSES_UI_TEST_CATALOG"] = "fixtures"
        app.launch()
        let library = app.buttons["Library"].firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: 10)); library.tap()
        let rail = app.scrollViews["library.categories"]
        let playlists = app.buttons["library.category.Playlists"]
        for _ in 0..<6 {
            if playlists.isHittable && playlists.frame.maxX <= rail.frame.maxX { break }
            rail.swipeLeft(velocity: .slow)
        }
        playlists.tap()
        let entry = app.buttons["library.importPlaylist"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(entry.frame.width, 44)
        XCTAssertGreaterThanOrEqual(entry.frame.height, 44)
        XCTAssertEqual(entry.label, "Import YouTube Music or account playlist")
        entry.tap()
        XCTAssertTrue(app.buttons["playlistImport.accountLoad"].exists)
        app.buttons["playlistImport.accountLoad"].tap()
        let owned = app.buttons["playlistImport.account.PLfixture"]
        XCTAssertTrue(owned.waitForExistence(timeout: 5)); owned.tap()
        XCTAssertTrue(app.buttons["playlistImport.save"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["playlistImport.save"].isEnabled)
        XCTAssertEqual(app.textFields["playlistImport.name"].value as? String, "Fixture public playlist")
        app.buttons["Choose another playlist"].tap()
        let link = app.textFields["playlistImport.link"]
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
        app.terminate(); app.launch()
        app.buttons["Library"].firstMatch.tap()
        for _ in 0..<6 {
            if playlists.isHittable && playlists.frame.maxX <= rail.frame.maxX { break }
            rail.swipeLeft(velocity: .slow)
        }
        playlists.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'playlist.open.' AND label CONTAINS 'Fixture public playlist'")).firstMatch.waitForExistence(timeout: 5))
    }
}
