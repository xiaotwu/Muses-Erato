import XCTest
import AVFoundation
import MediaPlayer
import UIKit
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
    func testFailedStreamRetriesOnceAndStopsWithActionableError() async throws {
        var resolutions = 0
        var failure: String?
        let engine = ExperimentalNativePlayback(startupTimeout: .milliseconds(150)) { _ in
            resolutions += 1
            return URL(fileURLWithPath: "/missing-muses-audio-fixture.m4a")
        }
        defer { engine.stop() }
        engine.onEvent = { if case .failed(let message) = $0 { failure = message } }
        engine.load(videoID: "unavailable", title: "Test", artist: "Test")
        for _ in 0..<100 where failure == nil { try await Task.sleep(for: .milliseconds(30)) }
        XCTAssertEqual(resolutions, 2, "A failed startup gets one fresh resolution, never an endless loop")
        XCTAssertNotNil(failure)
        XCTAssertTrue(failure?.contains("Retry") == true)
        XCTAssertFalse(engine.loaded)
        XCTAssertNil(engine.player.currentItem)
    }

    func testArtworkTrimsPairedBlackBarsButPreservesDarkCovers() {
        func image(bars: Bool, dark: Bool = false) -> UIImage {
            UIGraphicsImageRenderer(size: CGSize(width: 640, height: 360)).image { context in
                UIColor.black.setFill(); context.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
                if !dark {
                    UIColor.red.setFill()
                    context.fill(CGRect(x: 0, y: bars ? 40 : 0, width: 640, height: bars ? 280 : 360))
                }
            }
        }
        let barred = image(bars: true)
        let cropped = PublicArtworkCrop.removingLetterbox(barred)
        XCTAssertLessThan(cropped.size.height, barred.size.height)
        XCTAssertEqual(cropped.size.width, barred.size.width)
        let plain = image(bars: false)
        XCTAssertEqual(PublicArtworkCrop.removingLetterbox(plain).size, plain.size)
        let dark = image(bars: false, dark: true)
        XCTAssertEqual(PublicArtworkCrop.removingLetterbox(dark).size, dark.size)
    }

}
