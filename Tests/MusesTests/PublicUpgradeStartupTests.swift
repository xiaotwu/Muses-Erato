import XCTest
import SwiftData
import WebKit
import MusesPersistence
@testable import Muses

@MainActor
final class PublicUpgradeStartupTests: XCTestCase {
    func testPhysicalLegacyStartupRelaunchAndExplicitDeletion() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("app-upgrade-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fixture = try PhysicalLegacyFixture(url: root.appendingPathComponent("muses-youtube-native.sqlite"))
        defer { fixture.closePinAndSettings() }
        let destination = root.appendingPathComponent("muses-public-v1.sqlite")
        let original = try PublicStoreRouter.fingerprint(fixture.url)
        var credentialDeletionCalled = false
        let session = PublicYouTubeSession(storeURL: destination, defaults: fixture.defaults, domainName: fixture.domain,
            deleteCredentials: { credentialDeletionCalled = true })
        XCTAssertNil(session.recoveryMessage)
        XCTAssertTrue(session.hasMigrationArchive)
        XCTAssertEqual(session.playedIDs.count, 1)
        XCTAssertEqual(session.playlists.first?.occurrences?.count, 2)
        session.enqueuePlaylist(try XCTUnwrap(session.playlists.first?.id))
        XCTAssertEqual(session.queue.snapshot.upcoming.suffix(2).map(\.trackID),
            session.playlists.first?.playbackTrackIDs)
        session.toggleFavorite()
        let liked = session.currentTrack?.liked
        let reopened = PublicYouTubeSession(storeURL: destination, defaults: fixture.defaults,
            domainName: fixture.domain, deleteCredentials: {})
        XCTAssertNil(reopened.recoveryMessage)
        XCTAssertEqual(reopened.currentTrack?.liked, liked)
        XCTAssertFalse(reopened.showPlayer)
        XCTAssertEqual(try PublicStoreRouter.fingerprint(fixture.url), original)
        XCTAssertEqual(try reopened.repository?.list(LegacyNote.self, kind: .note).count, 1)
        XCTAssertEqual(try reopened.repository?.list(LegacyBookmark.self, kind: .bookmark).count, 1)
        await session.deleteLocalData()
        XCTAssertTrue(credentialDeletionCalled)
        XCTAssertTrue(session.tracks.isEmpty)
        XCTAssertFalse(session.hasMigrationArchive)
        XCTAssertNotNil(session.failureMessage, "Pending physical deletion must be disclosed")
        let afterDelete = PublicYouTubeSession(storeURL: destination, defaults: fixture.defaults,
            domainName: fixture.domain, deleteCredentials: {})
        XCTAssertNil(afterDelete.recoveryMessage)
        XCTAssertTrue(afterDelete.tracks.isEmpty)
        XCTAssertFalse(afterDelete.hasMigrationArchive)
    }

    func testMalformedPhysicalQueueNeverActivates() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("app-upgrade-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fixture = try PhysicalLegacyFixture(url: root.appendingPathComponent("muses-youtube-native.sqlite"))
        defer { fixture.closePinAndSettings() }
        let context = ModelContext(fixture.container)
        let queue = try XCTUnwrap(context.fetch(FetchDescriptor<QueueState>()).first)
        queue.itemsJSON = "malformed"
        try context.save()
        let before = try PublicStoreRouter.fingerprint(fixture.url)
        let target = root.appendingPathComponent("muses-public-v1.sqlite")
        let session = PublicYouTubeSession(storeURL: target, defaults: fixture.defaults,
            domainName: fixture.domain, deleteCredentials: {})
        XCTAssertNotNil(session.recoveryMessage)
        XCTAssertNil(session.repository)
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.appendingPathExtension("upgrade").appendingPathComponent("active.json").path))
        XCTAssertEqual(try PublicStoreRouter.fingerprint(fixture.url), before)
    }
}

