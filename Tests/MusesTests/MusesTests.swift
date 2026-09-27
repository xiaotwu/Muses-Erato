import XCTest
@testable import Muses

final class MusesTests: XCTestCase {

    func testTrackInitialization() throws {
        let track = Track(
            title: "Triumph on the Ice",
            artist: "Streetwise Rhapsody",
            durationMs: 214000,
            youTubeId: "test-video-id"
        )
        XCTAssertEqual(track.title, "Triumph on the Ice")
        XCTAssertEqual(track.artist, "Streetwise Rhapsody")
        XCTAssertEqual(track.durationSeconds, 214.0)
    }

    func testModelContainerCreation() throws {
        let container = try makeModelContainer(inMemory: true)
        XCTAssertNotNil(container)
    }

    func testAppleMusicTokens() {
        XCTAssertEqual(AppleMusicTokens.keyColorHex, "C7A66B")
        XCTAssertGreaterThan(AppleMusicTokens.miniPlayerHeight, 50)
        XCTAssertGreaterThan(AppleMusicTokens.tabBarHeight, 50)
    }

    func testEQBandInitialization() {
        let band = EQBand(frequency: 1000, gain: 3.5)
        XCTAssertEqual(band.frequency, 1000)
        XCTAssertEqual(band.gain, 3.5)
    }

    func testYouTubeResolverPlaylistEntry() {
        let entry = YTDlpPlaylistEntry(
            id: "abc123xyz",
            title: "Test Song",
            uploader: "Test Artist",
            duration: 180.0
        )
        XCTAssertEqual(entry.id, "abc123xyz")
        XCTAssertEqual(entry.title, "Test Song")
    }

    func testSeedPlaylistJSON() throws {
        let seedURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Muses/Resources/muses-debug-seed.json")
        let data = try Data(contentsOf: seedURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["playlistId"] as? String, "PLVRppllwHcDw")
        let entries = json?["entries"] as? [[String: Any]]
        XCTAssertEqual(entries?.count, 506)
    }
}
