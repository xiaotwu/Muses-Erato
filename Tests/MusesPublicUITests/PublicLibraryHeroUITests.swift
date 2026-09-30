import XCTest

@MainActor final class PublicLibraryHeroUITests: XCTestCase {
    private func app(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        app.launchEnvironment["MUSES_UI_TEST_CATALOG"] = "fixtures"
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        return app
    }
    private func library(_ app: XCUIApplication) {
        if app.tabBars.buttons["Library"].exists { app.tabBars.buttons["Library"].tap() }
        else {
            if !app.buttons["Library"].firstMatch.isHittable {
                let sidebar = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sidebar'")).firstMatch
                if sidebar.exists { sidebar.tap() }
            }
            app.buttons["Library"].firstMatch.tap()
        }
    }
    private func category(_ name: String, app: XCUIApplication) {
        let button = app.buttons["library.category.\(name)"]
        for _ in 0..<6 where !button.isHittable { app.swipeDown() }
        XCTAssertTrue(button.isHittable)
        button.tap()
        XCTAssertTrue(button.isSelected)
    }
    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<6 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
    private func cancelConfirmation(_ app: XCUIApplication) {
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
        else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.12)).tap() }
    }
    private func saveVideo(_ app: XCUIApplication) {
        let entry = app.buttons["public.openLinkEntry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5)); entry.tap()
        reveal(app.textFields["public.link"], app: app)
        app.textFields["public.link"].tap()
        app.textFields["public.link"].typeText("dQw4w9WgXcQ")
        reveal(app.buttons["public.open"], app: app)
        app.buttons["public.open"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["public.iframe"].waitForExistence(timeout: 10))
        app.buttons["Close player"].tap()

    }
    private func importSongs(_ app: XCUIApplication) {
        category("Playlists", app: app)
        let add = app.buttons["library.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5)); add.tap()
        app.buttons["library.importPlaylist"].tap()
        let owned = app.buttons["playlistImport.account.PLfixture"]
        XCTAssertTrue(owned.waitForExistence(timeout: 10)); owned.tap()
        let save = app.buttons["playlistImport.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isEnabled); save.tap()
        if app.alerts.buttons["Import playlist"].waitForExistence(timeout: 2) { app.alerts.buttons["Import playlist"].tap() }
        category("Videos", app: app)
    }
    func testFourCategoriesAndEmptyControlsHidden() {
        let app = app(); library(app)
        XCTAssertFalse(app.buttons["library.category.Artists"].exists)
        XCTAssertFalse(app.buttons["library.category.Albums"].exists)
        XCTAssertFalse(app.buttons["library.category.Songs"].exists)
        XCTAssertFalse(app.buttons["library.category.Podcasts"].exists)
        XCTAssertFalse(app.buttons["library.presentation.Cards"].exists)
        XCTAssertTrue(app.buttons["public.start.search"].isHittable)
        category("History", app: app)
        XCTAssertFalse(app.buttons["library.collectionActions"].exists)
        category("Videos", app: app)
        XCTAssertFalse(app.buttons["library.collectionActions"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["public.iframe"].exists)
    }
    func testHeroOpensVisiblePlayerAndDeletionSurvivesRestart() {
        let app = app(); saveVideo(app); library(app)
        app.buttons["library.presentation.Cards"].tap()
        let play = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'library.play.'")).firstMatch
        reveal(play, app: app)
        XCTAssertFalse(app.descendants(matching: .any)["public.iframe"].exists)
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "Library hero"; image.lifetime = .keepAlways; add(image)
        play.tap()
        XCTAssertTrue(app.descendants(matching: .any)["public.iframe"].waitForExistence(timeout: 10))
        app.buttons["Close player"].tap()
        let actions = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library.actions.'")).firstMatch
        reveal(actions, app: app); actions.tap()
        app.buttons["Delete saved video"].tap()
        cancelConfirmation(app)
        XCTAssertTrue(actions.exists)
        actions.tap(); app.buttons["Delete saved video"].tap()
        app.buttons["Delete saved video"].tap()
        XCTAssertTrue(app.staticTexts["No saved videos"].waitForExistence(timeout: 5))
        app.terminate(); app.launch(); library(app)
        XCTAssertTrue(app.staticTexts["No saved videos"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["library.collectionActions"].exists)
    }
    func testLargeTextHeroAndCategoriesRemainReachable() {
        let app = app(largeText: true); library(app); importSongs(app)
        let play = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'library.play.'")).firstMatch
        reveal(play, app: app)
        XCTAssertFalse(app.descendants(matching: .any)["public.iframe"].exists)
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "Library hero accessibility text"; image.lifetime = .keepAlways; add(image)
        XCTAssertTrue(play.isHittable)
    }
    func testBulkClearRequiresConfirmation() {
        let app = app(); saveVideo(app); library(app)
        app.buttons["library.collectionActions"].tap(); app.buttons["library.clear.Videos"].tap()
        cancelConfirmation(app)
        XCTAssertTrue(app.buttons["library.collectionActions"].exists)
        app.buttons["library.collectionActions"].tap(); app.buttons["library.clear.Videos"].tap()
        app.buttons["Clear local items"].tap()
        XCTAssertTrue(app.staticTexts["No saved videos"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["library.collectionActions"].exists)
    }
    func testIndependentFavoriteAndPresentationPreferenceSurviveRelaunch() {
        let app = app(); saveVideo(app); library(app)
        app.buttons["library.presentation.List"].tap()
        let actions = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library.actions.'")).firstMatch
        reveal(actions, app: app); actions.tap(); app.buttons["Favorite"].tap()
        category("Favorites", app: app)
        XCTAssertTrue(actions.waitForExistence(timeout: 5))
        app.buttons["library.presentation.Cards"].tap()
        app.terminate(); app.launch(); library(app)
        XCTAssertTrue(app.buttons["library.presentation.Cards"].isSelected)
        category("Favorites", app: app)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'library.play.'")).firstMatch.waitForExistence(timeout: 5))
        let filter = app.textFields["library.filter"]
        filter.tap(); filter.typeText("zzzz-no-match")
        XCTAssertTrue(app.staticTexts["No matching saved items"].waitForExistence(timeout: 5))
        app.buttons["Clear filter"].tap()
        XCTAssertTrue(actions.exists)
        category("Playlists", app: app)
        XCTAssertTrue(app.staticTexts["No local playlists"].exists, "Favorite is independent of playlist membership")
    }

}
