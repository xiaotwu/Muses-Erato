import XCTest
import MusesNetworking
@testable import MusesCatalog

private actor RecordingHTTP: HTTPTransport {
    var requests: [URLRequest] = []
    let body: Data
    init(fixture: String) throws { body = try Data(contentsOf: Bundle.module.url(forResource: fixture, withExtension: "json")!) }
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        return HTTPResponse(status: 200, body: body)
    }
    func queries() -> [[String: String]] {
        requests.map { Dictionary(uniqueKeysWithValues: URLComponents(url: $0.url!, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value ?? "") }) }
    }
    func capturedRequests() -> [URLRequest] { requests }
    func authHeaders() -> [String?] { requests.map { $0.value(forHTTPHeaderField: "Authorization") } }
}
private struct TestToken: CatalogCredential { func accessToken() async throws -> String { "fixture-token" } }
private actor SuspendedHTTP: HTTPTransport {
    var response: CheckedContinuation<HTTPResponse, Never>?
    var started: CheckedContinuation<Void, Never>?
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        await withCheckedContinuation { continuation in
            response = continuation; started?.resume(); started = nil
        }
    }
    func waitUntilStarted() async {
        if response != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func finish() { response?.resume(returning: HTTPResponse(status: 200, body: Data(#"{"items":[]}"#.utf8))); response = nil }
}

final class BrowserTests: XCTestCase {
    func testIOSRestrictedKeyIdentityHeaderWithoutSpoofedReferer() async throws {
        let http = try RecordingHTTP(fixture: "channel")
        let identity = try XCTUnwrap(CatalogClientIdentity(iOSBundleID: "com.example.fixture"))
        let catalog = YouTubeDataCatalog(apiKey: "fixture", credential: TestToken(), transport: http, clientIdentity: identity)
        _ = try await catalog.channel(id: "UCabcdefghijklmnopqrstuv")
        _ = try await catalog.myPlaylists()
        let requests = await http.capturedRequests()
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "X-Ios-Bundle-Identifier"), "com.example.fixture")
        XCTAssertNil(requests[0].value(forHTTPHeaderField: "Referer"))
        XCTAssertNil(requests[0].value(forHTTPHeaderField: "Origin"))
        XCTAssertNil(requests[1].value(forHTTPHeaderField: "X-Ios-Bundle-Identifier"))
        XCTAssertEqual(requests[1].value(forHTTPHeaderField: "Authorization"), "Bearer fixture-token")
        XCTAssertNil(CatalogClientIdentity(iOSBundleID: "com.example\r\nInjected: value"))
    }
    func testChannelUploadsAndHandleUseCheapChannelsEndpoint() async throws {
        let http = try RecordingHTTP(fixture: "channel")
        let catalog = YouTubeDataCatalog(apiKey: "fixture", transport: http)
        let page = try await catalog.channel(id: "@fixture", isHandle: true)
        XCTAssertEqual(page.items.first?.uploadsPlaylistID, "UUabcdefghijklmnopqrstuv")
        XCTAssertEqual(page.items.first?.description, "Official channel description")
        XCTAssertNotNil(page.items.first?.fetchedAt)
        let queries = await http.queries()
        XCTAssertEqual(queries[0]["forHandle"], "@fixture")
        XCTAssertEqual(queries[0]["part"], "snippet,contentDetails")
        let counts = await catalog.requestCounts()
        XCTAssertNil(counts.calls["search"])
    }
    func testPlaylistResourceIDsAndAuthorizedReadEvenWhenKeyExists() async throws {
        let http = try RecordingHTTP(fixture: "playlist-items")
        let catalog = YouTubeDataCatalog(apiKey: "fixture-key", credential: TestToken(), transport: http)
        let page = try await catalog.playlist(id: "PLfixture", pageToken: "second", authorized: true)
        XCTAssertEqual(page.items.map(\.id), ["abcdefghijk", "lmnopqrstuv"])
        XCTAssertEqual(page.nextPageToken, "next-videos")
        XCTAssertEqual(page.items.first?.listEntryID, "playlist-entry-1")
        let queries = await http.queries(), auth = await http.authHeaders()
        XCTAssertEqual(queries[0]["pageToken"], "second")
        XCTAssertNil(queries[0]["key"])
        XCTAssertEqual(auth[0], "Bearer fixture-token")
    }
    func testSearchKindsAndBatchDeduplication() async throws {
        let http = try RecordingHTTP(fixture: "channel")
        let catalog = YouTubeDataCatalog(apiKey: "fixture", transport: http)
        _ = try await catalog.search("mix", kind: .playlist)
        _ = try await catalog.search("mix", kind: .channel)
        _ = try await catalog.videos(["bbbbbbbbbbb", "aaaaaaaaaaa", "bbbbbbbbbbb"])
        _ = try await catalog.videos(["aaaaaaaaaaa", "bbbbbbbbbbb"])
        let queries = await http.queries()
        XCTAssertEqual(queries.count, 3)
        XCTAssertEqual(queries[0]["type"], "playlist")
        XCTAssertNil(queries[0]["videoEmbeddable"])
        XCTAssertEqual(queries[1]["type"], "channel")
        XCTAssertEqual(queries[2]["id"], "aaaaaaaaaaa,bbbbbbbbbbb")
    }
    func testNoNextSearchWithoutActionAndBudgetRetainsCachedFirstPage() async throws {
        let http = try RecordingHTTP(fixture: "search-page-1")
        let catalog = YouTubeDataCatalog(apiKey: "fixture", transport: http, budget: RequestBudget(searchCallsPerDay: 1, otherUnitsPerDay: 5))
        let first = try await catalog.search("music")
        XCTAssertNotNil(first.nextPageToken)
        let queries = await http.queries()
        XCTAssertEqual(queries.count, 1)
        do { _ = try await catalog.search("music", pageToken: first.nextPageToken); XCTFail("Expected budget limit") }
        catch { XCTAssertEqual(error as? APIError, .quotaExceeded(reason: "localSearchBudget")) }
        let cached = try await catalog.search("music")
        XCTAssertEqual(cached, first)
    }
    func testPrivateInvalidationDiscardsInFlightResponse() async throws {
        let http = SuspendedHTTP()
        let catalog = YouTubeDataCatalog(credential: TestToken(), transport: http)
        let task = Task { try await catalog.myPlaylists() }
        await http.waitUntilStarted()
        await catalog.clearPrivateCache()
        await http.finish()
        do { _ = try await task.value; XCTFail("Stale private data must be discarded") }
        catch { XCTAssertTrue(error is CancellationError) }
    }
    func testLinks() {
        XCTAssertEqual(YouTubeCatalogLink.parse("https://youtube.com/playlist?list=PLabc"), .playlist("PLabc"))
        XCTAssertEqual(YouTubeCatalogLink.parse("https://youtube.com/@music"), .handle("@music"))
        XCTAssertEqual(YouTubeCatalogLink.parse("https://youtube.com/channel/UCabcdefghijklmnopqrstuv"), .channel("UCabcdefghijklmnopqrstuv"))
        XCTAssertEqual(YouTubeCatalogLink.parse("https://music.youtube.com/watch?v=abcdefghijk&list=PLabc"), .video("abcdefghijk"))
        for bad in ["https://youtube.com.evil.test/@a", "http://youtube.com/@a", "https://user@youtube.com/@a", "https://youtu.be/playlist?list=PLabc", "https://youtube.com/channel/bad", "https://youtube.com/playlist?list="] {
            XCTAssertNil(YouTubeCatalogLink.parse(bad), bad)
        }
    }
}

@MainActor final class PagerTests: XCTestCase {
    private let first = CatalogItem(kind: .video, id: "abcdefghijk", title: "First", channelID: nil, thumbnailURL: nil)
    func testExplicitPaginationRetryDedupeAndRepeatedCursor() async {
        let pager = CatalogPager()
        XCTAssertFalse(pager.loaded)
        await pager.load { token in
            XCTAssertNil(token)
            return CatalogPage(items: [first], nextPageToken: "next")
        }
        await pager.load { token in XCTAssertEqual(token, "next"); throw APIError.network }
        XCTAssertEqual(pager.items, [first]); XCTAssertEqual(pager.nextPageToken, "next")
        XCTAssertNotNil(pager.error)
        await pager.load { token in
            XCTAssertEqual(token, "next")
            return CatalogPage(items: [first], nextPageToken: "next")
        }
        XCTAssertEqual(pager.items.count, 1); XCTAssertNil(pager.nextPageToken)
        await pager.load { _ in XCTFail("Completed pager must not fetch"); throw APIError.network }
    }
    func testRepeatedVideoInPlaylistKeepsDistinctEntries() async {
        let pager = CatalogPager()
        let a = CatalogItem(kind: .video, id: "abcdefghijk", title: "Same video", channelID: nil, thumbnailURL: nil, listEntryID: "entryA")
        let b = CatalogItem(kind: .video, id: "abcdefghijk", title: "Same video", channelID: nil, thumbnailURL: nil, listEntryID: "entryB")
        await pager.load { _ in CatalogPage(items: [a], nextPageToken: "next") }
        await pager.load { _ in CatalogPage(items: [a, b], nextPageToken: nil) }
        XCTAssertEqual(pager.items, [a, b])
    }
    func testResetDuringLoadAndDuplicateTap() async {
        let pager = CatalogPager()
        var continuation: CheckedContinuation<CatalogPage, Never>?
        let task = Task { await pager.load { _ in await withCheckedContinuation { continuation = $0 } } }
        while continuation == nil { await Task.yield() }
        await pager.load { _ in XCTFail("Duplicate request"); throw APIError.network }
        pager.reset()
        continuation?.resume(returning: CatalogPage(items: [first], nextPageToken: "old"))
        await task.value
        XCTAssertTrue(pager.items.isEmpty); XCTAssertFalse(pager.loaded); XCTAssertFalse(pager.loading)
    }
}
