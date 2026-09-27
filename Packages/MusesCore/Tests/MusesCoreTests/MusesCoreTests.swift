import XCTest
@testable import MusesCore

final class MusesCoreTests: XCTestCase {
    func testBrowseIdsMatchMusicHomeContract() {
        XCTAssertEqual(YouTubeMusicBrowseIDs.home, "FEmusic_home")
        XCTAssertEqual(YouTubeMusicBrowseIDs.charts, "FEmusic_charts")
    }

    func testCatalogIdentityPrefersChannel() {
        XCTAssertEqual(
            CatalogIdentity.artist(channelID: "UCabc", browseID: "MPxyz"),
            "channel:UCabc"
        )
    }

    func testHomeModeRawValuesStable() {
        XCTAssertEqual(HomeRecommendationMode.muses.rawValue, "muses")
        XCTAssertEqual(HomeRecommendationMode.youtubeMusic.rawValue, "youtubeMusic")
    }
}
