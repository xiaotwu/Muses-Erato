import Foundation
import XCTest
import MusesNetworking
@testable import MusesIOSOAuth

private final class RetryTokenStore: OAuthTokenStore, @unchecked Sendable {
    var tokens: OAuthTokens? = OAuthTokens(accessToken: "old-access", refreshToken: "old-refresh", expiresAt: .distantFuture)
    var fail = true
    var loads = 0
    var deletions = 0
    func load() throws -> OAuthTokens? { loads += 1; return tokens }
    func save(_ value: OAuthTokens) throws { tokens = value }
    func delete() throws {
        deletions += 1
        if fail { throw OAuthFailure.storage }
        tokens = nil
    }
}
private actor CleanupData: PrivateAccountData {
    var fail = false
    var calls = 0
    func setFailure(_ value: Bool) { fail = value }
    func deletePrivateData() async throws {
        calls += 1
        if fail { throw OAuthFailure.storage }
    }
}
private actor HoldingCleanup: PrivateAccountData {
    private var started = false
    private var waiter: CheckedContinuation<Void, Never>?
    func deletePrivateData() async throws {
        started = true
        await withCheckedContinuation { waiter = $0 }
    }
    func waitUntilStarted() async { while !started { await Task.yield() } }
    func release() { waiter?.resume(); waiter = nil }
}
private actor NoNetwork: HTTPTransport {
    var calls = 0
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        calls += 1
        XCTFail("Cleanup startup must not send credentials to Google")
        throw OAuthFailure.invalidToken
    }
}
private struct JournalFailure: OAuthCleanupJournal {
    enum Stage { case begin, finish }
    let stage: Stage
    func isPending() throws -> Bool { true }
    func begin() throws { if stage == .begin { throw OAuthFailure.storage } }
    func finish() throws { if stage == .finish { throw OAuthFailure.storage } }
}

