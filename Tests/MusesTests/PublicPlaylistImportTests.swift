import XCTest
import SwiftData
import MusesCatalog
import MusesDomain
import MusesPersistence
import MusesNetworking
@testable import Muses

@MainActor final class PublicPlaylistImportTests: XCTestCase {
    func testImportedTitlesVisibleInMemoryButAbsentFromStoredPayload() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = PublicYouTubeSession(storeURL: directory.appending(path: "library.sqlite"))
        var draft = PlaylistImportDraft()
        let item = CatalogItem(kind: .video, id: "dQw4w9WgXcQ", title: "API secret display title", channelID: nil, thumbnailURL: nil, fetchedAt: Date(), listEntryID: "one", contentKind: .music)
        try draft.append(.init(items: [item], nextPageToken: nil))
        try session.saveImportedPlaylist(name: "User collection", draft: draft)
        XCTAssertEqual(session.tracks.first?.title, item.title)
        XCTAssertEqual(session.tracks.first?.contentKind, .music)
        session.toggleFavorite(session.tracks.first!.id)
        let rows = try session.repository!.context.fetch(FetchDescriptor<MusesSchemaV1.Record>())
        XCTAssertFalse(rows.contains { String(data: $0.payload, encoding: .utf8)?.contains(item.title) == true })
        XCTAssertEqual(try session.repository!.list(Track.self, kind: .track).first?.title, "YouTube video dQw4w9WgXcQ")
        XCTAssertNil(try session.repository!.list(Track.self, kind: .track).first?.contentKind)
        XCTAssertEqual(session.tracks.first?.title, item.title)
    }
}

extension PublicPlaylistImportTests {
    func testSongsPlaybackUsesCompleteVisibleCollectionContext() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = PublicYouTubeSession(storeURL: directory.appending(path: "library.sqlite"))
        for id in ["dQw4w9WgXcQ", "M7lc1UVf-VE"] { _ = session.open(try VideoID(id), title: id) }
        let collection = session.tracks
        XCTAssertTrue(session.playTracks(collection, startingAt: 0, context: "collection:Songs"))
        XCTAssertEqual(session.queue.snapshot.current?.trackID, collection[0].id)
        XCTAssertEqual(session.queue.snapshot.upcoming.map(\.trackID), [collection[1].id])
        XCTAssertTrue(session.playTracks(collection, startingAt: 1, context: "collection:Songs"))
        XCTAssertEqual(session.queue.snapshot.current?.trackID, collection[1].id)
        XCTAssertTrue(session.queue.snapshot.upcoming.isEmpty)
        XCTAssertEqual(session.queue.snapshot.history.last?.trackID, collection[0].id)
        XCTAssertEqual(session.queue.snapshot.intent, .pause)
        XCTAssertEqual(session.queue.snapshot.sourceContext, "collection:Songs")
    }

    func testSongsClearRemovesOnlyPlaylistUnionAndRetainsUnlistedSavedVideo() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "library.sqlite")
        let session = PublicYouTubeSession(storeURL: url)
        for id in ["dQw4w9WgXcQ", "M7lc1UVf-VE"] { _ = session.open(try VideoID(id), title: id) }
        let inPlaylist = try XCTUnwrap(session.tracks.first)
        let unlisted = try XCTUnwrap(session.tracks.last)
        XCTAssertTrue(session.createPlaylist("One", trackIDs: [inPlaylist.id]))
        XCTAssertTrue(session.createPlaylist("Two", trackIDs: [inPlaylist.id]))
        session.clearLibraryItems(.songs)
        XCTAssertEqual(session.tracks.map(\.id), [unlisted.id])
        XCTAssertEqual(session.playlists.count, 2)
        XCTAssertTrue(session.playlists.allSatisfy { $0.trackIDs.isEmpty })
        let reopened = PublicYouTubeSession(storeURL: url)
        XCTAssertEqual(reopened.tracks.map(\.id), [unlisted.id])
        XCTAssertEqual(reopened.playlists.count, 2)
    }

    func testPlaylistPlaybackStartsAtOriginalOccurrenceAndPreservesExplicitQueue() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "library.sqlite")
        let session = PublicYouTubeSession(storeURL: url)
        var draft = PlaylistImportDraft()
        try draft.append(.init(items: ["dQw4w9WgXcQ", "M7lc1UVf-VE", "dQw4w9WgXcQ"].enumerated().map { index, id in
            CatalogItem(kind: .video, id: id, title: id, channelID: nil, thumbnailURL: nil, listEntryID: "entry\(index)")
        }, nextPageToken: nil))
        try session.saveImportedPlaylist(name: "Repeated", draft: draft)
        let playlist = try XCTUnwrap(session.playlists.first)
        let first = try XCTUnwrap(session.tracks.first)
        session.enqueueTrack(first)
        let explicit = try XCTUnwrap(session.queue.snapshot.upcoming.first)
        XCTAssertTrue(session.editPlaylist(playlist.id) { value in
            var occurrences = try XCTUnwrap(value.occurrences)
            occurrences.insert(LocalPlaylistOccurrence(id: UUID(), trackID: nil), at: 1)
            value = try LocalPlaylist(id: value.id, name: value.name, trackIDs: value.trackIDs, createdAt: value.createdAt, occurrences: occurrences)
        })
        XCTAssertFalse(session.playPlaylist(playlist.id, startingAtOccurrenceIndex: 1))
        XCTAssertTrue(session.playPlaylist(playlist.id, startingAtOccurrenceIndex: 2))
        XCTAssertEqual(session.queue.snapshot.current?.trackID, playlist.playbackTrackIDs[1])
        XCTAssertEqual(session.queue.snapshot.history.map(\.trackID), [playlist.playbackTrackIDs[0]])
        XCTAssertEqual(session.queue.snapshot.upcoming.map(\.trackID), [playlist.playbackTrackIDs[2], first.id])
        XCTAssertEqual(session.queue.snapshot.upcoming.last?.id, explicit.id)
        XCTAssertEqual(session.queue.snapshot.sourceContext, "playlist:" + playlist.id.uuidString)
        XCTAssertEqual(session.queue.snapshot.intent, .pause)
        XCTAssertTrue(session.showPlayer)
        let reopened = PublicYouTubeSession(storeURL: url)
        XCTAssertEqual(reopened.queue.snapshot.current?.id, session.queue.snapshot.current?.id)
        XCTAssertEqual(reopened.queue.snapshot.upcoming, session.queue.snapshot.upcoming)
        XCTAssertTrue(reopened.playPlaylist(playlist.id, startingAtOccurrenceIndex: 0))
        XCTAssertEqual(reopened.queue.snapshot.upcoming.map(\.trackID), playlist.playbackTrackIDs.dropFirst().map { $0 } + [first.id])
        XCTAssertEqual(reopened.queue.snapshot.upcoming.last?.id, explicit.id)
    }

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

