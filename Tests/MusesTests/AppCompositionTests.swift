import XCTest
import SwiftData
@testable import Muses

@MainActor
final class AppCompositionTests: XCTestCase {

    func testProductionGraphSeedsNoSampleTrack() throws {
        let composition = try AppComposition.makeForTesting()
        XCTAssertNil(
            composition.playback.state.track,
            "Empty playback.state.track must remain valid; no sample-erato seed"
        )
    }

    func testCoreServicesAreConstructed() throws {
        let composition = try AppComposition.makeForTesting()
        XCTAssertNotNil(composition.lyrics)
        XCTAssertNotNil(composition.homeDiscovery)
        XCTAssertNotNil(composition.situational)
        XCTAssertNotNil(composition.context)
        XCTAssertNotNil(composition.history)
        XCTAssertFalse(
            composition.homeProviderHasWebEnhancement,
            "Default Home path must not require macOS WebHome helper"
        )
    }

    func testQueueRestoreDoesNotCrashWithEmptyStore() throws {
        let composition = try AppComposition.makeForTesting()
        // restore() already ran inside make(); call again for empty-store safety.
        composition.queue.restore()
        XCTAssertTrue(composition.queue.items.isEmpty)
    }

    func testFeatureFlagsDefaultOnForLocalDiscovery() {
        AppComposition.registerPreferenceDefaults()
        XCTAssertEqual(FeatureFlagDefaults.enabledByDefault[PrefKey.ffDiscovery], true)
        XCTAssertEqual(FeatureFlagDefaults.enabledByDefault[PrefKey.ffSituationalNew], true)
        XCTAssertEqual(FeatureFlagDefaults.enabledByDefault[PrefKey.ffContext], true)
        XCTAssertEqual(FeatureFlagDefaults.enabledByDefault[PrefKey.ffSmartHistory], true)
    }

    func testHomeDiscoveryLoadAndReloadDoNotCrash() throws {
        let composition = try AppComposition.makeForTesting()
        composition.homeDiscovery.load()
        composition.homeDiscovery.reload()
    }

    func testContextCaptureRespectsFeatureFlag() {
        let key = PrefKey.ffContext
        let previous = UserDefaults.standard.object(forKey: key)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        UserDefaults.standard.set(false, forKey: key)
        let context = ContextService()
        XCTAssertNil(context.capture())

        UserDefaults.standard.set(true, forKey: key)
        let snapped = context.capture()
        XCTAssertNotNil(snapped)
        XCTAssertNil(
            snapped?.frontmostAppBundleId,
            "iOS must not invent frontmost-app tracking"
        )
    }
}
