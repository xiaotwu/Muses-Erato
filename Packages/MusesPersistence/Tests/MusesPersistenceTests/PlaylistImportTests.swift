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

extension PlaylistImportTests {
    func testRemoteNameNeverEntersPersistedPayloadThroughAnyWritePath() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "remote-name.sqlite")
        let container = try SwiftDataSnapshotRepository.container(url: url)
        let repo = SwiftDataSnapshotRepository(context: container.mainContext)
        let apiTitle = "REMOTE_API_NAME_MUST_NOT_PERSIST"
        let source = RemotePlaylistSource(playlistID: "PLremote", requiresAuthorization: true)
        let (playlist, added) = try repo.importPlaylist(name: apiTitle, videoIDs: [try VideoID("dQw4w9WgXcQ")], remoteSource: source, nameFetchedAt: Date())
        XCTAssertEqual(playlist.name, apiTitle)
        XCTAssertTrue(playlist.usesRemoteName)
        try repo.put(playlist, kind: .localPlaylist, id: playlist.id.uuidString)
        try repo.savePlaylist(playlist)
        _ = try repo.deleteSavedTrack(added[0].id)
        let rows = try container.mainContext.fetch(FetchDescriptor<MusesSchemaV1.Record>())
        XCTAssertFalse(rows.contains { String(data: $0.payload, encoding: .utf8)?.contains(apiTitle) == true })
        let reopened = try SwiftDataSnapshotRepository.container(url: url)
        let read = SwiftDataSnapshotRepository(context: reopened.mainContext)
        var restored = try XCTUnwrap(read.localPlaylists().first)
        XCTAssertEqual(restored.name, LocalPlaylist.remoteNamePlaceholder)
        XCTAssertEqual(restored.remoteSource, source)
        try restored.updateRemoteName(apiTitle)
        try restored.rename(apiTitle) // Confirming the unchanged prefilled value is not authorship.
        XCTAssertTrue(restored.usesRemoteName)
        try restored.rename("My actual custom name")
        try read.savePlaylist(restored)
        XCTAssertFalse(restored.usesRemoteName)
        try restored.updateRemoteName("Remote renamed again")
        XCTAssertEqual(restored.name, "My actual custom name")
        XCTAssertEqual(try read.localPlaylists().first?.name, "My actual custom name")
    }
}
