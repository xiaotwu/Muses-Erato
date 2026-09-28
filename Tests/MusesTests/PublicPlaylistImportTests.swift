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
