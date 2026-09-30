import XCTest
import MusesNetworking
@testable import MusesCatalog

private actor ConfigurationFailureHTTP: HTTPTransport {
    let reason: String
    let status: Int
    var calls = 0
    init(reason: String, status: Int) { self.reason = reason; self.status = status }
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        calls += 1
        // The actual configured identity must reach Google unchanged, even when blocked.
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier"), "fixture.quality.bundle")
        return HTTPResponse(status: status, body: Data("{\"error\":{\"message\":\"secret-fixture-message\",\"errors\":[{\"reason\":\"forbidden\"}],\"details\":[{\"@type\":\"type.googleapis.com/google.rpc.ErrorInfo\",\"reason\":\"\(reason)\"}]}}".utf8))
    }
}
private struct ConfigurationSavedIndex: LocalCatalogIndex {
    func searchSaved(query: String, limit: Int) async throws -> [CatalogItem] {
        [CatalogItem(kind: .video, id: "abcdefghijk", title: "Saved", channelID: nil, thumbnailURL: nil)]
    }
    func recentSaved(limit: Int) async throws -> [CatalogItem] { [] }
}

final class ConfigurationFailureTests: XCTestCase {
    func testConfigurationFailuresPropagateThroughSearchAndPlaybackStatusWithoutRetry() async throws {
        for (reason, status, expected) in [
            ("API_KEY_IOS_APP_BLOCKED", 403, APIConfigurationIssue.appNotAuthorized),
            ("SERVICE_DISABLED", 403, .serviceDisabled),
            ("API_KEY_INVALID", 400, .invalidKey)
        ] {
            let transport = ConfigurationFailureHTTP(reason: reason, status: status)
            let catalog = YouTubeDataCatalog(apiKey: "fixture-key", transport: transport,
                clientIdentity: CatalogClientIdentity(iOSBundleID: "fixture.quality.bundle"))
            do { _ = try await catalog.search("test"); XCTFail("Expected search configuration failure") }
            catch {
                XCTAssertEqual(error as? APIError, .configuration(expected))
                XCTAssertTrue(error.localizedDescription.contains("Google API configuration"))
                XCTAssertFalse(error.localizedDescription.contains("secret-fixture"))
            }
            do { _ = try await catalog.videoEmbeddingStatus("abcdefghijk"); XCTFail("Configuration failure must not grant playback permission") }
            catch { XCTAssertEqual(error as? APIError, .configuration(expected)) }
            let calls = await transport.calls
            XCTAssertEqual(calls, 2, "Configuration failures must not auto-retry")
        }
    }

    func testBlockedAppPreservesLocalDiscoveryAndActionableOnlineError() async throws {
        let transport = ConfigurationFailureHTTP(reason: "API_KEY_IOS_APP_BLOCKED", status: 403)
        let catalog = YouTubeDataCatalog(apiKey: "fixture-key", transport: transport,
            clientIdentity: CatalogClientIdentity(iOSBundleID: "fixture.quality.bundle"))
        let result = try await CatalogDiscovery(remote: catalog, local: ConfigurationSavedIndex()).search("saved", includeOnline: true)
        XCTAssertEqual(result.saved.count, 1)
        XCTAssertEqual(result.onlineError as? APIError, .configuration(.appNotAuthorized))
        XCTAssertTrue(result.onlineError?.localizedDescription.contains("not authorized") == true)
    }
}
