import Foundation
import SwiftData
import XCTest
import MusesDomain
@testable import MusesPersistence

@MainActor final class CompleteMigrationTests: XCTestCase {
    private let models: Set<String> = ["Track", "QueueState", "EQPreset", "YouTubeImport",
        "YouTubeImportItem", "Playlist", "PlaylistItem", "ListeningEvent", "ListeningSession",
        "InboxItem", "TrackNote", "TrackBookmark", "AutomationRule", "FocusSession",
        "YouTubePlaylistRevision", "YouTubeSyncOperation", "YouTubeSyncBatch",
        "CatalogRelease", "CatalogArtist"]

    private func track(_ id: UUID) throws -> LegacyTrackArchive {
        let row: [String: Any] = [
            "id": id.uuidString, "title": "Edited title", "artist": "Artist",
            "albumTitle": "Album", "albumArtist": "Album artist", "durationMs": 45123,
            "trackNo": 3, "discNo": 2, "year": 2020, "genre": "Jazz",
            "youTubeId": "dQw4w9WgXcQ", "mediaKindRaw": "song",
            "releaseCatalogID": "browse:release", "releaseOrder": 4,
            "artistCatalogID": "channel:artist", "artworkUrl": "https://example.com/art.jpg",
            "lyrics": "User corrected lyrics", "lyricsOffsetMs": 220,
            "replayGain": -3.5, "sampleRate": 44100, "bitDepth": 16, "codec": "aac",
            "bitRate": 192000, "channels": 2, "isLossless": false,
            "metadataStatusRaw": "embedded", "availabilityRaw": "available",
            "addedAt": 0, "lastPlayedAt": 500, "playCount": 12, "liked": true
        ]
        return try JSONDecoder().decode(LegacyTrackArchive.self, from: JSONSerialization.data(withJSONObject: row))
    }

    private func bundle(_ id: UUID) throws -> LegacyCompleteBundle {
        let archive = try track(id)
        var truth = LegacyUserTruthBundle()
        truth.tracks = [LegacyTrackSnapshot(id: id, title: archive.title, artist: archive.artist,
                                           youTubeId: archive.youTubeId, durationMs: archive.durationMs,
                                           liked: archive.liked)]
        let queue = LegacyQueueArchive(id: UUID(), itemsJSON: "[]", currentIndex: -1,
            upNextJSON: "[]", historyJSON: "[]", repeatModeRaw: "off", shuffle: false,
            savedAt: .distantPast, currentTrackId: nil, lastPositionMs: nil,
            groupsJSON: "[]")
        truth.queue = LegacyQueueSnapshot(items: [], currentIndex: -1, repeatModeRaw: "off",
                                          shuffle: false, lastPositionMs: nil)
        return LegacyCompleteBundle(userTruth: truth, tracks: [archive], queue: queue,
            otherModels: Dictionary(uniqueKeysWithValues: LegacyModelKind.allCases.map { ($0, []) }),
            inspectedModels: models, inspectedSettingKeys: LegacyCompleteBundle.knownSettingKeys)
    }

