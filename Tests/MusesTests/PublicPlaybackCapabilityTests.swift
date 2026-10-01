import XCTest
@testable import Muses

/// Compiled only into the Public project's shared regression target.
@MainActor final class PublicPlaybackCapabilityTests: XCTestCase {
    func testNativePlaybackIsUnavailableAndCannotEmitPlaybackEvents() {
        XCTAssertFalse(ExperimentalNativePlayback.available)
        let engine = ExperimentalNativePlayback()
        var receivedEvent = false
        engine.onEvent = { _ in receivedEvent = true }
        engine.load(videoID: "test-video", title: "Test", artist: "Test")
        engine.play()
        engine.retry()
        engine.seek(10)
        engine.pause()
        engine.stop()
        XCTAssertFalse(engine.loaded)
        XCTAssertFalse(engine.wantsPlayback)
        XCTAssertFalse(receivedEvent)
    }

    func testPublicAppDoesNotDeclareBackgroundAudio() {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        XCTAssertFalse(modes.contains("audio"))
    }
}
