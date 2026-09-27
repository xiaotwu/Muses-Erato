import XCTest
@testable import MusesDomain

final class DomainTests: XCTestCase {
    func testIDsRejectMalformedAndStayDistinct() throws {
        XCTAssertThrowsError(try VideoID("bad"))
        XCTAssertThrowsError(try VideoID("dQw4w9WgXcQ\n"))
        let id = try VideoID("dQw4w9WgXcQ")
        XCTAssertEqual(try JSONDecoder().decode(VideoID.self, from: JSONEncoder().encode(id)), id)
        XCTAssertThrowsError(try JSONDecoder().decode(VideoID.self, from: Data("\"bad\"".utf8)))
    }
    func testRightsFailClosedAndYouTubeHasNoNativeAudioGrant() throws {
        let video = PlaybackSource.youtubeVideo(try VideoID("dQw4w9WgXcQ"))
        let remote = PlaybackSource.authorizedRemote(try ProviderID("licensed"), try ResourceID("r1"))
        let publicBuild = DistributionCapabilities(channel: .appStore)
        XCTAssertTrue(publicBuild.allows(video, rights: .init(origin: .youtube)))
        XCTAssertFalse(publicBuild.allows(remote, rights: .init(origin: .licensedRemote)))
        XCTAssertFalse(publicBuild.allows(remote, rights: .init(origin: .licensedRemote, licenseEvidenceID: "agreement-1")))
        let licensed = DistributionCapabilities(channel: .internalTesting, permittedEvidenceIDs: ["agreement-1"])
        XCTAssertTrue(licensed.allows(remote, rights: .init(origin: .licensedRemote, licenseEvidenceID: "agreement-1")))
        let all: PlaybackCapabilities = [.seek, .videoVisible, .backgroundAudio, .audioProcessing, .offlineMedia, .systemRemote]
        let effective = PlaybackCapabilityPolicy.effective(source: video, rights: .init(origin: .youtube), distribution: publicBuild, adapter: all, runtime: all)
        XCTAssertTrue(effective.contains(.seek))
        XCTAssertTrue(effective.contains(.videoVisible))
        XCTAssertFalse(effective.contains(.backgroundAudio))
        XCTAssertFalse(effective.contains(.audioProcessing))
        XCTAssertEqual(PlaybackCapabilityPolicy.effective(source: video, rights: .init(origin: .youtube), distribution: publicBuild, adapter: [.seek], runtime: all), [])
    }
    func testCatalogItemIsNotTrackAndPageKeepsPartialState() throws {
        let provider = try ProviderID("youtube")
        let provenance = try Provenance(provider: provider, originalID: "dQw4w9WgXcQ")
        let item = CatalogItem(id: try CatalogID("youtube:video:dQw4w9WgXcQ"), kind: .video, title: "Title", provenance: provenance, videoID: try VideoID("dQw4w9WgXcQ"))
        let page = CatalogPage(items: [item], nextToken: "next", isComplete: false, source: provider, fetchedAt: Date(timeIntervalSince1970: 1))
        XCTAssertEqual(try JSONDecoder().decode(CatalogPage.self, from: JSONEncoder().encode(page)), page)
        XCTAssertFalse(page.isComplete)
    }
}
