import XCTest
import SwiftData
import MusesDomain
@testable import MusesPersistence

@MainActor final class PlaylistImportTests: XCTestCase {
    func testAtomicImportRetainsOrderRepeatsAndReusesSavedTracks() throws {
        let container = try SwiftDataSnapshotRepository.container(inMemory: true)
        let repo = SwiftDataSnapshotRepository(context: container.mainContext)
        let a = try VideoID("dQw4w9WgXcQ"), b = try VideoID("M7lc1UVf-VE")
        let (first, initial) = try repo.importPlaylist(name: "My name", videoIDs: [a, b, a])
        XCTAssertEqual(initial.count, 2)
        XCTAssertEqual(first.playbackTrackIDs, [initial[0].id, initial[1].id, initial[0].id])
        XCTAssertEqual(try repo.localPlaylists().first, first)
        let (_, added) = try repo.importPlaylist(name: "Second", videoIDs: [a])
        XCTAssertTrue(added.isEmpty)
        XCTAssertThrowsError(try repo.importPlaylist(name: "  ", videoIDs: [try VideoID("abcdefghijk")]))
        XCTAssertEqual(try repo.list(Track.self, kind: .track).count, 2)
        XCTAssertEqual(try repo.localPlaylists().count, 2)
        XCTAssertTrue(try repo.list(Track.self, kind: .track).allSatisfy { $0.metadataOrigin == .placeholder })
    }
}

extension PlaylistImportTests {
    func testUnavailableOccurrenceAndInvalidReorderPreserveProjection() throws {
        let a = try TrackID(UUID().uuidString), b = try TrackID(UUID().uuidString)
        let entries = [LocalPlaylistOccurrence(id: UUID(), trackID: a), .init(id: UUID(), trackID: b), .init(id: UUID(), trackID: a), .init(id: UUID(), trackID: nil)]
        var playlist = try LocalPlaylist(name: "Legacy", trackIDs: [a, b], occurrences: entries)
        XCTAssertEqual(playlist.entryCount, 4)
        XCTAssertThrowsError(try playlist.reorderOccurrences([entries[0].id, entries[0].id, entries[2].id, entries[3].id]))
        XCTAssertEqual(playlist.occurrences, entries)
        playlist.removeOccurrence(entries[0].id)
        XCTAssertEqual(playlist.playbackTrackIDs, [b, a])
        XCTAssertEqual(playlist.trackIDs, [b, a])
        playlist.remove(a) // Existing whole-track deletion still removes every occurrence.
        XCTAssertEqual(playlist.entryCount, 2)
        playlist.removeAllEntries()
        XCTAssertEqual(playlist.entryCount, 0)
        XCTAssertEqual(playlist.occurrences, [])
        try playlist.validated()
    }
}
