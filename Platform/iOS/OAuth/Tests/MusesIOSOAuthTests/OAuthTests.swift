import XCTest
import MusesNetworking
@testable import MusesIOSOAuth

private final class MemoryStore: OAuthTokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: OAuthTokens?
    func load() throws -> OAuthTokens? { lock.lock(); defer { lock.unlock() }; return value }
    func save(_ tokens: OAuthTokens) throws { lock.lock(); defer { lock.unlock() }; value = tokens }
    func delete() throws { lock.lock(); defer { lock.unlock() }; value = nil }
}
private actor PrivateData: PrivateAccountData {
    var deleted = false
    func deletePrivateData() async throws { deleted = true }
}
private final class FailingStore: OAuthTokenStore, @unchecked Sendable {
    var deleteAttempted = false
    func load() throws -> OAuthTokens? { throw OAuthFailure.storage }
    func save(_ tokens: OAuthTokens) throws { throw OAuthFailure.storage }
    func delete() throws { deleteAttempted = true; throw OAuthFailure.storage }
}
private struct TokenHTTP: HTTPTransport {
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        if request.url?.path == "/revoke" { return HTTPResponse(status: 200, body: Data()) }
        return HTTPResponse(status: 200, body: Data(#"{"access_token":"fake-access","refresh_token":"fake-refresh","expires_in":3600}"#.utf8))
    }
}
private struct RevokeFailureHTTP: HTTPTransport {
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        if request.url?.path == "/revoke" { return HTTPResponse(status: 503, body: Data()) }
        return HTTPResponse(status: 200, body: Data(#"{"access_token":"fake-access","refresh_token":"fake-refresh","expires_in":3600}"#.utf8))
    }
}

final class OAuthTests: XCTestCase {
    func testTokenStoreFailuresStillAttemptPrivateCacheDeletion() async throws {
        let config = try OAuthConfiguration(clientID: "123.apps.googleusercontent.com", redirectURI: URL(string: "com.googleusercontent.apps.123:/oauth2redirect")!)
        for revoke in [true, false] {
            let store = FailingStore()
            let privateData = PrivateData()
            let client = OAuthClient(configuration: config, transport: TokenHTTP(), store: store, privateData: privateData)
            do {
                if revoke { try await client.revokeAndDelete() }
                else { try await client.deleteLocalAccount() }
                XCTFail("expected storage error")
            } catch { XCTAssertEqual(error as? OAuthFailure, .storage) }
            XCTAssertTrue(store.deleteAttempted)
            let deleted = await privateData.deleted
            XCTAssertTrue(deleted)
        }
    }
    func testAttemptPKCEAndCallback() throws {
        let config = try OAuthConfiguration(clientID: "123.apps.googleusercontent.com", redirectURI: URL(string: "com.googleusercontent.apps.123:/oauth2redirect")!)
        let attempt = try OAuthAttempt(configuration: config)
        let parts = URLComponents(url: attempt.authorizationURL, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(parts.queryItems?.first(where: { $0.name == "code_challenge_method" })?.value, "S256")
        XCTAssertEqual(try attempt.code(from: URL(string: "com.googleusercontent.apps.123:/oauth2redirect?code=abc&state=\(attempt.state)")!), "abc")
        XCTAssertThrowsError(try attempt.code(from: URL(string: "com.googleusercontent.apps.123:/oauth2redirect?code=abc&state=wrong")!))
    }
    func testExchangeAndRevokeDeletesPrivateData() async throws {
        let config = try OAuthConfiguration(clientID: "123.apps.googleusercontent.com", redirectURI: URL(string: "com.googleusercontent.apps.123:/oauth2redirect")!)
        let attempt = try OAuthAttempt(configuration: config)
        let store = MemoryStore()
        let privateData = PrivateData()
        let client = OAuthClient(configuration: config, transport: TokenHTTP(), store: store, privateData: privateData)
        try await client.complete(attempt, callback: URL(string: "com.googleusercontent.apps.123:/oauth2redirect?code=fake-code&state=\(attempt.state)")!)
        let access = try await client.accessToken()
        XCTAssertEqual(access, "fake-access")
        try await client.revokeAndDelete()
        XCTAssertNil(try store.load())
        let deleted = await privateData.deleted
        XCTAssertTrue(deleted)
    }
    func testFailedRemoteRevocationStillDeletesLocalData() async throws {
        let config = try OAuthConfiguration(clientID: "123.apps.googleusercontent.com", redirectURI: URL(string: "com.googleusercontent.apps.123:/oauth2redirect")!)
        let attempt = try OAuthAttempt(configuration: config)
        let store = MemoryStore()
        let privateData = PrivateData()
        let client = OAuthClient(configuration: config, transport: RevokeFailureHTTP(), store: store, privateData: privateData)
        try await client.complete(attempt, callback: URL(string: "com.googleusercontent.apps.123:/oauth2redirect?code=fake-code&state=\(attempt.state)")!)
        do { try await client.revokeAndDelete(); XCTFail("expected revoke error") }
        catch { XCTAssertEqual(error as? APIError, .server(status: 503)) }
        XCTAssertNil(try store.load())
        let deleted = await privateData.deleted
        XCTAssertTrue(deleted)
    }
}
