import XCTest
import MusesNetworking
@testable import MusesCatalog

final class PlaylistImportTests: XCTestCase {
    func testMusicLinkAndExplicitPagesRetainRepeatedVideos() throws {
        XCTAssertEqual(YouTubeCatalogLink.parse("https://music.youtube.com/playlist?list=PLexample&si=share"), .playlist("PLexample"))
        XCTAssertNil(YouTubeCatalogLink.parse("https://music.youtube.com.evil.test/playlist?list=PLexample"))
        var draft = PlaylistImportDraft()
        let a = CatalogItem(kind: .video, id: "dQw4w9WgXcQ", title: "temporary", channelID: nil, thumbnailURL: nil, listEntryID: "entry1")
        let b = CatalogItem(kind: .video, id: a.id, title: "temporary", channelID: nil, thumbnailURL: nil, listEntryID: "entry2")
        try draft.append(.init(items: [a], nextPageToken: "page2"))
        XCTAssertFalse(draft.complete)
        try draft.append(.init(items: [b], nextPageToken: nil))
        XCTAssertTrue(draft.complete)
        XCTAssertEqual(draft.items.map(\.id), [a.id, a.id])
    }
    func testInconsistentPageCannotBecomeCompleteOrMutateDraft() throws {
        var draft = PlaylistImportDraft()
        try draft.append(.init(items: [], nextPageToken: "loop"))
        XCTAssertThrowsError(try draft.append(.init(items: [], nextPageToken: "loop")))
        XCTAssertFalse(draft.complete)
        XCTAssertEqual(draft.nextPageToken, "loop")
        let malformed = CatalogItem(kind: .video, id: "bad", title: "bad", channelID: nil, thumbnailURL: nil)
        XCTAssertThrowsError(try draft.append(.init(items: [malformed], nextPageToken: nil)))
        XCTAssertFalse(draft.complete)
    }
}

private struct ImportCredential: CatalogCredential {
    func accessToken() async throws -> String { "test-account" }
}
private actor ImportTransport: HTTPTransport {
    var captured: [URLRequest] = []
    let malformed: Bool
    init(malformed: Bool = false) { self.malformed = malformed }
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        captured.append(request)
        let body = malformed ? #"{"items":[{"id":"missing-video","snippet":{"title":"Unavailable"}}]}"# : #"{"items":[],"nextPageToken":"next"}"#
        return HTTPResponse(status: 200, body: Data(body.utf8))
    }
    func requests() -> [URLRequest] { captured }
}
extension PlaylistImportTests {
    func testOwnedAccountPlaylistsUseOAuthAndExplicitCursor() async throws {
        let transport = ImportTransport()
        let catalog = YouTubeDataCatalog(apiKey: "unused", credential: ImportCredential(), transport: transport)
        _ = try await catalog.myPlaylists()
        _ = try await catalog.myPlaylists(pageToken: "next")
        let requests = await transport.requests()
        XCTAssertEqual(requests.count, 2)
        for request in requests {
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-account")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            XCTAssertTrue(query.contains(URLQueryItem(name: "mine", value: "true")))
            XCTAssertFalse(query.contains { $0.name == "key" })
        }
        XCTAssertTrue(requests[1].url!.absoluteString.contains("pageToken=next"))
    }
    func testMissingPlaylistResourceFailsRatherThanSilentlyDroppingEntry() async {
        let catalog = YouTubeDataCatalog(apiKey: "fixture", transport: ImportTransport(malformed: true))
        do { _ = try await catalog.playlist(id: "PLbroken"); XCTFail("Incomplete playlist must fail") }
        catch { XCTAssertTrue(error is PlaylistImportError) }
    }
}
