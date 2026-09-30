import XCTest

@MainActor final class PublicNotebookUITests: XCTestCase {
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
    private func detail(_ app: XCUIApplication) {
        app.tabBars.buttons["Library"].tap()
        let list = app.buttons["library.presentation.List"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        list.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library.actions.' AND label CONTAINS %@", "YouTube video dQw4w9WgXcQ")).firstMatch
        reveal(row, in: app)
        row.tap(); app.buttons["Video details"].tap()
        XCTAssertTrue(app.navigationBars["Details"].waitForExistence(timeout: 5))
    }
    private func replace(_ field: XCUIElement, with value: String) {
        let previous = field.value as? String ?? ""
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count) + value)
    }
    private func saveOnce(_ button: XCUIElement) {
        XCTAssertTrue(button.isEnabled)
        button.tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: button)
        waitForExpectations(timeout: 5)
    }
    func testNotebookCRUDRelaunchAndVisibleBookmarkRoute() {
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        app.launchEnvironment["MUSES_UI_TEST_CATALOG"] = "fixtures"
        app.launch()
        let entry = app.buttons["public.add"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10)); entry.tap()
        app.buttons["public.add.openLink"].tap()
        XCTAssertTrue(app.textFields["public.link"].waitForExistence(timeout: 10))
        app.textFields["public.link"].tap()
        app.textFields["public.link"].typeText("dQw4w9WgXcQ")
        app.buttons["public.open"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["public.iframe"].waitForExistence(timeout: 15))
        app.buttons["Close player"].tap()
        addSavedVideosToLocalPlaylist(app, name: "Notebook collection")
        detail(app)
        reveal(app.buttons["notebook.addNote"], in: app)
        app.buttons["notebook.addNote"].tap()
        let text = app.textViews["notebook.noteText"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.tap()
        text.typeText("First thought")
        saveOnce(app.buttons["notebook.saveNote"])
        XCTAssertTrue(app.staticTexts["First thought"].exists)
        let editNote = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'notebook.editNote.'")).firstMatch
        reveal(editNote, in: app)
        editNote.tap()
        replace(text, with: "Edited thought")
        saveOnce(app.buttons["notebook.saveNote"])
        XCTAssertTrue(app.staticTexts["Edited thought"].exists)

        reveal(app.buttons["notebook.addBookmark"], in: app)
        app.buttons["notebook.addBookmark"].tap()
        replace(app.textFields["notebook.bookmarkSeconds"], with: "12.5")
        app.textFields["notebook.bookmarkTitle"].tap()
        app.textFields["notebook.bookmarkTitle"].typeText("First moment")
        app.textFields["notebook.bookmarkNote"].tap()
        app.textFields["notebook.bookmarkNote"].typeText("Keep detail")
        saveOnce(app.buttons["notebook.saveBookmark"])
        let editBookmark = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'notebook.editBookmark.'")).firstMatch
        reveal(editBookmark, in: app)
        editBookmark.tap()
        replace(app.textFields["notebook.bookmarkSeconds"], with: "25.75")
        replace(app.textFields["notebook.bookmarkTitle"], with: "Updated moment")
        saveOnce(app.buttons["notebook.saveBookmark"])
        XCTAssertTrue(app.staticTexts["Keep detail"].exists)
        let openBookmark = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'notebook.openBookmark.'")).firstMatch
        reveal(openBookmark, in: app)
        openBookmark.tap()
        XCTAssertTrue(app.descendants(matching: .any)["public.iframe"].waitForExistence(timeout: 10))
        reveal(app.staticTexts["notebook.bookmarkTarget"], in: app)
        XCTAssertTrue(app.staticTexts["notebook.bookmarkTarget"].label.contains("0:25"))
        XCTAssertNotEqual(app.staticTexts["public.playbackState"].label, "Playing")
        app.buttons["Close player"].tap()
        app.terminate()
        app.launch()
        detail(app)
        reveal(app.staticTexts["Edited thought"], in: app)
        XCTAssertTrue(app.staticTexts["Edited thought"].exists)
        reveal(openBookmark, in: app)
        XCTAssertTrue(openBookmark.label.contains("Updated moment"))
        XCTAssertTrue(openBookmark.label.contains("0:25"))
        let deleteNote = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'notebook.deleteNote.'")).firstMatch
        let noteActions = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'notebook.noteActions.'")).firstMatch
        // The note precedes bookmarks; scroll to its visible overflow control first.
        for _ in 0..<5 { if noteActions.isHittable { break }; app.swipeDown() }
        XCTAssertTrue(noteActions.isHittable); noteActions.tap()
        XCTAssertTrue(deleteNote.waitForExistence(timeout: 5)); deleteNote.tap()
        app.alerts.buttons["Delete note"].tap()
        XCTAssertTrue(app.staticTexts["No notes yet."].waitForExistence(timeout: 5))
        let deleteBookmark = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'notebook.deleteBookmark.'")).firstMatch
        let bookmarkActions = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'notebook.bookmarkActions.'")).firstMatch
        reveal(bookmarkActions, in: app); bookmarkActions.tap()
        XCTAssertTrue(deleteBookmark.waitForExistence(timeout: 5)); deleteBookmark.tap()
        app.alerts.buttons["Delete bookmark"].tap()
        XCTAssertTrue(app.staticTexts["No bookmarks yet."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["notebook.clearBookmarks"].isEnabled)
        for _ in 0..<5 { if app.buttons["notebook.addNote"].isHittable { break }; app.swipeDown() }
        XCTAssertFalse(app.buttons["notebook.clearNotes"].isEnabled)
        app.buttons["notebook.addNote"].tap()
        text.tap(); text.typeText("Clear me")
        saveOnce(app.buttons["notebook.saveNote"])
        reveal(app.buttons["notebook.addBookmark"], in: app)
        app.buttons["notebook.addBookmark"].tap()
        saveOnce(app.buttons["notebook.saveBookmark"])
        let clearNotes = app.buttons["notebook.clearNotes"]
        for _ in 0..<5 { if clearNotes.isHittable { break }; app.swipeDown() }
        clearNotes.tap()
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Clear me"].exists)
        clearNotes.tap()
        app.alerts.buttons["Clear notes"].tap()
        expectation(for: NSPredicate(format: "enabled == false"), evaluatedWith: clearNotes)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(openBookmark.exists, "Clearing notes keeps bookmarks")
        reveal(app.buttons["notebook.clearBookmarks"], in: app)
        app.buttons["notebook.clearBookmarks"].tap()
        app.alerts.buttons["Clear bookmarks"].tap()
        expectation(for: NSPredicate(format: "enabled == false"), evaluatedWith: app.buttons["notebook.clearBookmarks"])
        waitForExpectations(timeout: 5)
        app.terminate()
        app.launch()
        detail(app)
        reveal(app.buttons["notebook.clearNotes"], in: app)
        XCTAssertFalse(app.buttons["notebook.clearNotes"].isEnabled)
        reveal(app.buttons["notebook.clearBookmarks"], in: app)
        XCTAssertFalse(app.buttons["notebook.clearBookmarks"].isEnabled)

    }
}
