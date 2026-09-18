import XCTest
@testable import Muses

@MainActor
final class InnertubeSearchParserTests: XCTestCase {

    func testParsesSongShelfEntries() {
        let json: [String: Any] = [
            "contents": [
                "tabbedSearchResultsRenderer": [
                    "tabs": [[
                        "tabRenderer": [
                            "content": [
                                "sectionListRenderer": [
                                    "contents": [[
                                        "musicShelfRenderer": [
                                            "title": ["runs": [["text": "Songs"]]],
                                            "contents": [
                                                [
                                                    "musicResponsiveListItemRenderer": [
                                                        "flexColumns": [
                                                            [
                                                                "musicResponsiveListItemFlexColumnRenderer": [
                                                                    "text": ["runs": [["text": "Night Drive"]]]
                                                                ]
                                                            ],
                                                            [
                                                                "musicResponsiveListItemFlexColumnRenderer": [
                                                                    "text": ["runs": [["text": "Nova"]]]
                                                                ]
                                                            ]
                                                        ],
                                                        "playlistItemData": ["videoId": "ABCDEFGHIJK"],
                                                        "lengthText": ["simpleText": "3:45"]
                                                    ]
                                                ]
                                            ]
                                        ]
                                    ]]
                                ]
                            ]
                        ]
                    ]]
                ]
            ]
        ]

        let entries = InnertubeSearchParser.entries(from: json, limit: 10)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].id, "ABCDEFGHIJK")
        XCTAssertEqual(entries[0].title, "Night Drive")
        XCTAssertEqual(entries[0].uploader, "Nova")
        XCTAssertEqual(entries[0].duration, 225)
    }

    func testIgnoresNonVideoIds() {
        let json: [String: Any] = [
            "contents": [
                "musicShelfRenderer": [
                    "title": ["runs": [["text": "Songs"]]],
                    "contents": [[
                        "musicResponsiveListItemRenderer": [
                            "flexColumns": [[
                                "musicResponsiveListItemFlexColumnRenderer": [
                                    "text": ["runs": [["text": "Some Playlist"]]]
                                ]
                            ]],
                            "playlistItemData": ["videoId": "PLTOO_LONG_TO_BE_VIDEO"]
                        ]
                    ]]
                ]
            ]
        ]
        XCTAssertTrue(InnertubeSearchParser.entries(from: json).isEmpty)
    }

    func testCatalogBrowseIdsAreStable() {
        XCTAssertEqual(YouTubeMusicCatalog.BrowseID.home, "FEmusic_home")
        XCTAssertEqual(YouTubeMusicCatalog.BrowseID.charts, "FEcharts")
        XCTAssertEqual(YouTubeMusicCatalog.BrowseID.newReleases, "FEmusic_new_releases")
        XCTAssertFalse(YouTubeMusicCatalog.BrowseID.moodsAndGenres.isEmpty)
    }

    func testYouTubeSearchServiceUsesBridge() async throws {
        final class StubBridge: YTDlpBridgeProtocol {
            func resolveStreamURL(videoId: String, quality: String, timeout: TimeInterval) async throws -> URL {
                URL(string: "https://example.com/\(videoId)")!
            }
            func fetchPlaylist(url: String, timeout: TimeInterval) async throws -> [YTDlpPlaylistEntry] { [] }
            func searchYouTube(query: String, limit: Int, timeout: TimeInterval) async throws -> [YTDlpPlaylistEntry] {
                [
                    YTDlpPlaylistEntry(id: "12345678901", title: "Hit", uploader: "Artist")
                ]
            }
            func version() async -> String? { "stub" }
        }

        let container = try makeModelContainer(inMemory: true)
        let service = YouTubeSearchService(bridge: StubBridge(), modelContainer: container)
        let results = try await service.search(query: "hit", limit: 5)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "Hit")
    }
}
