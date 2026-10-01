import XCTest
import SwiftUI
@testable import Muses

final class PublicPrivacyPolicyTests: XCTestCase {
    @MainActor func testInvalidLinkLeavesSettingsFeedbackClear() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "privacy-settings-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "muses.settings.tests.\(UUID().uuidString)"
        let store = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { store.removePersistentDomain(forName: suite) }
        let session = PublicYouTubeSession(storeURL: directory.appending(path: "library.sqlite"), defaults: store, domainName: suite)
        await session.openLink("invalid")
        XCTAssertNotNil(session.failureMessage, "The unrelated failing operation must actually report an error")
        XCTAssertNil(session.accountOperation.error)
        XCTAssertNil(session.metadataRefreshOperation.error)
        XCTAssertNil(session.localDataDeletionOperation.error)
    }

    @MainActor func testGateDoesNotConstructContentBeforeConsentOrWithoutPolicy() throws {
        let suite = "muses.privacy.gate.\(UUID().uuidString)"
        let store = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { store.removePersistentDomain(forName: suite) }
        var constructions = 0
        let unaccepted = PublicPrivacyGate(store: store, policy: { "Complete policy" }, fixtureAccepted: false) {
            constructions += 1
            return EmptyView()
        }
        _ = unaccepted.body
        XCTAssertEqual(constructions, 0)
        store.set(PublicPrivacyPolicy.version, forKey: PublicPrivacyPolicy.acceptanceKey)
        let missing = PublicPrivacyGate(store: store, policy: { nil }, fixtureAccepted: true) {
            constructions += 1
            return EmptyView()
        }
        _ = missing.body
        XCTAssertEqual(constructions, 0)
        let accepted = PublicPrivacyGate(store: store, policy: { "Complete policy" }, fixtureAccepted: false) {
            constructions += 1
            return EmptyView()
        }
        _ = accepted.body
        XCTAssertEqual(constructions, 1)
    }

    func testPolicyMustExistEvenForSavedConsentOrFixtures() {
        for policy: String? in [nil, "", " \n\t "] {
            XCTAssertFalse(PublicPrivacyPolicy.canEnter(acceptedVersion: PublicPrivacyPolicy.version, policy: policy))
            XCTAssertFalse(PublicPrivacyPolicy.canEnter(acceptedVersion: "", policy: policy, fixtureAccepted: true))
        }
    }

    func testVersionedConsentIsRequired() {
        XCTAssertFalse(PublicPrivacyPolicy.canEnter(acceptedVersion: "", policy: "Complete policy"))
        XCTAssertFalse(PublicPrivacyPolicy.canEnter(acceptedVersion: "2026-09-28.2", policy: "Complete policy"))
        XCTAssertTrue(PublicPrivacyPolicy.canEnter(acceptedVersion: PublicPrivacyPolicy.version, policy: "Complete policy"))
    }

    func testBundledPolicyMatchesConsentVersionAndHasReadableSections() throws {
        let policy = try XCTUnwrap(PublicPrivacyPolicy.text)
        XCTAssertTrue(policy.contains("Version \(PublicPrivacyPolicy.version)"))
        XCTAssertTrue(policy.contains("## Search and playback"))
        XCTAssertTrue(policy.contains("## Your controls"))
        XCTAssertFalse(policy.contains("Cloud Home requests are sent"))
    }
}
