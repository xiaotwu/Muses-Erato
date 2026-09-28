import XCTest
import AVFoundation
import MediaPlayer
@testable import Muses

@MainActor final class ExperimentalNativePlaybackTests: XCTestCase {
    func testLateResolutionCannotReplaceNewTrackOrReviveStoppedPlayer() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100))
        buffer.frameLength = 44100
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        var pending: CheckedContinuation<URL, Error>?
        let engine = ExperimentalNativePlayback { id in
            if id == "old" { return try await withCheckedThrowingContinuation { pending = $0 } }
            return url
        }
        engine.load(videoID: "old", title: "Old", artist: "Test", autoplay: false)
        for _ in 0..<20 where pending == nil { await Task.yield() }
        XCTAssertNotNil(pending)
        engine.load(videoID: "new", title: "New", artist: "Test", autoplay: false)
        for _ in 0..<50 where !engine.loaded { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertTrue(engine.loaded)
        let item = try XCTUnwrap(engine.player.currentItem)
        pending?.resume(returning: url)
        for _ in 0..<10 { await Task.yield() }
        XCTAssertTrue(engine.player.currentItem === item, "Old resolver must not replace the current item")
        engine.stop()
        XCTAssertFalse(engine.loaded)
        XCTAssertNil(engine.player.currentItem)
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
        XCTAssertFalse(MPRemoteCommandCenter.shared().playCommand.isEnabled)
        engine.load(videoID: "old", title: "Old", artist: "Test", autoplay: false)
        pending = nil
        for _ in 0..<20 where pending == nil { await Task.yield() }
        engine.stop(); pending?.resume(returning: url)
        for _ in 0..<10 { await Task.yield() }
        XCTAssertNil(engine.player.currentItem, "Stop must cancel unresolved loads")
    }
}