@MainActor
final class PublicDeletionRecoveryTests: XCTestCase {
    func testFailedCredentialCleanupStillAttemptsWebsiteCleanupAndRestartsPending() async throws {
        enum Failure: Error { case keychain }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("app-delete-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let target = root.appendingPathComponent("muses-public-v1.sqlite")
        let domain = "muses.delete-test." + UUID().uuidString
        defer { UserDefaults.standard.removePersistentDomain(forName: domain) }
        var websiteAttempted = false
        let session = PublicYouTubeSession(storeURL: target, domainName: domain, deleteCredentials: { throw Failure.keychain },
            deleteWebsiteData: { websiteAttempted = true })
        await session.deleteLocalData()
        XCTAssertTrue(websiteAttempted)
        XCTAssertNotNil(session.recoveryMessage)
        XCTAssertNil(session.repository)
        let marker = target.appendingPathExtension("upgrade").appendingPathComponent("deleted.json")
        var deletion = try JSONDecoder().decode(PublicStoreRouter.Deletion.self, from: Data(contentsOf: marker))
        XCTAssertFalse(deletion.externalCleanupComplete)
        let restarted = PublicYouTubeSession(storeURL: target, domainName: domain, deleteCredentials: {}, deleteWebsiteData: {})
        // Startup completes async privacy cleanup before it permits a public library to open.
        for _ in 0..<100 where restarted.repository == nil { await Task.yield() }
        XCTAssertNil(restarted.recoveryMessage)
        XCTAssertNotNil(restarted.repository)
        XCTAssertTrue(restarted.tracks.isEmpty)
        deletion = try JSONDecoder().decode(PublicStoreRouter.Deletion.self, from: Data(contentsOf: marker))
        XCTAssertTrue(deletion.externalCleanupComplete)
    }
}

@MainActor
final class PublicWebsiteCleanupTests: XCTestCase {
    func testWebsiteCookieAndFoundationCacheAreRemoved() async throws {
        let store = WKWebsiteDataStore(forIdentifier: UUID())
        let cookie = try XCTUnwrap(HTTPCookie(properties: [.domain: "migration-proof.invalid", .path: "/", .name: "session", .value: "synthetic"] ))
        await withCheckedContinuation { continuation in
            store.httpCookieStore.setCookie(cookie) { continuation.resume() }
        }
        let cookiesBefore = await withCheckedContinuation { continuation in
            store.httpCookieStore.getAllCookies { continuation.resume(returning: $0.count) }
        }
        XCTAssertEqual(cookiesBefore, 1)
        let cache = URLCache(memoryCapacity: 1024 * 1024, diskCapacity: 0)
        let url = try XCTUnwrap(URL(string: "https://migration-proof.invalid/artwork.png"))
        let request = URLRequest(url: url)
        cache.storeCachedResponse(CachedURLResponse(response: URLResponse(url: url, mimeType: "image/png", expectedContentLength: 3, textEncodingName: nil), data: Data([1, 2, 3])), for: request)
        XCTAssertNotNil(cache.cachedResponse(for: request))
        let cacheRoot = FileManager.default.temporaryDirectory.appendingPathComponent("retired-cache-" + UUID().uuidString)
        let inherited = cacheRoot.appendingPathComponent("Muses")
        try FileManager.default.createDirectory(at: inherited.appendingPathComponent("artwork"), withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: inherited.appendingPathComponent("artwork/retained.jpg"))
        let unrelated = cacheRoot.appendingPathComponent("unrelated")
        try Data([4]).write(to: unrelated)
        try await PublicWebsiteDataDeletion.clear(store: store, cache: cache, legacyCacheDirectory: inherited)
        XCTAssertFalse(FileManager.default.fileExists(atPath: inherited.path))
        XCTAssertEqual(try Data(contentsOf: unrelated), Data([4]))
        let cookiesAfter = await withCheckedContinuation { continuation in
            store.httpCookieStore.getAllCookies { continuation.resume(returning: $0.count) }
        }
        XCTAssertEqual(cookiesAfter, 0)
        XCTAssertNil(cache.cachedResponse(for: request))
    }
}
