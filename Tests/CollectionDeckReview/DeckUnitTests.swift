import XCTest
import MusesDomain
@testable import Muses

final class DeckUnitTests: XCTestCase {
    func testVirtualWindowAndDirectionalGesture() {
        XCTAssertEqual(PublicDeckProjection.visibleIndices(count: 5000, focus: 2500), [2498, 2499, 2500, 2501, 2502])
        XCTAssertEqual(PublicDeckProjection.visibleIndices(count: 0, focus: 0), [])
        XCTAssertEqual(PublicDeckProjection.swipeStep(CGSize(width: 40, height: 90)), 0)
        XCTAssertEqual(PublicDeckProjection.swipeStep(CGSize(width: -80, height: 9)), 1)
        XCTAssertEqual(PublicDeckProjection.swipeStep(CGSize(width: 80, height: 9)), -1)
    }
    func testSongsIsOnlyPlaylistUnionInFirstAppearanceOrder() throws {
        let video = try VideoID("abcdefghijk")
        let tracks = try (0..<3).map { i in try Track(id: TrackID(UUID().uuidString), title: "\(i)", artist: "", source: .youtubeVideo(video), provenance: Provenance(provider: ProviderID("youtube"), originalID: video.rawValue)) }
        let a = try LocalPlaylist(name: "A", trackIDs: [tracks[1].id, tracks[0].id])
        let b = try LocalPlaylist(name: "B", trackIDs: [tracks[0].id])
        XCTAssertEqual(PublicCollectionScope.songs(tracks: tracks, playlists: [a,b]).map(\.id), [tracks[1].id,tracks[0].id])
    }
}
