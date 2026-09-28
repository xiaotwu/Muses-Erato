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
private final class RevokedRefreshStore: OAuthTokenStore, @unchecked Sendable {
    let failsDeletion: Bool
    var deleteAttempted = false
    private var value: OAuthTokens? = OAuthTokens(accessToken: "expired", refreshToken: "revoked-refresh", expiresAt: .distantPast)
    init(failsDeletion: Bool) { self.failsDeletion = failsDeletion }
    func load() throws -> OAuthTokens? { value }
    func save(_ tokens: OAuthTokens) throws { XCTFail("Revoked refresh must not save tokens") }
    func delete() throws {
        deleteAttempted = true
        if failsDeletion { throw OAuthFailure.storage }
        value = nil
    }
}
private actor RefreshPrivateData: PrivateAccountData {
    let failsDeletion: Bool
    var deleteAttempted = false
    init(failsDeletion: Bool) { self.failsDeletion = failsDeletion }
    func deletePrivateData() async throws {
        deleteAttempted = true
        if failsDeletion { throw OAuthFailure.storage }
    }
}
private struct RevokedRefreshHTTP: HTTPTransport {
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        XCTAssertEqual(request.url?.path, "/token")
        return HTTPResponse(status: 400, body: Data(#"{"error":"invalid_grant"}"#.utf8))
    }
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
    func testRevokedRefreshAttemptsBothCleanupStepsAndReportsFailures() async throws {
        let config = try OAuthConfiguration(clientID: "123.apps.googleusercontent.com", redirectURI: URL(string: "com.googleusercontent.apps.123:/oauth2redirect")!)
        for failsStore in [false, true] {
            for failsCache in [false, true] {
                let store = RevokedRefreshStore(failsDeletion: failsStore)
                let privateData = RefreshPrivateData(failsDeletion: failsCache)
                let client = OAuthClient(configuration: config, transport: RevokedRefreshHTTP(), store: store, privateData: privateData)
                do { _ = try await client.accessToken(); XCTFail("Expected revoked or cleanup error") }
                catch { XCTAssertEqual(error as? OAuthFailure, failsStore || failsCache ? .storage : .revoked) }
                XCTAssertTrue(store.deleteAttempted)
                let cacheAttempted = await privateData.deleteAttempted
                XCTAssertTrue(cacheAttempted)
                if !failsStore { XCTAssertNil(try store.load()) }
            }
        }
    }

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

private actor DelayedTokenHTTP: HTTPTransport {
    let hold: String
    let delayedResult: HTTPResponse
    private(set) var requestCount = 0
    private var pending: CheckedContinuation<HTTPResponse, Never>?
    private var started: CheckedContinuation<Void, Never>?
    init(hold: String, revoked: Bool = false) {
        self.hold = hold
        delayedResult = revoked
            ? HTTPResponse(status: 400, body: Data(#"{"error":"invalid_grant"}"#.utf8))
            : HTTPResponse(status: 200, body: Data(#"{"access_token":"late-access","refresh_token":"late-refresh","expires_in":3600}"#.utf8))
    }
    func waitUntilStarted() async {
        if pending != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func release() { pending?.resume(returning: delayedResult); pending = nil }
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        if (hold == "revoke" && request.url?.path == "/revoke") || body.contains("grant_type=" + hold) {
            requestCount += 1
            if requestCount > 1 { return delayedResult }
            return await withCheckedContinuation {
                pending = $0; started?.resume(); started = nil
            }
        }
        if request.url?.path == "/revoke" { return HTTPResponse(status: 200, body: Data()) }
        return HTTPResponse(status: 200, body: Data(#"{"access_token":"new-access","refresh_token":"new-refresh","expires_in":3600}"#.utf8))
    }
}

extension OAuthTests {
    private func testConfiguration() throws -> OAuthConfiguration {
        try OAuthConfiguration(clientID: "123.apps.googleusercontent.com", redirectURI: URL(string: "com.googleusercontent.apps.123:/oauth2redirect")!)
    }
    private func callback(_ attempt: OAuthAttempt) -> URL {
        URL(string: "com.googleusercontent.apps.123:/oauth2redirect?code=fake-code&state=\(attempt.state)")!
    }
    func testLateRefreshCannotRestoreTokensAfterLocalDeletionOrRevoke() async throws {
        for revoke in [false, true] {
            let store = MemoryStore()
            try store.save(OAuthTokens(accessToken: "old", refreshToken: "old-refresh", expiresAt: .distantPast))
            let transport = DelayedTokenHTTP(hold: "refresh_token")
            let privateData = PrivateData()
            let client = OAuthClient(configuration: try testConfiguration(), transport: transport, store: store, privateData: privateData)
            let refresh = Task { try await client.accessToken() }
            await transport.waitUntilStarted()
            if revoke { try await client.revokeAndDelete() } else { try await client.deleteLocalAccount() }
            await transport.release()
            do { _ = try await refresh.value; XCTFail("Late refresh must be discarded") }
            catch { XCTAssertEqual(error as? OAuthFailure, .revoked) }
            XCTAssertNil(try store.load())
            let deleted = await privateData.deleted
            XCTAssertTrue(deleted)
        }
    }
    func testLateRevokedRefreshCannotDeleteNewLogin() async throws {
        let configuration = try testConfiguration()
        let store = MemoryStore()
        try store.save(OAuthTokens(accessToken: "old", refreshToken: "old-refresh", expiresAt: .distantPast))
        let transport = DelayedTokenHTTP(hold: "refresh_token", revoked: true)
        let client = OAuthClient(configuration: configuration, transport: transport, store: store, privateData: PrivateData())
        let refresh = Task { try await client.accessToken() }
        await transport.waitUntilStarted()
        let attempt = try OAuthAttempt(configuration: configuration)
        try await client.complete(attempt, callback: callback(attempt))
        await transport.release()
        do { _ = try await refresh.value; XCTFail("Old request must not be accepted") }
        catch { XCTAssertEqual(error as? OAuthFailure, .revoked) }
        XCTAssertEqual(try store.load()?.accessToken, "new-access")
        let token = try await client.accessToken()
        XCTAssertEqual(token, "new-access")
    }
    func testLateExchangeAfterDeletionCannotCreateCredentials() async throws {
        let configuration = try testConfiguration()
        let store = MemoryStore()
        let transport = DelayedTokenHTTP(hold: "authorization_code")
        let client = OAuthClient(configuration: configuration, transport: transport, store: store, privateData: PrivateData())
        let attempt = try OAuthAttempt(configuration: configuration)
        let url = callback(attempt)
        let exchange = Task { try await client.complete(attempt, callback: url) }
        await transport.waitUntilStarted()
        try await client.deleteLocalAccount()
        await transport.release()
        do { try await exchange.value; XCTFail("Exchange must not restore deleted credentials") }
        catch { XCTAssertEqual(error as? OAuthFailure, .revoked) }
        XCTAssertNil(try store.load())
    }
    func testPendingRemoteRevokeBlocksTokenUseAndNewExchange() async throws {
        let configuration = try testConfiguration()
        let store = MemoryStore()
        try store.save(OAuthTokens(accessToken: "old", refreshToken: "old-refresh", expiresAt: .distantFuture))
        let transport = DelayedTokenHTTP(hold: "revoke")
        let client = OAuthClient(configuration: configuration, transport: transport, store: store, privateData: PrivateData())
        let revoke = Task { try await client.revokeAndDelete() }
        await transport.waitUntilStarted()
        do { _ = try await client.accessToken(); XCTFail("Revoking credentials cannot be used") }
        catch { XCTAssertEqual(error as? OAuthFailure, .revoked) }
        let attempt = try OAuthAttempt(configuration: configuration)
        do { try await client.complete(attempt, callback: callback(attempt)); XCTFail("Login cannot overlap deletion") }
        catch { XCTAssertEqual(error as? OAuthFailure, .revoked) }
        await transport.release()
        try await revoke.value
        XCTAssertNil(try store.load())
        try await client.complete(attempt, callback: callback(attempt))
        let token = try await client.accessToken()
        XCTAssertEqual(token, "new-access", "A new user-initiated login after deletion is allowed")
    }
    func testCancelledRefreshCannotSaveResponse() async throws {
        let store = MemoryStore()
        try store.save(OAuthTokens(accessToken: "old", refreshToken: "old-refresh", expiresAt: .distantPast))
        let transport = DelayedTokenHTTP(hold: "refresh_token")
        let client = OAuthClient(configuration: try testConfiguration(), transport: transport, store: store, privateData: PrivateData())
        let refresh = Task { try await client.accessToken() }
        await transport.waitUntilStarted()
        refresh.cancel()
        await transport.release()
        do { _ = try await refresh.value; XCTFail("Cancelled response must not be saved") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(try store.load()?.accessToken, "old")
    }
    func testFailedTokenDeletionStillBlocksReuseInCurrentClient() async throws {
        let store = RevokedRefreshStore(failsDeletion: true)
        let client = OAuthClient(configuration: try testConfiguration(), transport: TokenHTTP(), store: store, privateData: PrivateData())
        do { try await client.deleteLocalAccount(); XCTFail("Expected storage failure") }
        catch { XCTAssertEqual(error as? OAuthFailure, .storage) }
        do { _ = try await client.accessToken(); XCTFail("Failed deletion cannot silently reuse credentials") }
        catch { XCTAssertEqual(error as? OAuthFailure, .revoked) }
        XCTAssertTrue(store.deleteAttempted)
    }
}

extension OAuthTests {
    func testConcurrentRefreshUsesOneProviderRequest() async throws {
        let store = MemoryStore()
        try store.save(OAuthTokens(accessToken: "old", refreshToken: "old-refresh", expiresAt: .distantPast))
        let transport = DelayedTokenHTTP(hold: "refresh_token")
        let client = OAuthClient(configuration: try testConfiguration(), transport: transport, store: store, privateData: PrivateData())
        let first = Task { try await client.accessToken() }
        await transport.waitUntilStarted()
        let second = Task { try await client.accessToken() }
        // Let the second caller enter the actor while the provider request is held.
        for _ in 0..<20 { await Task.yield() }
        await transport.release()
        let values = try await (first.value, second.value)
        XCTAssertEqual(values.0, "late-access")
        XCTAssertEqual(values.1, "late-access")
        let calls = await transport.requestCount
        XCTAssertEqual(calls, 1, "Concurrent refresh must not rotate the same refresh grant twice")
    }
}

private actor DelayedPrivateCleanup: PrivateAccountData {
    private var pending: CheckedContinuation<Void, Never>?
    private var started: CheckedContinuation<Void, Never>?
    private var calls = 0
    func waitUntilStarted() async {
        if pending != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func release() { pending?.resume(); pending = nil }
    func deletePrivateData() async throws {
        calls += 1
        if calls > 1 { return }
        await withCheckedContinuation {
            pending = $0; started?.resume(); started = nil
        }
    }
}

extension OAuthTests {
    func testDeletionDuringAccountReplacementCacheCleanupBlocksTokenSave() async throws {
        let configuration = try testConfiguration()
        let store = MemoryStore()
        try store.save(OAuthTokens(accessToken: "old", refreshToken: "old-refresh", expiresAt: .distantFuture))
        let cleanup = DelayedPrivateCleanup()
        let client = OAuthClient(configuration: configuration, transport: TokenHTTP(), store: store, privateData: cleanup)
        let attempt = try OAuthAttempt(configuration: configuration)
        let url = callback(attempt)
        let exchange = Task { try await client.complete(attempt, callback: url) }
        await cleanup.waitUntilStarted()
        try await client.deleteLocalAccount()
        await cleanup.release()
        do { try await exchange.value; XCTFail("Deletion during cache cleanup must invalidate the exchange") }
        catch { XCTAssertEqual(error as? OAuthFailure, .revoked) }
        XCTAssertNil(try store.load())
    }
}

private actor RetryPrivateCleanup: PrivateAccountData {
    private(set) var calls = 0
    func deletePrivateData() async throws {
        calls += 1
        if calls == 1 { throw OAuthFailure.storage }
    }
}

extension OAuthTests {
    func testNewLoginRetriesFailedCacheCleanupEvenWhenTokensWereDeleted() async throws {
        let configuration = try testConfiguration()
        let store = MemoryStore()
        let cleanup = RetryPrivateCleanup()
        let client = OAuthClient(configuration: configuration, transport: TokenHTTP(), store: store, privateData: cleanup)
        do { try await client.deleteLocalAccount(); XCTFail("Expected initial cache failure") }
        catch { XCTAssertEqual(error as? OAuthFailure, .storage) }
        XCTAssertNil(try store.load())
        let attempt = try OAuthAttempt(configuration: configuration)
        try await client.complete(attempt, callback: callback(attempt))
        let calls = await cleanup.calls
        XCTAssertEqual(calls, 2)
        let token = try await client.accessToken()
        XCTAssertEqual(token, "fake-access")
    }
}
