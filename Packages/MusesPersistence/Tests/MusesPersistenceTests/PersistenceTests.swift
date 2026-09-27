import XCTest
import SwiftData
import MusesDomain
import MusesQueue
@testable import MusesPersistence

@MainActor final class PersistenceTests: XCTestCase {
    func testTrackAndQueueRoundTripWithoutAutoPlay() throws {
        let container = try SwiftDataSnapshotRepository.container(inMemory: true)
        let repo = SwiftDataSnapshotRepository(context: ModelContext(container))
        let legacy = LegacyTrackSnapshot(id: UUID(), title: "A", artist: "B", youTubeId: "dQw4w9WgXcQ", durationMs: 1000, liked: true)
        let track = try legacy.mapped()
        try repo.saveTrack(track)
        XCTAssertEqual(try repo.track(id: track.id), track)
        let entry = QueueEntry(trackID: track.id, source: track.source)
        try repo.saveQueue(QueueSnapshot(current: entry, positionMilliseconds: 250, intent: .play))
        XCTAssertEqual(try repo.queue()?.current?.id, entry.id)
        XCTAssertEqual(try repo.queue()?.positionMilliseconds, 250)
        XCTAssertEqual(try repo.queue()?.intent, .pause)
    }
    func testLegacyQueueFixtureAndCorruptRecordRecovery() throws {
        let id = UUID()
        let old = LegacyQueueSnapshot(items: [LegacyQueueEntry(id: id, trackID: UUID(), youTubeId: "dQw4w9WgXcQ")], currentIndex: 0, repeatModeRaw: "all", shuffle: false, lastPositionMs: 1234)
        let mapped = try old.mapped()
        XCTAssertEqual(mapped.current?.id, id)
        XCTAssertEqual(mapped.positionMilliseconds, 1234)
        XCTAssertEqual(mapped.intent, .pause)
        let container = try SwiftDataSnapshotRepository.container(inMemory: true)
        let context = ModelContext(container)
        context.insert(MusesSchemaV1.Record(kind: .track, recordID: "broken", payload: Data("bad".utf8)))
        try context.save()
        let repo = SwiftDataSnapshotRepository(context: context)
        XCTAssertThrowsError(try repo.get(Track.self, kind: .track, id: "broken"))
        XCTAssertEqual(try repo.get(Track.self, kind: .track, id: "missing"), nil)
    }
    func testWholeUserTruthImportIsAtomicAndIdempotent() throws {
        let repo = SwiftDataSnapshotRepository(context: ModelContext(try SwiftDataSnapshotRepository.container(inMemory: true)))
        let oldID = UUID()
        var bundle = LegacyUserTruthBundle()
        bundle.tracks = [LegacyTrackSnapshot(id: oldID, title: "First", artist: "Artist", youTubeId: "dQw4w9WgXcQ", durationMs: 1, liked: true)]
        bundle.notes = [LegacyNote(id: UUID(), trackId: oldID, content: "Keep", createdAt: .distantPast, updatedAt: .distantPast)]
        bundle.playlists = [LegacyPlaylist(id: UUID(), name: "Saved", createdAt: .distantPast, pinned: true)]
        bundle.history = [LegacyHistoryEvent(id: UUID(), trackID: oldID, title: "First", artist: "Artist", startedAt: .distantPast, listenedMs: 500, outcomeRaw: "completed")]
        bundle.imports = [LegacyImport(id: UUID(), playlistID: "PL123", originalURL: "https://www.youtube.com/playlist?list=PL123", title: "Imported", importedAt: .distantPast)]
        bundle.settings = [LegacySetting(key: "repeat", value: Data("all".utf8))]
        let bad = LegacyImportItem(id: UUID(), importID: bundle.imports[0].id, videoID: "invalid", playlistItemID: nil, order: 0)
        bundle.importItems = [bad]
        XCTAssertThrowsError(try repo.importLegacy(bundle))
        XCTAssertEqual(try repo.list(Track.self, kind: .track).count, 0)
        bundle.importItems = [LegacyImportItem(id: bad.id, importID: bad.importID, videoID: "dQw4w9WgXcQ", playlistItemID: nil, order: 0)]
        try repo.importLegacy(bundle)
        XCTAssertEqual(try repo.list(Track.self, kind: .track).count, 1)
        XCTAssertEqual(try repo.list(LegacyNote.self, kind: .note).first?.content, "Keep")
        XCTAssertEqual(try repo.list(LegacyPlaylist.self, kind: .playlist).first?.name, "Saved")
        XCTAssertEqual(try repo.list(LegacyHistoryEvent.self, kind: .history).count, 1)
        XCTAssertEqual(try repo.list(LegacyImport.self, kind: .importRelation).count, 1)
        XCTAssertEqual(try repo.list(LegacyImportItem.self, kind: .importItem).count, 1)
        XCTAssertEqual(try repo.list(LegacySetting.self, kind: .setting).count, 1)
        bundle.tracks = []
        try repo.importLegacy(bundle)
        XCTAssertEqual(try repo.list(Track.self, kind: .track).count, 1)
    }
    func testDiskStoreReopensWithQueuePaused() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("v1.sqlite")
        let oldID = UUID()
        do {
            let repo = SwiftDataSnapshotRepository(context: ModelContext(try SwiftDataSnapshotRepository.container(url: url)))
            let entry = try QueueEntry(trackID: TrackID(oldID.uuidString), source: .youtubeVideo(VideoID("dQw4w9WgXcQ")))
            try repo.saveQueue(QueueSnapshot(current: entry, generation: 7, positionMilliseconds: 901, intent: .play))
        }
        let reopened = SwiftDataSnapshotRepository(context: ModelContext(try SwiftDataSnapshotRepository.container(url: url)))
        XCTAssertEqual(try reopened.queue()?.generation, 7)
        XCTAssertEqual(try reopened.queue()?.positionMilliseconds, 901)
        XCTAssertEqual(try reopened.queue()?.intent, .pause)
    }
}
