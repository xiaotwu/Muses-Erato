import XCTest
import SwiftData
import MusesDomain
import MusesQueue
@testable import MusesPersistence

@MainActor final class LocalLibraryDeletionTests: XCTestCase {
    private func track(_ raw: String) throws -> Track {
        Track(id: try TrackID(UUID().uuidString), title: raw, artist: "User", source: .youtubeVideo(try VideoID(raw)), provenance: try Provenance(provider: ProviderID("youtube"), originalID: raw), liked: true, metadataOrigin: .user)
    }
    func testSingleCommitCleansEntirePublicGraphAndPreservesArchive() throws {
        let container = try SwiftDataSnapshotRepository.container(inMemory: true)
        let repo = SwiftDataSnapshotRepository(context: container.mainContext)
        let a = try track("abcdefghijk"), b = try track("lmnopqrstuv")
        try repo.saveTrack(a); try repo.saveTrack(b)
        let playlist = try LocalPlaylist(name: "My list", trackIDs: [a.id, b.id])
        try repo.savePlaylist(playlist)
        let historyA = PlaybackHistoryEntry(trackID: a.id), historyB = PlaybackHistoryEntry(trackID: b.id)
        try repo.put(historyA, kind: .history, id: historyA.id.uuidString)
        try repo.put(historyB, kind: .history, id: historyB.id.uuidString)
        try repo.put(a.id, kind: .favorite, id: a.id.rawValue)
        try repo.put("untouched", kind: .legacyTrack, id: "archive")
        try repo.saveQueue(QueueSnapshot(current: QueueEntry(trackID: a.id, source: a.source), upcoming: [QueueEntry(trackID: b.id, source: b.source), QueueEntry(trackID: a.id, source: a.source)], history: [QueueEntry(trackID: a.id, source: a.source)]))
        try repo.saveVideoNote(VideoNote(trackID: a.id, content: "Delete with video"))
        try repo.saveVideoNote(VideoNote(trackID: b.id, content: "Keep other video note"))
        try repo.saveVideoBookmark(VideoTimeBookmark(trackID: a.id, timestampMilliseconds: 42))
        let result = try repo.deleteSavedTrack(a.id)
        XCTAssertTrue(try repo.videoNotes(trackID: a.id).isEmpty)
        XCTAssertTrue(try repo.videoBookmarks(trackID: a.id).isEmpty)
        XCTAssertEqual(try repo.videoNotes(trackID: b.id).count, 1)
        XCTAssertEqual(result.tracks.map(\.id), [b.id])
        XCTAssertEqual(result.playlists.first?.trackIDs, [b.id])
        XCTAssertEqual(result.history.map(\.id), [historyB.id])
        XCTAssertNil(result.queue.current); XCTAssertTrue(result.queue.history.isEmpty)
        XCTAssertEqual(result.queue.upcoming.map(\.trackID), [b.id])
        XCTAssertNil(try repo.get(TrackID.self, kind: .favorite, id: a.id.rawValue))
        XCTAssertEqual(try repo.get(String.self, kind: .legacyTrack, id: "archive"), "untouched")
    }
    func testSaveFailureRollsBackAllStagedMutations() throws {
        enum Failure: Error { case disk }
        let container = try SwiftDataSnapshotRepository.container(inMemory: true)
        let repo = SwiftDataSnapshotRepository(context: container.mainContext)
        let a = try track("abcdefghijk"), b = try track("lmnopqrstuv")
        try repo.saveTrack(a); try repo.saveTrack(b)
        let playlist = try LocalPlaylist(name: "Keep", trackIDs: [a.id, b.id])
        try repo.savePlaylist(playlist)
        let history = PlaybackHistoryEntry(trackID: a.id)
        try repo.put(history, kind: .history, id: history.id.uuidString)
        let queue = QueueSnapshot(current: QueueEntry(trackID: a.id, source: a.source))
        try repo.saveQueue(queue)
        let note = VideoNote(trackID: a.id, content: "Keep on failure")
        let bookmark = try VideoTimeBookmark(trackID: a.id, timestampMilliseconds: 1000)
        try repo.saveVideoNote(note); try repo.saveVideoBookmark(bookmark)
        XCTAssertThrowsError(try repo.deleteSavedTracks([a.id, b.id], save: { throw Failure.disk }))
        XCTAssertEqual(try repo.videoNotes(trackID: a.id), [note])
        XCTAssertEqual(try repo.videoBookmarks(trackID: a.id), [bookmark])
        XCTAssertEqual(try repo.list(Track.self, kind: .track).count, 2)
        XCTAssertEqual(try repo.localPlaylists(), [playlist])
        XCTAssertEqual(try repo.queue(), queue)
        XCTAssertEqual(try repo.list(PlaybackHistoryEntry.self, kind: .history), [history])
    }
    func testClearFavoritesAndHistoryDoNotDeleteSavedVideos() throws {
        let container = try SwiftDataSnapshotRepository.container(inMemory: true)
        let repo = SwiftDataSnapshotRepository(context: container.mainContext)
        let a = try track("abcdefghijk"), b = try track("lmnopqrstuv")
        try repo.saveTrack(a); try repo.saveTrack(b)
        for _ in 0..<2 { let h = PlaybackHistoryEntry(trackID: a.id); try repo.put(h, kind: .history, id: h.id.uuidString) }
        let other = PlaybackHistoryEntry(trackID: b.id); try repo.put(other, kind: .history, id: other.id.uuidString)
        let history = try repo.removeLocalHistory(for: a.id)
        XCTAssertEqual(history, [other])
        XCTAssertTrue(try repo.clearLocalFavorites().allSatisfy { !$0.liked })
        XCTAssertEqual(try repo.list(Track.self, kind: .track).count, 2)
    }
}
