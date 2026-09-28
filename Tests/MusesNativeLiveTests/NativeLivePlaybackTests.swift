import XCTest
import AVFoundation
import UIKit
@testable import Muses

/// Explicit diagnostic scheme only; never part of the offline/default test suite.
@MainActor final class NativeLivePlaybackTests: XCTestCase {
    func testRickAstleyActuallyStartsAndAdvances() async throws { try await verifyPlayback("dQw4w9WgXcQ") }
    func testAdeleActuallyStartsAndAdvances() async throws { try await verifyPlayback("YQHsXMglC9A") }
    func testWeekndActuallyStartsAndAdvances() async throws { try await verifyPlayback("4NRXx6U8ABQ") }
    func testPublicMusicHomeLoadsFirstPageAndContinuation() async throws {
        let service = PublicMusicHomeService()
        let first = try await service.fetch()
        XCTAssertFalse(first.sections.isEmpty)
        XCTAssertFalse(first.authenticated)
        if let token = first.continuation {
            let next = try await service.fetch(continuation: token)
            XCTAssertNotEqual(next.continuation, token, "Pagination must not loop on the same token")
            print("HOME_LIVE initialShelves=\(first.sections.count) nextShelves=\(next.sections.count)")
        } else { print("HOME_LIVE initialShelves=\(first.sections.count) continuation=none") }
    }
    private func verifyPlayback(_ videoID: String) async throws {
        guard ExperimentalNativePlayback.available else { throw XCTSkip("Requires the native experimental build") }
        print("NATIVE_LIVE appState=\(UIApplication.shared.applicationState.rawValue)")
        let engine = ExperimentalNativePlayback()
        defer { engine.stop() }
        var failure: String?
        var advanced = false
        engine.onEvent = { event in
            switch event {
            case .time(let position, _): if position >= 1 { advanced = true }
            case .failed(let message): failure = message
            default: break
            }
        }
        engine.load(videoID: videoID, title: "Native live diagnostic", artist: "Rick Astley")
        for _ in 0..<800 {
            if failure != nil || advanced { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        let error = engine.player.currentItem?.error as NSError?
        print("NATIVE_LIVE video=\(videoID) result advanced=\(advanced) itemStatus=\(engine.player.currentItem?.status.rawValue ?? -1) timeControl=\(engine.player.timeControlStatus.rawValue) errorDomain=\(error?.domain ?? "none") errorCode=\(error?.code ?? 0)")
        XCTAssertNil(failure)
        XCTAssertTrue(advanced, "AVPlayer must decode and advance actual YouTube audio, not merely accept a URL")
    }
}
