import XCTest
import MusesNetworking
@testable import MusesCatalog

private struct FakeHTTP: HTTPTransport {
    let body: Data
    func send(_ request: URLRequest) async throws -> HTTPResponse { HTTPResponse(status: 200, body: body) }
}
private actor PagingHTTP: HTTPTransport {
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        let second = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.contains { $0.name == "pageToken" && $0.value == "second" } ?? false
        let name = second ? "search-page-2" : "search-page-1"
        let url = Bundle.module.url(forResource: name, withExtension: "json")!
        return HTTPResponse(status: 200, body: try Data(contentsOf: url))
    }
}
private struct QuotaHTTP: HTTPTransport {
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        HTTPResponse(status: 403, body: try Data(contentsOf: Bundle.module.url(forResource: "quota", withExtension: "json")!))
    }
}
private struct SavedIndex: LocalCatalogIndex {
    func searchSaved(query: String, limit: Int) async throws -> [CatalogItem] { [CatalogItem(kind: .video, id: "abcdefghijk", title: "Saved", channelID: nil, thumbnailURL: nil)] }
    func recentSaved(limit: Int) async throws -> [CatalogItem] { [] }
}
private struct FakeCredential: CatalogCredential {
    func accessToken() async throws -> String { "fake-token" }
}
private struct OAuthOnlyHTTP: HTTPTransport {
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fake-token")
        XCTAssertFalse(request.url!.absoluteString.contains("key="))
        return HTTPResponse(status: 200, body: Data(#"{"items":[]}"#.utf8))
    }
}
final class CatalogTests: XCTestCase {
    func testSignedInSearchWorksWithoutPublicAPIKey() async throws {
        let catalog = YouTubeDataCatalog(credential: FakeCredential(), transport: OAuthOnlyHTTP())
        _ = try await catalog.search("music")
        let before = await catalog.requestCounts()
        XCTAssertEqual(before.calls["search"], 1)
        await catalog.clearPrivateCache()
        _ = try await catalog.search("music")
        let after = await catalog.requestCounts()
        XCTAssertEqual(after.calls["search"], 2)
    }
    func testSearchPage() async throws {
        let data = Data(#"{"nextPageToken":"next","items":[{"id":{"kind":"youtube#video","videoId":"abcdefghijk"},"snippet":{"title":"Title","channelId":"UC123"}}]}"#.utf8)
        let catalog = YouTubeDataCatalog(apiKey: "fake", transport: FakeHTTP(body: data))
        let page = try await catalog.search("test")
        XCTAssertEqual(page.items.first?.id, "abcdefghijk")
        XCTAssertEqual(page.nextPageToken, "next")
        XCTAssertFalse(page.complete)
    }
    func testOnDemandSecondPageAndCacheBudget() async throws {
        let catalog = YouTubeDataCatalog(apiKey: "fake", transport: PagingHTTP())
        let first = try await catalog.search("music")
        XCTAssertEqual(first.nextPageToken, "second")
        let firstCounts = await catalog.requestCounts()
        XCTAssertEqual(firstCounts.calls["search"], 1)
        let second = try await catalog.search("music", pageToken: first.nextPageToken)
        XCTAssertEqual(second.items.first?.title, "Second")
        XCTAssertTrue(second.complete)
        _ = try await catalog.search("music")
        let finalCounts = await catalog.requestCounts()
        XCTAssertEqual(finalCounts.calls["search"], 2)
    }
    func testQuotaPreservesLocalSearch() async throws {
        let catalog = YouTubeDataCatalog(apiKey: "fake", transport: QuotaHTTP())
        let result = try await CatalogDiscovery(remote: catalog, local: SavedIndex()).search("saved", includeOnline: true)
        XCTAssertEqual(result.saved.count, 1)
        XCTAssertEqual(result.onlineError as? APIError, .quotaExceeded(reason: "quotaExceeded"))
    }
    func testPrivateCacheIsPurged() async throws {
        let data = Data(#"{"items":[{"id":"PL123","snippet":{"title":"Mine"}}]}"#.utf8)
        let catalog = YouTubeDataCatalog(credential: FakeCredential(), transport: FakeHTTP(body: data))
        _ = try await catalog.myPlaylists()
        _ = try await catalog.myPlaylists()
        let before = await catalog.requestCounts()
        XCTAssertEqual(before.calls["playlists"], 1)
        await catalog.clearPrivateCache()
        _ = try await catalog.myPlaylists()
        let after = await catalog.requestCounts()
        XCTAssertEqual(after.calls["playlists"], 2)
    }
}

private actor ContentStatusHTTP: HTTPTransport {
    let statuses: [String]
    var calls = 0
    init(_ statuses: [String]) { self.statuses = statuses }
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        let query = Dictionary(uniqueKeysWithValues: URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(query["part"], "id,snippet,status")
        XCTAssertEqual(query["id"], "abcdefghijk")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier"), "com.xiaotwu.muses.erato")
        let status = statuses[min(calls, statuses.count - 1)]
        calls += 1
        return HTTPResponse(status: 200, body: Data(("{\"items\":[{\"id\":\"abcdefghijk\",\"snippet\":{\"title\":\"Video\"},\"status\":" + status + "}]}").utf8))
    }
}

extension CatalogTests {
    func testEmbeddingStatusIsFreshAndNeverInfersMissingFields() async throws {
        let transport = ContentStatusHTTP([
            #"{"madeForKids":false,"embeddable":true}"#,
            #"{"madeForKids":true,"embeddable":true}"#,
            #"{"embeddable":true}"#,
            #"{"madeForKids":false}"#,
            #"{"madeForKids":false,"embeddable":false}"#
        ])
        let catalog = YouTubeDataCatalog(apiKey: "fake", transport: transport,
            clientIdentity: CatalogClientIdentity(iOSBundleID: "com.xiaotwu.muses.erato"))
        for expected in [VideoEmbeddingStatus.permitted, .madeForKids, .unknown, .unknown, .notEmbeddable] {
            let actual = try await catalog.videoEmbeddingStatus("abcdefghijk")
            XCTAssertEqual(actual, expected)
        }
        let counts = await catalog.requestCounts()
        XCTAssertEqual(counts.calls["videos"], 5, "A previous allowed result must not hide a changed status")
    }

    func testMissingWrongAndDuplicateVideoCannotGrantEmbedding() async throws {
        for body in [
            #"{"items":[]}"#,
            #"{"items":[{"id":"lmnopqrstuv","snippet":{"title":"Other"},"status":{"madeForKids":false,"embeddable":true}}]}"#,
            #"{"items":[{"id":"abcdefghijk","snippet":{"title":"One"},"status":{"madeForKids":false,"embeddable":true}},{"id":"abcdefghijk","snippet":{"title":"Two"},"status":{"madeForKids":false,"embeddable":true}}]}"#
        ] {
            let catalog = YouTubeDataCatalog(apiKey: "fake", transport: FakeHTTP(body: Data(body.utf8)))
            let status = try await catalog.videoEmbeddingStatus("abcdefghijk")
            XCTAssertEqual(status, .unknown)
        }
    }
}
