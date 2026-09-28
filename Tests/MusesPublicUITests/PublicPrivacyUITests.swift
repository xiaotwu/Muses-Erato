import XCTest

final class PublicPrivacyUITests: XCTestCase {
    func testAgreementGatesFeaturesAndPersistsForSamePolicy() {
        let app = XCUIApplication()
        app.launchEnvironment["MUSES_UI_TEST_LIBRARY"] = UUID().uuidString
        app.launchEnvironment["MUSES_UI_TEST_PRIVACY"] = "required"
        app.launch()
        let proceed = app.buttons["privacy.continue"]
        XCTAssertTrue(proceed.waitForExistence(timeout: 10))
        XCTAssertFalse(proceed.isEnabled)
        XCTAssertFalse(app.buttons["public.openLinkEntry"].exists)
        app.buttons["privacy.agreement"].tap()
        XCTAssertTrue(proceed.isEnabled)
        proceed.tap()
        XCTAssertTrue(app.buttons["public.openLinkEntry"].waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["public.openLinkEntry"].waitForExistence(timeout: 10))
        XCTAssertFalse(proceed.exists)
    }
}
