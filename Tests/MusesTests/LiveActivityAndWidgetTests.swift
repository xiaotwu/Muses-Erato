import XCTest
@testable import Muses

final class LiveActivityAndWidgetTests: XCTestCase {

    func testSnapshotRoundTrip() throws {
        let suite = "muses.test.snapshot.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = NowPlayingSnapshotStore(defaults: defaults, containerURL: nil)
        let snapshot = NowPlayingSnapshot(
            trackId: "abc",
            title: "Song",
            artist: "Artist",
            isPlaying: true,
            artworkFileName: "art.jpg",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        store.save(snapshot)
        XCTAssertEqual(store.load()?.title, "Song")
        XCTAssertEqual(store.load()?.artist, "Artist")
        XCTAssertEqual(store.load()?.isPlaying, true)
        store.clear()
        XCTAssertNil(store.load())
    }

    func testPendingCommandQueue() {
        let suite = "muses.test.command.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = NowPlayingSnapshotStore(defaults: defaults, containerURL: nil)
        store.enqueue(.toggle)
        XCTAssertEqual(store.dequeue(), .toggle)
        XCTAssertNil(store.dequeue())
        store.enqueue(.next)
        store.enqueue(.toggle)
        XCTAssertEqual(store.dequeue(), .toggle)
    }

    func testEmptySnapshotOpensAppNotBlank() {
        XCTAssertEqual(NowPlayingSnapshot.empty.title.isEmpty, false)
        XCTAssertFalse(NowPlayingSnapshot.empty.isPlaying)
        XCTAssertNil(NowPlayingSnapshot.empty.trackId)
    }

    func testPolicyStartsOnPlayAndEndsWithoutTrack() {
        let policy = LiveActivitySessionPolicy()
        let now = Date()
        XCTAssertEqual(
            policy.decide(enabled: true, hasTrack: true, isPlaying: true,
                          hasActivity: false, startedAt: nil, lastPausedAt: nil, now: now),
            .start
        )
        XCTAssertEqual(
            policy.decide(enabled: true, hasTrack: false, isPlaying: false,
                          hasActivity: true, startedAt: now, lastPausedAt: now, now: now),
            .end
        )
    }

    func testPolicyEndsAfterTenMinutePause() {
        let policy = LiveActivitySessionPolicy()
        let started = Date()
        let paused = started.addingTimeInterval(30)
        XCTAssertEqual(
            policy.decide(enabled: true, hasTrack: true, isPlaying: false,
                          hasActivity: true, startedAt: started, lastPausedAt: paused,
                          now: paused.addingTimeInterval(9 * 60)),
            .update
        )
        XCTAssertEqual(
            policy.decide(enabled: true, hasTrack: true, isPlaying: false,
                          hasActivity: true, startedAt: started, lastPausedAt: paused,
                          now: paused.addingTimeInterval(10 * 60)),
            .end
        )
    }

    func testPolicyRestartsAfterEightHours() {
        let policy = LiveActivitySessionPolicy()
        let started = Date()
        XCTAssertEqual(
            policy.decide(enabled: true, hasTrack: true, isPlaying: true,
                          hasActivity: true, startedAt: started, lastPausedAt: nil,
                          now: started.addingTimeInterval(8 * 60 * 60)),
            .restart
        )
    }

    func testPolicyTrackChangeUpdatesWithoutRestart() {
        let policy = LiveActivitySessionPolicy()
        let now = Date()
        XCTAssertEqual(
            policy.decide(enabled: true, hasTrack: true, isPlaying: true,
                          hasActivity: true, startedAt: now, lastPausedAt: nil, now: now),
            .update
        )
    }

    func testCurrentOrRecentKeepsLastTrackWhenQueueEmpty() {
        let previous = NowPlayingSnapshot(
            trackId: "abc",
            title: "Song",
            artist: "Artist",
            isPlaying: true,
            artworkFileName: "art.jpg",
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        let published = NowPlayingSnapshot.currentOrRecent(
            trackId: nil,
            title: "",
            artist: "",
            isPlaying: false,
            previous: previous,
            now: Date(timeIntervalSince1970: 2)
        )
        XCTAssertEqual(published.trackId, "abc")
        XCTAssertEqual(published.title, "Song")
        XCTAssertFalse(published.isPlaying)
        XCTAssertEqual(published.artworkFileName, "art.jpg")
    }

    func testCurrentOrRecentDropsArtworkWhenTrackChanges() {
        let previous = NowPlayingSnapshot(
            trackId: "abc",
            title: "Song",
            artist: "Artist",
            isPlaying: true,
            artworkFileName: "old.jpg",
            updatedAt: Date()
        )
        let published = NowPlayingSnapshot.currentOrRecent(
            trackId: "def",
            title: "Next",
            artist: "Other",
            isPlaying: true,
            previous: previous
        )
        XCTAssertEqual(published.trackId, "def")
        XCTAssertNil(published.artworkFileName)
    }

    func testPolicyDisabledEndsExistingActivity() {
        let policy = LiveActivitySessionPolicy()
        let now = Date()
        XCTAssertEqual(
            policy.decide(enabled: false, hasTrack: true, isPlaying: true,
                          hasActivity: true, startedAt: now, lastPausedAt: nil, now: now),
            .end
        )
        XCTAssertEqual(
            policy.decide(enabled: false, hasTrack: true, isPlaying: true,
                          hasActivity: false, startedAt: nil, lastPausedAt: nil, now: now),
            .none
        )
    }
}
