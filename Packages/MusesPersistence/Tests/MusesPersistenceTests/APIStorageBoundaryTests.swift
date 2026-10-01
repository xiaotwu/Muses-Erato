import XCTest
import SwiftData
import MusesDomain
@testable import MusesPersistence

@MainActor final class APIStorageBoundaryTests: XCTestCase {
    func testFreshAPITitleNeverEntersDurableTrackPayload() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "library.sqlite")
        let track = Track(id: try TrackID(UUID().uuidString), title: "API-only title", artist: "API-only channel",
            source: .youtubeVideo(try VideoID("M7lc1UVf-VE")),
            provenance: try Provenance(provider: ProviderID("youtube"), originalID: "M7lc1UVf-VE"),
            durationMilliseconds: 123000, liked: true, metadataOrigin: .youtubeDataAPI, metadataFetchedAt: Date(), contentKind: .music)
        let container = try SwiftDataSnapshotRepository.container(url: url)
        let repository = SwiftDataSnapshotRepository(context: ModelContext(container))
        try repository.put(track, kind: .track, id: track.id.rawValue)
        let rows = try repository.context.fetch(FetchDescriptor<MusesSchemaV1.Record>())
        XCTAssertFalse(rows.contains { String(data: $0.payload, encoding: .utf8)?.contains("API-only") == true })
        let reopened = try SwiftDataSnapshotRepository.container(url: url)
        let saved = try XCTUnwrap(SwiftDataSnapshotRepository(context: ModelContext(reopened)).track(id: track.id))
        XCTAssertEqual(saved.id, track.id)
        XCTAssertEqual(saved.source, track.source)
        XCTAssertTrue(saved.liked)
        XCTAssertNil(saved.durationMilliseconds)
        XCTAssertNil(saved.contentKind)
        XCTAssertFalse(rows.contains { String(data: $0.payload, encoding: .utf8)?.contains("contentKind") == true })
        XCTAssertEqual(saved.metadataOrigin, .placeholder)
        XCTAssertEqual(track.title, "API-only title", "Live display value remains available in memory")
        var userEdit = track
        userEdit.title = "My own label"; userEdit.artist = "My own grouping"; userEdit.metadataOrigin = .user
        try repository.saveTrack(userEdit)
        XCTAssertEqual(try repository.track(id: track.id)?.title, "My own label")
        XCTAssertNil(try repository.track(id: track.id)?.contentKind)
    }
}
