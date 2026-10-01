import XCTest

final class PublicPrivacyUITests: XCTestCase {
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func newApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        app.launchEnvironment["MUSES_UI_TEST_PRIVACY"] = "required"
        app.launchEnvironment["MUSES_UI_TEST_CATALOG"] = "fixtures"
        return app
    }

    func testAgreementGatesFeaturesAndPersistsForSamePolicy() {
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        app.launchEnvironment["MUSES_UI_TEST_PRIVACY"] = "required"
        app.launch()
        let proceed = app.buttons["privacy.continue"]
        XCTAssertTrue(proceed.waitForExistence(timeout: 10))
        XCTAssertFalse(proceed.isEnabled)
        XCTAssertTrue(app.buttons["privacy.notNow"].isHittable, "Refusal must be reachable on the first screen")
        capture("First launch", app: app)
        XCTAssertFalse(app.buttons["public.add"].exists)
        reveal(app.buttons["privacy.agreement"], in: app)
        app.buttons["privacy.agreement"].tap()
        XCTAssertTrue(proceed.isEnabled)
        reveal(proceed, in: app)
        proceed.tap()
        XCTAssertTrue(app.buttons["public.add"].waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["public.add"].waitForExistence(timeout: 10))
        XCTAssertFalse(proceed.exists)
    }
    func testPolicyRoundTripAndRefusalNeverAccept() {
        let app = newApp()
        app.launch()
        let readPolicy = app.buttons["privacy.readPolicy"]
        XCTAssertTrue(readPolicy.waitForExistence(timeout: 10))
        reveal(readPolicy, in: app)
        readPolicy.tap()
        XCTAssertTrue(app.navigationBars["Privacy policy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Muses-Erato privacy policy"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        let agreement = app.buttons["privacy.agreement"]
        reveal(agreement, in: app)
        XCTAssertEqual(agreement.value as? String, "Not agreed")
        agreement.tap()
        agreement.tap()
        XCTAssertFalse(app.buttons["privacy.continue"].isEnabled)
        let notNow = app.buttons["privacy.notNow"]
        reveal(notNow, in: app)
        notNow.tap()
        let reopen = app.buttons["privacy.reopen"]
        XCTAssertTrue(reopen.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["public.add"].exists)
        reopen.tap()
        XCTAssertTrue(app.buttons["privacy.continue"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["privacy.continue"].isEnabled)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["privacy.readPolicy"].waitForExistence(timeout: 10))
    }

    func testChangedPolicyRequiresNewAgreement() {
        let app = newApp()
        app.launchEnvironment["MUSES_UI_TEST_ACCEPTED_POLICY"] = "2026-09-28.2"
        app.launch()
        XCTAssertTrue(app.buttons["privacy.readPolicy"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["privacy.continue"].isEnabled)
        XCTAssertFalse(app.buttons["public.add"].exists)
    }

    func testLargestTextCanReachConsentAndExit() {
        let app = newApp()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["privacy.readPolicy"].waitForExistence(timeout: 10))
        capture("First launch accessibility text", app: app)
        let agreement = app.buttons["privacy.agreement"]
        reveal(agreement, in: app)
        agreement.tap()
        let proceed = app.buttons["privacy.continue"]
        reveal(proceed, in: app)
        XCTAssertTrue(proceed.isEnabled)
        let refuse = app.buttons["privacy.notNow"]
        reveal(refuse, in: app)
        capture("Consent accessibility text", app: app)
        refuse.tap()
        XCTAssertTrue(app.buttons["privacy.reopen"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["public.add"].exists)
    }

    func testUnavailablePolicyBlocksSavedConsentAndFixtureBypass() {
        for missing in ["missing", "empty"] {
            let app = newApp()
            app.launchEnvironment["MUSES_UI_TEST_PRIVACY"] = "accepted"
            app.launchEnvironment["MUSES_UI_TEST_ACCEPTED_POLICY"] = "2026-09-29.1"
            app.launchEnvironment["MUSES_UI_TEST_POLICY"] = missing
            app.launch()
            let agreement = app.buttons["privacy.agreement"]
            XCTAssertTrue(agreement.waitForExistence(timeout: 10))
            reveal(agreement, in: app)
            agreement.tap()
            XCTAssertFalse(app.buttons["privacy.continue"].isEnabled)
            XCTAssertTrue(app.staticTexts["Privacy policy unavailable"].exists)
            XCTAssertFalse(app.buttons["public.add"].exists)
            app.terminate()
        }
    }

    func testSettingsVersionAndPolicyAccess() {
        let app = newApp()
        app.launchEnvironment["MUSES_UI_TEST_PRIVACY"] = "accepted"
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.account"].exists)
        XCTAssertTrue(app.buttons["settings.libraryData"].exists)
        XCTAssertTrue(app.buttons["settings.playback"].exists)
        XCTAssertTrue(app.staticTexts["Version"].exists)
        XCTAssertTrue(app.staticTexts["Build"].exists)
        capture("Settings", app: app)
        app.buttons["settings.privacy"].tap()
        app.buttons["settings.policy"].tap()
        XCTAssertTrue(app.navigationBars["Privacy policy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Muses-Erato privacy policy"].exists)
        capture("Full privacy policy", app: app)
    }

    func testUnrelatedLinkFailureDoesNotAppearInSettings() {
        let app = newApp()
        app.launchEnvironment["MUSES_UI_TEST_PRIVACY"] = "accepted"
        app.launch()
        XCTAssertTrue(app.buttons["public.add"].waitForExistence(timeout: 10))
        app.buttons["public.add"].tap()
        app.buttons["public.add.openLink"].tap()
        let field = app.textFields["public.link"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("invalid")
        app.buttons["public.open"].tap()
        let error = "Enter a YouTube video, playlist or channel URL (including @handle), or an 11-character video ID."
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        app.buttons["settings.account"].tap()
        XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts[error].exists)
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["settings.libraryData"].tap()
        XCTAssertTrue(app.navigationBars["Library & data"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts[error].exists)
    }

    @MainActor func testSettingsContrastAudit() throws {
        let app = newApp()
        app.launchEnvironment["MUSES_UI_TEST_PRIVACY"] = "accepted"
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        capture("Settings contrast audit", app: app)
        try app.performAccessibilityAudit(for: .contrast) { issue in
            print("[STRICT_SETTINGS_AUDIT] \(issue.compactDescription) | \(String(describing: issue.element))")
            return false
        }
        app.buttons["settings.privacy"].tap()
        XCTAssertTrue(app.buttons["settings.policy"].waitForExistence(timeout: 5))
        capture("Privacy settings contrast audit", app: app)
        try app.performAccessibilityAudit(for: .contrast) { issue in
            print("[STRICT_SETTINGS_AUDIT] \(issue.compactDescription) | \(String(describing: issue.element))")
            return false
        }
    }

}