private actor PlaylistNameHTTP: HTTPTransport {
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        HTTPResponse(status: 200, body: Data(#"{"items":[{"id":"PLremote","snippet":{"title":"Original remote name"}}]}"#.utf8))
    }
}
extension PublicPlaylistImportTests {
    func testDefaultNameRestoresOnlineAfterRestartAndCustomRenamePersists() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "library.sqlite")
        let catalog = YouTubeDataCatalog(apiKey: "fixture", transport: PlaylistNameHTTP())
        let session = PublicYouTubeSession(storeURL: url, catalogOverride: catalog)
        var draft = PlaylistImportDraft()
        let item = CatalogItem(kind: .video, id: "dQw4w9WgXcQ", title: "Video temporary title", channelID: nil, thumbnailURL: nil, listEntryID: "one")
        try draft.append(.init(items: [item], nextPageToken: "next"))
        XCTAssertThrowsError(try session.saveImportedPlaylist(name: "Partial", draft: draft))
        XCTAssertTrue(session.playlists.isEmpty)
        XCTAssertTrue(try session.repository!.localPlaylists().isEmpty)
        try draft.append(.init(items: [], nextPageToken: nil))
        try session.saveImportedPlaylist(name: "Original remote name", draft: draft, remoteSource: .init(playlistID: "PLremote", requiresAuthorization: false), originalName: "Original remote name")
        XCTAssertEqual(session.playlists[0].name, "Original remote name")
        let rows = try session.repository!.context.fetch(FetchDescriptor<MusesSchemaV1.Record>())
        XCTAssertFalse(rows.contains { String(data: $0.payload, encoding: .utf8)?.contains("Original remote name") == true })
        let reopened = PublicYouTubeSession(storeURL: url, catalogOverride: catalog)
        XCTAssertEqual(reopened.playlists[0].name, LocalPlaylist.remoteNamePlaceholder)
        await reopened.maintainCatalogData()
        XCTAssertEqual(reopened.playlists[0].name, "Original remote name")
        try reopened.expireCatalogMetadata(force: true)
        XCTAssertEqual(reopened.playlists[0].name, LocalPlaylist.remoteNamePlaceholder)
        await reopened.refreshPlaylistNames(force: true)
        XCTAssertEqual(reopened.playlists[0].name, "Original remote name")
        XCTAssertTrue(reopened.editPlaylist(reopened.playlists[0].id) { try $0.rename("My own name") })
        let custom = PublicYouTubeSession(storeURL: url, catalogOverride: catalog)
        await custom.refreshPlaylistNames(force: true)
        XCTAssertEqual(custom.playlists[0].name, "My own name")
        try custom.expireCatalogMetadata(force: true)
        XCTAssertEqual(custom.playlists[0].name, "My own name")
    }
}

extension PublicPlaylistImportTests {
    func testFailedAndCancelledReadsCannotWritePartialLibrary() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = PublicYouTubeSession(storeURL: directory.appending(path: "library.sqlite"))
        for cancelled in [false, true] {
            let reader = PlaylistImportReader()
            let task = Task { @MainActor in
                try await reader.readAll(playlistID: "PLremote") { contents, token in
                    if !contents {
                        return .init(items: [.init(kind: .playlist, id: "PLremote", title: "Original", channelID: nil, thumbnailURL: nil)], nextPageToken: nil)
                    }
                    if token != nil {
                        if cancelled { withUnsafeCurrentTask { $0?.cancel() } }
                        else { throw URLError(.notConnectedToInternet) }
                    }
                    return .init(items: [.init(kind: .video, id: "dQw4w9WgXcQ", title: "Video", channelID: nil, thumbnailURL: nil, listEntryID: token ?? "first")], nextPageToken: token == nil ? "next" : nil)
                }
            }
            do { try await task.value; XCTFail("Expected read failure") } catch { }
            XCTAssertFalse(reader.draft.complete)
            XCTAssertThrowsError(try session.saveImportedPlaylist(name: "Original", draft: reader.draft, remoteSource: .init(playlistID: "PLremote", requiresAuthorization: false), originalName: "Original"))
            XCTAssertTrue(try session.repository!.localPlaylists().isEmpty)
            XCTAssertTrue(try session.repository!.list(Track.self, kind: .track).isEmpty)
        }
    }
}
