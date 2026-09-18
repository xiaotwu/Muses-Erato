import XCTest
@testable import Muses

final class LyricsMatchPolicyTests: XCTestCase {
    private func track(title: String, artist: String, duration: Double = 200) -> TrackSnapshot {
        TrackSnapshot(
            id: UUID(),
            title: title,
            artist: artist,
            albumTitle: nil,
            durationSeconds: duration,
            youTubeId: "ABCDEFGHIJK",
            artworkUrl: nil,
            sampleRate: nil,
            bitDepth: nil,
            codec: nil,
            isLossless: false
        )
    }

    func testRejectsCoverWhenRecordingIsStudio() {
        let studio = track(title: "Night Drive", artist: "Nova")
        let cover = LyricsCandidate(
            id: 1,
            trackName: "Night Drive (Cover)",
            artistName: "Someone",
            albumName: nil,
            duration: 200,
            instrumental: false,
            plainLyrics: "line",
            syncedLyrics: nil
        )
        XCTAssertEqual(LyricsMatchPolicy.score(cover, track: studio), 0)
    }

    func testRanksExactArtistTitleHigh() {
        let studio = track(title: "Night Drive", artist: "Nova")
        let exact = LyricsCandidate(
            id: 2,
            trackName: "Night Drive",
            artistName: "Nova",
            albumName: nil,
            duration: 201,
            instrumental: false,
            plainLyrics: "hello",
            syncedLyrics: "[00:01.00]hello"
        )
        let weak = LyricsCandidate(
            id: 3,
            trackName: "Night Drive Remix",
            artistName: "Other",
            albumName: nil,
            duration: 240,
            instrumental: false,
            plainLyrics: "hello",
            syncedLyrics: nil
        )
        let ranked = LyricsMatchPolicy.ranked([weak, exact], track: studio)
        XCTAssertEqual(ranked.first?.id, 2)
        XCTAssertEqual(LyricsMatchPolicy.automatic([weak, exact], track: studio)?.id, 2)
    }

    func testLineAlignmentRejectsMissingIndex() {
        XCTAssertNil(LyricsLineAlignment.align([(0, "a"), (2, "c")], count: 3))
        XCTAssertEqual(LyricsLineAlignment.align([(1, "b"), (0, "a")], count: 2), ["a", "b"])
    }

    func testSanitizedTitleStripsOfficialVideoNoise() {
        let cleaned = LyricsService.sanitizedTitle("Song (Official Music Video)")
        XCTAssertEqual(cleaned, "Song")
    }
}
