import XCTest
import SwiftData
import MusesCatalog
import MusesDomain
import MusesPersistence
@testable import Muses

@MainActor final class PublicPlaylistImportTests: XCTestCase {
    func testImportedTitlesVisibleInMemoryButAbsentFromStoredPayload() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = PublicYouTubeSession(storeURL: directory.appending(path: "library.sqlite"))
        var draft = PlaylistImportDraft()
        let item = CatalogItem(kind: .video, id: "dQw4w9WgXcQ", title: "API secret display title", channelID: nil, thumbnailURL: nil, fetchedAt: Date(), listEntryID: "one")
        try draft.append(.init(items: [item], nextPageToken: nil))
        try session.saveImportedPlaylist(name: "User collection", draft: draft)
        XCTAssertEqual(session.tracks.first?.title, item.title)
        session.toggleFavorite(session.tracks.first!.id)
        let rows = try session.repository!.context.fetch(FetchDescriptor<MusesSchemaV1.Record>())
        XCTAssertFalse(rows.contains { String(data: $0.payload, encoding: .utf8)?.contains(item.title) == true })
        XCTAssertEqual(try session.repository!.list(Track.self, kind: .track).first?.title, "YouTube video dQw4w9WgXcQ")
        XCTAssertEqual(session.tracks.first?.title, item.title)
    }
}

extension PublicPlaylistImportTests {
    func testOccurrenceEditsSurviveRestartAndQueueKeepsRepeatedOrder() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "library.sqlite")
        let session = PublicYouTubeSession(storeURL: url)
        var draft = PlaylistImportDraft()
        let videos = ["dQw4w9WgXcQ", "M7lc1UVf-VE", "dQw4w9WgXcQ"]
        try draft.append(.init(items: videos.enumerated().map { index, id in
            CatalogItem(kind: .video, id: id, title: id, channelID: nil, thumbnailURL: nil, listEntryID: "entry\(index)")
        }, nextPageToken: nil))
        try session.saveImportedPlaylist(name: "Repeated", draft: draft)
        let original = try XCTUnwrap(session.playlists.first)
        let entries = try XCTUnwrap(original.occurrences)
        XCTAssertEqual(original.entryCount, 3)
        session.enqueuePlaylist(original.id)
        XCTAssertEqual(session.queue.snapshot.upcoming.map(\.trackID), original.playbackTrackIDs)
        XCTAssertEqual(Set(session.queue.snapshot.upcoming.map(\.id)).count, 3)
        XCTAssertTrue(session.editPlaylist(original.id) { try $0.reorderOccurrences([entries[1].id, entries[0].id, entries[2].id]) })
        XCTAssertEqual(session.playlists[0].playbackTrackIDs, [entries[1].trackID!, entries[0].trackID!, entries[2].trackID!])
        XCTAssertTrue(session.editPlaylist(original.id) { $0.removeOccurrence(entries[0].id) })
        XCTAssertEqual(session.playlists[0].entryCount, 2)
        let reopened = PublicYouTubeSession(storeURL: url)
        XCTAssertEqual(reopened.playlists[0].occurrences?.map(\.id), [entries[1].id, entries[2].id])
        XCTAssertEqual(reopened.playlists[0].trackIDs, [entries[1].trackID!, entries[2].trackID!])
        reopened.clearUpcoming()
        reopened.enqueuePlaylist(original.id)
        XCTAssertEqual(reopened.queue.snapshot.upcoming.map(\.trackID), [entries[1].trackID!, entries[2].trackID!])
    }
}
