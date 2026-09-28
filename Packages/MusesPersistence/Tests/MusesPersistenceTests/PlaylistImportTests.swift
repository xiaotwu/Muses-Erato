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
