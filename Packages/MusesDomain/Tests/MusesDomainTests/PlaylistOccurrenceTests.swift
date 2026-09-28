import XCTest
import MusesDomain

final class PlaylistOccurrenceTests: XCTestCase {
    func testOccurrencesPreserveRepeatsAndUnavailableSlotsThroughEdits() throws {
        let a = try TrackID(UUID().uuidString), b = try TrackID(UUID().uuidString)
        let entries: [LocalPlaylistOccurrence] = [
            .init(id: UUID(), trackID: a), .init(id: UUID(), trackID: b),
            .init(id: UUID(), trackID: a), .init(id: UUID(), trackID: nil)
        ]
        var playlist = try LocalPlaylist(name: "Original", trackIDs: [a, b], occurrences: entries)
        XCTAssertEqual(playlist.playbackTrackIDs, [a, b, a])
        let encoded = try JSONEncoder().encode(playlist)
        XCTAssertEqual(try JSONDecoder().decode(LocalPlaylist.self, from: encoded).occurrences, entries)
        try playlist.rename("Edited name")
        XCTAssertEqual(playlist.occurrences, entries)
        playlist.add(a)
        XCTAssertEqual(playlist.playbackTrackIDs, [a, b, a])
        try playlist.reorder([b, a])
        XCTAssertEqual(playlist.playbackTrackIDs, [b, a, a])
        XCTAssertEqual(Set(playlist.occurrences!.map(\.id)), Set(entries.map(\.id)))
        playlist.remove(a)
        XCTAssertEqual(playlist.playbackTrackIDs, [b])
        XCTAssertNil(playlist.occurrences?.last?.trackID)
        try playlist.validated()
    }

    func testOldPublicPayloadStillDecodesAndBadProjectionFails() throws {
        let id = UUID(), track = try TrackID(UUID().uuidString)
        let json = """
        {"id":"\(id)","name":"Saved","trackIDs":["\(track.rawValue)"],"createdAt":0}
        """
        let old = try JSONDecoder().decode(LocalPlaylist.self, from: Data(json.utf8))
        XCTAssertNil(old.occurrences)
        XCTAssertEqual(old.playbackTrackIDs, [track])
        XCTAssertThrowsError(try LocalPlaylist(name: "Bad", trackIDs: [], occurrences: [.init(id: UUID(), trackID: track)]))
    }
}