    func testCompleteDiskImportPreservesFullTrackAndRawQueueAndIsIdempotent() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("public.sqlite")
        let id = UUID()
        let source = try bundle(id)
        do {
            let container = try SwiftDataSnapshotRepository.container(url: url)
            let repo = SwiftDataSnapshotRepository(context: container.mainContext)
            try repo.importLegacyComplete(source)
            try repo.importLegacyComplete(source)
            XCTAssertThrowsError(try repo.importLegacyComplete(bundle(UUID())))
            try repo.put("damaged", kind: .legacyTrack, id: id.uuidString)
            XCTAssertThrowsError(try repo.importLegacyComplete(source))
            try repo.put(source.tracks[0], kind: .legacyTrack, id: id.uuidString)
            XCTAssertEqual(try repo.list(LegacyTrackArchive.self, kind: .legacyTrack).count, 1)
        }
        let container = try SwiftDataSnapshotRepository.container(url: url)
        let repo = SwiftDataSnapshotRepository(context: container.mainContext)
        XCTAssertEqual(try repo.track(id: TrackID(id.uuidString))?.title, "Edited title")
        XCTAssertEqual(try repo.get(LegacyTrackArchive.self, kind: .legacyTrack, id: id.uuidString)?.lyrics, "User corrected lyrics")
        XCTAssertEqual(try repo.list(LegacyQueueArchive.self, kind: .legacyQueue).first?.groupsJSON, "[]")
        XCTAssertEqual(try repo.get(LegacyMigrationReceipt.self, kind: .migration,
                                    id: "legacy-complete-v1")?.recordCount, 5)
    }

    func testInvalidQueueAndMissingFieldsLeaveTargetEmpty() throws {
        let container = try SwiftDataSnapshotRepository.container(inMemory: true)
        let repo = SwiftDataSnapshotRepository(context: container.mainContext)
        var source = try bundle(UUID())
        source.queue?.groupsJSON = "{broken"
        XCTAssertThrowsError(try repo.importLegacyComplete(source))
        XCTAssertTrue(try repo.list(LegacyTrackArchive.self, kind: .legacyTrack).isEmpty)
        XCTAssertNil(try repo.get(LegacyMigrationReceipt.self, kind: .migration,
                                 id: "legacy-complete-v1"))
        source = try bundle(UUID())
        source.otherModels[.trackNote] = [LegacyModelArchive(id: UUID(), fields: Data("{}".utf8), fieldNames: [])]
        XCTAssertThrowsError(try repo.importLegacyComplete(source))
        XCTAssertTrue(try repo.list(Track.self, kind: .track).isEmpty)
    }

    func testQueueArchiveProjectsAllPlayableSectionsAndRetainsAdvancedFields() throws {
        let container = try SwiftDataSnapshotRepository.container(inMemory: true)
        let repo = SwiftDataSnapshotRepository(context: container.mainContext)
        let trackID = UUID()
        var source = try bundle(trackID)
        func entry(_ id: UUID) -> String {
            """
            {"id":"\(id.uuidString)","track":{"id":"\(trackID.uuidString)","youTubeId":"dQw4w9WgXcQ"},"locked":true,"priority":7,"queuedAt":0}
            """
        }
        let current = UUID(), next = UUID(), past = UUID()
        source.queue?.itemsJSON = "[\(entry(current))]"
        source.queue?.upNextJSON = "[\(entry(next))]"
        source.queue?.historyJSON = "[\(entry(past))]"
        source.queue?.currentIndex = 0
        source.queue?.lastPositionMs = 1500
        source.queue?.groupsJSON = "[{\"id\":\"\(UUID().uuidString)\",\"name\":\"Set\",\"order\":0,\"collapsed\":true}]"
        try repo.importLegacyComplete(source)
        XCTAssertEqual(try repo.queue()?.current?.id, current)
        XCTAssertEqual(try repo.queue()?.upcoming.map(\.id), [next])
        XCTAssertEqual(try repo.queue()?.history.map(\.id), [past])
        XCTAssertEqual(try repo.queue()?.positionMilliseconds, 1500)
        XCTAssertTrue(try repo.list(LegacyQueueArchive.self, kind: .legacyQueue).first?.groupsJSON?.contains("collapsed") == true)
    }

    func testExistingTargetAndCorruptPayloadAreSurfaced() throws {
        let container = try SwiftDataSnapshotRepository.container(inMemory: true)
        let repo = SwiftDataSnapshotRepository(context: container.mainContext)
        try repo.put("existing", kind: .setting, id: "user")
        XCTAssertThrowsError(try repo.importLegacyComplete(bundle(UUID())))
        XCTAssertEqual(try repo.get(String.self, kind: .setting, id: "user"), "existing")
        container.mainContext.insert(MusesSchemaV1.Record(kind: .legacyTrack, recordID: UUID().uuidString,
                                                           payload: Data("broken".utf8)))
        try container.mainContext.save()
        XCTAssertThrowsError(try repo.list(LegacyTrackArchive.self, kind: .legacyTrack))
    }

    func testArchivedNotesAndPlaylistRelationshipsRetainSourceFields() throws {
        let trackID = UUID(), noteID = UUID(), playlistID = UUID(), itemID = UUID()
        var source = try bundle(trackID)
        source.userTruth.notes = [LegacyNote(id: noteID, trackId: trackID, content: "My words",
                                             createdAt: .distantPast, updatedAt: .distantPast)]
        source.userTruth.playlists = [LegacyPlaylist(id: playlistID, name: "My list",
                                                     createdAt: .distantPast, pinned: true)]
        source.userTruth.playlistItems = [LegacyPlaylistItem(id: itemID, playlistID: playlistID,
                                                             trackID: trackID, order: 2)]
        func archive(_ kind: LegacyModelKind, id: UUID, overrides: [String: Any]) throws -> LegacyModelArchive {
            var object = Dictionary(uniqueKeysWithValues: kind.requiredFields.map { ($0, NSNull() as Any) })
            object["id"] = id.uuidString
            for (key, value) in overrides { object[key] = value }
            return LegacyModelArchive(id: id, fields: try JSONSerialization.data(withJSONObject: object),
                                      fieldNames: kind.requiredFields)
        }
        source.otherModels[.trackNote] = [try archive(.trackNote, id: noteID,
            overrides: ["trackId": trackID.uuidString, "content": "My words", "createdAt": 0, "updatedAt": 0])]
        source.otherModels[.playlist] = [try archive(.playlist, id: playlistID,
            overrides: ["name": "My list", "createdAt": 0, "pinned": true, "items": [itemID.uuidString]])]
        source.otherModels[.playlistItem] = [try archive(.playlistItem, id: itemID,
            overrides: ["order": 2, "playlist": playlistID.uuidString, "track": trackID.uuidString])]
        let repo = SwiftDataSnapshotRepository(context: ModelContext(try SwiftDataSnapshotRepository.container(inMemory: true)))
        try repo.importLegacyComplete(source)
        XCTAssertEqual(try repo.list(LegacyNote.self, kind: .note).first?.content, "My words")
        let stored = try repo.get(LegacyModelArchive.self, kind: .legacyModel,
                                  id: "playlistItem:\(itemID.uuidString)")
        XCTAssertEqual(stored?.fieldNames, LegacyModelKind.playlistItem.requiredFields)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(stored?.fields)) as? [String: Any])
        XCTAssertEqual(object["track"] as? String, trackID.uuidString)
    }
    func testNotebookEditsKeepMigrationReceiptAndSourceArchive() throws {
        let trackID = UUID(), noteID = UUID(), bookmarkID = UUID()
        var source = try bundle(trackID)
        let note = LegacyNote(id: noteID, trackId: trackID, content: "Original note", createdAt: .distantPast, updatedAt: .distantPast)
        let bookmark = LegacyBookmark(id: bookmarkID, trackId: trackID, timestampMs: 1234.5, title: "Original", note: "Keep detail")
        source.userTruth.notes = [note]
        source.userTruth.bookmarks = [bookmark]
        source.otherModels[.trackNote] = [LegacyModelArchive(id: noteID, fields: try JSONEncoder().encode(note), fieldNames: LegacyModelKind.trackNote.requiredFields)]
        var bookmarkFields = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(bookmark)) as? [String: Any])
        bookmarkFields["createdAt"] = 321
        source.otherModels[.trackBookmark] = [LegacyModelArchive(id: bookmarkID, fields: try JSONSerialization.data(withJSONObject: bookmarkFields), fieldNames: LegacyModelKind.trackBookmark.requiredFields)]
        let container = try SwiftDataSnapshotRepository.container(inMemory: true)
        let repo = SwiftDataSnapshotRepository(context: container.mainContext)
        try repo.importLegacyComplete(source)
        try repo.importLegacyComplete(source)
        let receipt = try repo.get(LegacyMigrationReceipt.self, kind: .migration, id: "legacy-complete-v1")
        let noteArchive = try repo.get(LegacyModelArchive.self, kind: .legacyModel, id: "trackNote:\(noteID.uuidString)")
        let bookmarkArchive = try repo.get(LegacyModelArchive.self, kind: .legacyModel, id: "trackBookmark:\(bookmarkID.uuidString)")
        let id = try TrackID(trackID.uuidString)
        let projected = try XCTUnwrap(repo.videoNotes(trackID: id).first)
        try repo.saveVideoNote(projected.edited(content: "Edited locally"))
        let projectedBookmark = try XCTUnwrap(repo.videoBookmarks(trackID: id).first)
        try repo.saveVideoBookmark(.init(id: bookmarkID, trackID: id, timestampMilliseconds: 9999, title: "Edited", note: projectedBookmark.note))
        XCTAssertEqual(try repo.get(LegacyMigrationReceipt.self, kind: .migration, id: "legacy-complete-v1"), receipt)
        XCTAssertEqual(try repo.get(LegacyModelArchive.self, kind: .legacyModel, id: "trackNote:\(noteID.uuidString)")?.fields, noteArchive?.fields)
        XCTAssertEqual(try repo.get(LegacyModelArchive.self, kind: .legacyModel, id: "trackBookmark:\(bookmarkID.uuidString)")?.fields, bookmarkArchive?.fields)
        try repo.deleteVideoNote(id: noteID, trackID: id)
        try repo.deleteVideoBookmark(id: bookmarkID, trackID: id)
        XCTAssertNotNil(try repo.get(LegacyModelArchive.self, kind: .legacyModel, id: "trackBookmark:\(bookmarkID.uuidString)"))
    }

}
