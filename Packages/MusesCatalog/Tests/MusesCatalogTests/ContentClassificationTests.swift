import XCTest
import MusesNetworking
@testable import MusesCatalog

private actor CategoryHTTP: HTTPTransport {
    let body: String
    var calls = 0
    init(_ body: String) { self.body = body }
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        calls += 1
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertTrue(query?.contains { $0.name == "part" && $0.value?.contains("snippet") == true } == true)
        return HTTPResponse(status: 200, body: Data(body.utf8))
    }
}
final class ContentClassificationTests: XCTestCase {
    func testVideoCategoryIsStructuredAndNeverGuessedFromTitleOrChannel() async throws {
        for (category, expected) in [("10", CatalogItem.ContentKind.music), ("22", .video)] {
            let http = CategoryHTTP("{\"items\":[{\"id\":\"abcdefghijk\",\"snippet\":{\"title\":\"Music - Official Song\",\"channelTitle\":\"Artist - Topic\",\"categoryId\":\"\(category)\"}}]}")
            let catalog = YouTubeDataCatalog(apiKey: "fixture", transport: http)
            let page = try await catalog.videos(["abcdefghijk"])
            XCTAssertEqual(page.items.first?.contentKind, expected)
            let calls = await http.calls
            XCTAssertEqual(calls, 1)
        }
        for categoryField in ["", ",\"categoryId\":null", ",\"categoryId\":10", ",\"categoryId\":true", ",\"categoryId\":\"\"", ",\"categoryId\":\"music\"", ",\"categoryId\":\"0\"", ",\"categoryId\":\"-10\""] {
            let http = CategoryHTTP("{\"items\":[{\"id\":\"abcdefghijk\",\"snippet\":{\"title\":\"Official Music\",\"channelTitle\":\"Artist - Topic\"\(categoryField)}}]}")
            let page = try await YouTubeDataCatalog(apiKey: "fixture", transport: http).videos(["abcdefghijk"])
            XCTAssertNil(page.items.first?.contentKind)
        }
    }
    func testFreshPlaybackLookupReturnsPermissionAndClassificationInOneRequest() async throws {
        let http = CategoryHTTP(#"{"items":[{"id":"abcdefghijk","snippet":{"title":"Song","categoryId":"10"},"status":{"madeForKids":false,"embeddable":true}}]}"#)
        let catalog = YouTubeDataCatalog(apiKey: "fixture", transport: http)
        let metadata = try await catalog.videoPlaybackMetadata("abcdefghijk")
        XCTAssertEqual(metadata.embeddingStatus, .permitted)
        XCTAssertEqual(metadata.contentKind, .music)
        let calls = await http.calls
        XCTAssertEqual(calls, 1)
        let legacyStatus = try await catalog.videoEmbeddingStatus("abcdefghijk")
        XCTAssertEqual(legacyStatus, .permitted)
        let freshCalls = await http.calls
        XCTAssertEqual(freshCalls, 2, "Each permission check stays fresh")
    }
    func testWrongOrDuplicateVideoCannotSupplyPlaybackClassification() async throws {
        for body in [
            #"{"items":[]}"#,
            #"{"items":[{"id":"lmnopqrstuv","snippet":{"title":"Other","categoryId":"10"}}]}"#,
            #"{"items":[{"id":"abcdefghijk","snippet":{"title":"One","categoryId":"10"}},{"id":"abcdefghijk","snippet":{"title":"Two","categoryId":"10"}}]}"#
        ] {
            let result = try await YouTubeDataCatalog(apiKey: "fixture", transport: CategoryHTTP(body)).videoPlaybackMetadata("abcdefghijk")
            XCTAssertEqual(result.embeddingStatus, .unknown)
            XCTAssertNil(result.contentKind)
        }
    }
    func testNonVideoAndOldCatalogPayloadDoNotAcquireClassification() async throws {
        let http = CategoryHTTP(#"{"items":[{"id":"UC123","snippet":{"title":"Music","categoryId":"10"}}]}"#)
        let page = try await YouTubeDataCatalog(apiKey: "fixture", transport: http).channel(id: "UC123")
        XCTAssertNil(page.items.first?.contentKind)
        let item = CatalogItem(kind: .video, id: "abcdefghijk", title: "Music", channelID: nil, thumbnailURL: nil)
        let restored = try JSONDecoder().decode(CatalogItem.self, from: JSONEncoder().encode(item))
        XCTAssertNil(restored.contentKind)
    }
}
