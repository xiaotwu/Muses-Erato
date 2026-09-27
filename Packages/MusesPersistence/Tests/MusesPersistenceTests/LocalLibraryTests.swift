import XCTest
import SwiftData
import MusesDomain
import MusesQueue
@testable import MusesPersistence

@MainActor final class LocalLibraryTests: XCTestCase {
    func testPublicV1UpgradeAndOrderedPlaylistsSurviveReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "public.sqlite")
        let a = try LegacyTrackSnapshot(id: UUID(), title: "A", artist: "YouTube", youTubeId: "dQw4w9WgXcQ", durationMs: 0, liked: true).mapped()
        let b = try LegacyTrackSnapshot(id: UUID(), title: "B", artist: "YouTube", youTubeId: "M7lc1UVf-VE", durationMs: 0, liked: false).mapped()
        let playlistID = UUID()
        // Exact initial public history wire format, before local playlists existed.
        struct OldPlayedVideo: Codable { let id: UUID; let trackID: TrackID; let date: Date }
        do {
            let container = try SwiftDataSnapshotRepository.container(url: url)
            let repo = SwiftDataSnapshotRepository(context: container.mainContext)
            try repo.saveTrack(a); try repo.saveTrack(b)
            let old = OldPlayedVideo(id: UUID(), trackID: a.id, date: .distantPast)
            try repo.put(old, kind: .history, id: old.id.uuidString)
            try repo.saveQueue(.init(current: .init(trackID: a.id, source: a.source), upcoming: [.init(trackID: b.id, source: b.source)], positionMilliseconds: 890, intent: .play))
        }
        do {
            let container = try SwiftDataSnapshotRepository.container(url: url)
            let repo = SwiftDataSnapshotRepository(context: container.mainContext)
            XCTAssertTrue(try repo.localPlaylists().isEmpty)
            XCTAssertEqual(try repo.list(PlaybackHistoryEntry.self, kind: .history).first?.trackID, a.id)
            var playlist = try LocalPlaylist(id: playlistID, name: "  Evening  ", trackIDs: [a.id, b.id])
            playlist.add(a.id)
            try playlist.reorder([b.id, a.id])
            try playlist.rename("Renamed")
            try repo.savePlaylist(playlist)
        }
        let container = try SwiftDataSnapshotRepository.container(url: url)
        let repo = SwiftDataSnapshotRepository(context: container.mainContext)
        XCTAssertEqual(try repo.localPlaylists().first?.trackIDs, [b.id, a.id])
        XCTAssertEqual(try repo.localPlaylists().first?.name, "Renamed")
        XCTAssertEqual(try repo.queue()?.intent, .pause)
        XCTAssertEqual(try repo.queue()?.positionMilliseconds, 890)
        try repo.delete(kind: .localPlaylist, id: playlistID.uuidString)
        try repo.deleteAll(kind: .history)
        XCTAssertTrue(try repo.localPlaylists().isEmpty)
        XCTAssertTrue(try repo.list(PlaybackHistoryEntry.self, kind: .history).isEmpty)
        XCTAssertEqual(try repo.track(id: a.id)?.liked, true)
        XCTAssertEqual(try repo.queue()?.upcoming.count, 1)
    }

    func testValidationAndFuturePayloadDoNotReplaceUserData() throws {
        XCTAssertThrowsError(try LocalPlaylist(name: " \n "))
        let id = try TrackID(UUID().uuidString)
        var playlist = try LocalPlaylist(name: "Keep", trackIDs: [id])
        XCTAssertThrowsError(try playlist.reorder([]))
        XCTAssertEqual(playlist.trackIDs, [id])
        let container = try SwiftDataSnapshotRepository.container(inMemory: true)
        let repo = SwiftDataSnapshotRepository(context: container.mainContext)
        XCTAssertThrowsError(try repo.savePlaylist(playlist))
        XCTAssertTrue(try repo.localPlaylists().isEmpty)
        let data = try JSONEncoder().encode(playlist)
        let row = MusesSchemaV1.Record(kind: .localPlaylist, recordID: playlist.id.uuidString, payload: data, payloadVersion: 99)
        container.mainContext.insert(row)
        try container.mainContext.save()
        XCTAssertThrowsError(try repo.localPlaylists())
        XCTAssertEqual(row.payload, data)
        XCTAssertEqual(row.payloadVersion, 99)
    }
}
