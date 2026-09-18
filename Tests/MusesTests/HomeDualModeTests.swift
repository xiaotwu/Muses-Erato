import XCTest
import SwiftData
@testable import Muses

@MainActor
final class HomeDualModeTests: XCTestCase {

    func testRecommendationModeDefaultsToMuses() {
        AppComposition.registerPreferenceDefaults()
        let previous = UserDefaults.standard.object(forKey: PrefKey.homeRecommendationMode)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: PrefKey.homeRecommendationMode)
            } else {
                UserDefaults.standard.removeObject(forKey: PrefKey.homeRecommendationMode)
            }
        }
        UserDefaults.standard.removeObject(forKey: PrefKey.homeRecommendationMode)
        AppComposition.registerPreferenceDefaults()
        XCTAssertEqual(HomeRecommendationMode.current, .muses)
    }

    func testCacheKeysIsolateModes() {
        let muses = HomeDiscoveryInput(
            topArtistNames: ["A"],
            recentlyPlayedArtistNames: [],
            likedArtistNames: [],
            timeBand: .afternoon,
            hour: 14,
            scope: .guest,
            mode: .muses
        )
        let ytm = HomeDiscoveryInput(
            topArtistNames: ["A"],
            recentlyPlayedArtistNames: [],
            likedArtistNames: [],
            timeBand: .afternoon,
            hour: 14,
            scope: .guest,
            mode: .youtubeMusic
        )
        XCTAssertNotEqual(HomeFeedCache.key(for: muses), HomeFeedCache.key(for: ytm))
        XCTAssertTrue(HomeFeedCache.key(for: muses).contains("mode=muses"))
        XCTAssertTrue(HomeFeedCache.key(for: ytm).contains("mode=youtubeMusic"))
    }

    func testModeSwitchingRoutesToMusesProvider() async throws {
        final class StubProvider: HomeDiscoveryProvider {
            let tag: String
            private(set) var fetchCount = 0
            init(tag: String) { self.tag = tag }
            func fetch(for input: HomeDiscoveryInput) async -> HomeFetchResult {
                fetchCount += 1
                return .baseline(
                    scope: input.scope,
                    sections: [
                        HomeSection(
                            id: tag,
                            title: tag,
                            kind: .mixed,
                            items: [],
                            source: tag == "muses" ? .localLibrary : .publicDiscovery)
                    ])
            }
        }

        let muses = StubProvider(tag: "muses")
        let ytm = StubProvider(tag: "ytm")
        let switching = ModeSwitchingHomeProvider(
            muses: muses,
            youtubeMusic: ytm,
            modeProvider: { .muses }
        )
        let input = HomeDiscoveryInput(
            topArtistNames: [],
            recentlyPlayedArtistNames: [],
            likedArtistNames: [],
            timeBand: .evening,
            hour: 20,
            scope: .guest,
            mode: .muses
        )
        let result = await switching.fetch(for: input)
        XCTAssertEqual(muses.fetchCount, 1)
        XCTAssertEqual(ytm.fetchCount, 0)
        XCTAssertEqual(result.baselineSnapshot.sections.first?.id, "muses")
    }

    func testModeSwitchingRoutesToYouTubeMusicProvider() async throws {
        final class StubProvider: HomeDiscoveryProvider {
            let tag: String
            private(set) var fetchCount = 0
            init(tag: String) { self.tag = tag }
            func fetch(for input: HomeDiscoveryInput) async -> HomeFetchResult {
                fetchCount += 1
                return .baseline(
                    scope: input.scope,
                    sections: [
                        HomeSection(id: tag, title: tag, kind: .youTubeCarousel, items: [])
                    ])
            }
        }

        let muses = StubProvider(tag: "muses")
        let ytm = StubProvider(tag: "ytm")
        let switching = ModeSwitchingHomeProvider(
            muses: muses,
            youtubeMusic: ytm,
            modeProvider: { .youtubeMusic }
        )
        let input = HomeDiscoveryInput(
            topArtistNames: [],
            recentlyPlayedArtistNames: [],
            likedArtistNames: [],
            timeBand: .evening,
            hour: 20,
            scope: .guest,
            mode: .youtubeMusic
        )
        let result = await switching.fetch(for: input)
        XCTAssertEqual(muses.fetchCount, 0)
        XCTAssertEqual(ytm.fetchCount, 1)
        XCTAssertEqual(result.baselineSnapshot.sections.first?.id, "ytm")
    }

    func testMusesHomeProviderBuildsLocalSectionsWithoutNetwork() async throws {
        let composition = try AppComposition.makeForTesting()
        let provider = MusesHomeProvider(library: composition.library)
        let input = HomeDiscoveryInput(
            topArtistNames: [],
            recentlyPlayedArtistNames: [],
            likedArtistNames: [],
            timeBand: .morning,
            hour: 9,
            scope: .guest,
            mode: .muses
        )
        let result = await provider.fetch(for: input)
        XCTAssertFalse(result.baselineSnapshot.sections.isEmpty)
        XCTAssertTrue(result.baselineSnapshot.sections.allSatisfy { $0.source == .localLibrary })
    }

    func testInnertubeHomeParserExtractsCarouselSections() throws {
        let json: [String: Any] = [
            "contents": [
                "singleColumnBrowseResultsRenderer": [
                    "tabs": [[
                        "tabRenderer": [
                            "content": [
                                "sectionListRenderer": [
                                    "contents": [[
                                        "musicCarouselShelfRenderer": [
                                            "header": [
                                                "musicCarouselShelfBasicHeaderRenderer": [
                                                    "title": ["runs": [["text": "Quick picks"]]]
                                                ]
                                            ],
                                            "contents": [[
                                                "musicResponsiveListItemRenderer": [
                                                    "flexColumns": [
                                                        [
                                                            "musicResponsiveListItemFlexColumnRenderer": [
                                                                "text": ["runs": [["text": "Song A"]]]
                                                            ]
                                                        ],
                                                        [
                                                            "musicResponsiveListItemFlexColumnRenderer": [
                                                                "text": ["runs": [["text": "Artist A"]]]
                                                            ]
                                                        ]
                                                    ],
                                                    "playlistItemData": ["videoId": "abcdefghijk"]
                                                ]
                                            ]]
                                        ]
                                    ]]
                                ]
                            ]
                        ]
                    ]]
                ]
            ]
        ]
        let sections = InnertubeHomeParser.sections(from: json)
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].title, "Quick picks")
        XCTAssertEqual(sections[0].cards.count, 1)
        XCTAssertEqual(sections[0].cards[0].id, "abcdefghijk")
        XCTAssertEqual(sections[0].cards[0].title, "Song A")
    }

    func testAppCompositionExposesYouTubeMusicSession() throws {
        let composition = try AppComposition.makeForTesting()
        XCTAssertNotNil(composition.youTubeMusicSession)
        XCTAssertFalse(composition.homeProviderHasWebEnhancement)
    }
}