final class OAuthCleanupJournalTests: XCTestCase {
    private func marker() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appending(path: "cleanup.json")
    }
    private func config() throws -> OAuthConfiguration {
        try OAuthConfiguration(clientID: "123.apps.googleusercontent.com", redirectURI: URL(string: "com.googleusercontent.apps.123:/oauth2redirect")!)
    }
    func testMarkerRoundTripContainsNoTokensAndRejectsCorruptOrFutureVersion() throws {
        let url = try marker()
        let journal = FileOAuthCleanupJournal(url: url)
        XCTAssertFalse(try journal.isPending())
        try journal.begin()
        XCTAssertTrue(try FileOAuthCleanupJournal(url: url).isPending())
        let value = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        XCTAssertEqual(Set(value.keys), ["version", "pending"])
        try journal.finish()
        XCTAssertFalse(try FileOAuthCleanupJournal(url: url).isPending())
        for text in ["broken", #"{"version":99,"pending":false}"#] {
            try Data(text.utf8).write(to: url)
            XCTAssertThrowsError(try journal.isPending()) { XCTAssertEqual($0 as? OAuthFailure, .storage) }
        }
    }
    func testNewClientDeletesSurvivingTokensBeforeLoadingOrRequestingAnything() async throws {
        let url = try marker()
        let store = RetryTokenStore()
        let data = CleanupData()
        let network = NoNetwork()
        let first = OAuthClient(configuration: try config(), transport: network, store: store, privateData: data, cleanupJournal: FileOAuthCleanupJournal(url: url))
        do { try await first.deleteLocalAccount(); XCTFail("Expected deletion failure") }
        catch { XCTAssertEqual(error as? OAuthFailure, .storage) }
        XCTAssertTrue(try FileOAuthCleanupJournal(url: url).isPending())
        XCTAssertNotNil(store.tokens)
        let restarted = OAuthClient(configuration: try config(), transport: network, store: store, privateData: data, cleanupJournal: FileOAuthCleanupJournal(url: url))
        do { _ = try await restarted.accessToken(); XCTFail("Failed retry must not use surviving tokens") }
        catch { XCTAssertEqual(error as? OAuthFailure, .storage) }
        XCTAssertEqual(store.loads, 0)
        XCTAssertTrue(try FileOAuthCleanupJournal(url: url).isPending())
        store.fail = false
        let resumed = try await restarted.resumePendingCleanup()
        XCTAssertTrue(resumed)
        XCTAssertNil(store.tokens)
        XCTAssertFalse(try FileOAuthCleanupJournal(url: url).isPending())
        let calls = await network.calls
        XCTAssertEqual(calls, 0)
        do { _ = try await restarted.accessToken(); XCTFail("Cleanup does not sign in again") }
        catch { XCTAssertEqual(error as? OAuthFailure, .revoked) }
    }
    func testCacheFailurePreservesPendingMarkerAfterTokenDeletion() async throws {
        let url = try marker()
        let store = RetryTokenStore(); store.fail = false
        let data = CleanupData(); await data.setFailure(true)
        let client = OAuthClient(configuration: try config(), transport: NoNetwork(), store: store, privateData: data, cleanupJournal: FileOAuthCleanupJournal(url: url))
        do { try await client.deleteLocalAccount(); XCTFail("Expected cache failure") }
        catch { XCTAssertEqual(error as? OAuthFailure, .storage) }
        XCTAssertNil(store.tokens)
        XCTAssertTrue(try FileOAuthCleanupJournal(url: url).isPending())
        await data.setFailure(false)
        let restarted = OAuthClient(configuration: try config(), transport: NoNetwork(), store: store, privateData: data, cleanupJournal: FileOAuthCleanupJournal(url: url))
        let resumed = try await restarted.resumePendingCleanup()
        XCTAssertTrue(resumed)
        XCTAssertFalse(try FileOAuthCleanupJournal(url: url).isPending())
    }
    func testCorruptMarkerBlocksTokenReadsAndNewExchange() async throws {
        let url = try marker()
        try Data("corrupt".utf8).write(to: url)
        let store = RetryTokenStore()
        let network = NoNetwork()
        let configuration = try config()
        let client = OAuthClient(configuration: configuration, transport: network, store: store, privateData: CleanupData(), cleanupJournal: FileOAuthCleanupJournal(url: url))
        do { _ = try await client.accessToken(); XCTFail("Corrupt intent must fail closed") }
        catch { XCTAssertEqual(error as? OAuthFailure, .storage) }
        let attempt = try OAuthAttempt(configuration: configuration)
        let callback = URL(string: "com.googleusercontent.apps.123:/oauth2redirect?code=fake&state=\(attempt.state)")!
        do { try await client.complete(attempt, callback: callback); XCTFail("Login must not bypass corrupt intent") }
        catch { XCTAssertEqual(error as? OAuthFailure, .storage) }
        XCTAssertEqual(store.loads, 0)
        let calls = await network.calls
        XCTAssertEqual(calls, 0)
    }
    func testConcurrentCleanupCannotCompleteAnotherPendingOperation() async throws {
        let url = try marker()
        let store = RetryTokenStore(); store.fail = false
        let data = HoldingCleanup()
        let client = OAuthClient(configuration: try config(), transport: NoNetwork(), store: store, privateData: data, cleanupJournal: FileOAuthCleanupJournal(url: url))
        let first = Task { try await client.deleteLocalAccount() }
        await data.waitUntilStarted()
        do { try await client.deleteLocalAccount(); XCTFail("Concurrent cleanup must not finish the marker") }
        catch { XCTAssertEqual(error as? OAuthFailure, .revoked) }
        XCTAssertTrue(try FileOAuthCleanupJournal(url: url).isPending())
        XCTAssertEqual(store.deletions, 1)
        await data.release()
        try await first.value
        XCTAssertFalse(try FileOAuthCleanupJournal(url: url).isPending())
    }
    func testIntentAndCompletionWriteFailuresAreNotReportedAsSuccess() async throws {
        for stage in [JournalFailure.Stage.begin, .finish] {
            let store = RetryTokenStore(); store.fail = false
            let data = CleanupData()
            let client = OAuthClient(configuration: try config(), transport: NoNetwork(), store: store, privateData: data, cleanupJournal: JournalFailure(stage: stage))
            do { try await client.deleteLocalAccount(); XCTFail("Journal failure must be reported") }
            catch { XCTAssertEqual(error as? OAuthFailure, .storage) }
            XCTAssertEqual(store.deletions, stage == .begin ? 0 : 1)
        }
    }
}
