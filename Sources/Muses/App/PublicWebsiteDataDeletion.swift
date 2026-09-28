import Foundation
import WebKit

@MainActor
enum PublicWebsiteDataDeletion {
    /// Called after iframe teardown. Does not affect Safari/ASWebAuthenticationSession's browser profile.
    static func clear(store: WKWebsiteDataStore = .default(), cache: URLCache = .shared,
                      cookies: HTTPCookieStorage = .shared,
                      legacyCacheDirectory: URL? = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("Muses")) async throws {
        let tasks = await withCheckedContinuation { continuation in
            URLSession.shared.getAllTasks { continuation.resume(returning: $0) }
        }
        tasks.forEach { $0.cancel() }
        for _ in 0..<100 where tasks.contains(where: { $0.state != .completed }) {
            try? await Task.sleep(for: .milliseconds(20))
        }
        guard tasks.allSatisfy({ $0.state == .completed }) else { throw WebsiteCleanupError.requestsRemain }
        cache.removeAllCachedResponses()
        for cookie in cookies.cookies ?? [] { cookies.deleteCookie(cookie) }
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        await withCheckedContinuation { continuation in
            store.removeData(ofTypes: types, modifiedSince: .distantPast) { continuation.resume() }
        }
        let remaining = await withCheckedContinuation { continuation in
            store.fetchDataRecords(ofTypes: types) { continuation.resume(returning: $0.isEmpty) }
        }
        guard remaining else { throw WebsiteCleanupError.recordsRemain }
        // Remove the retired app's dedicated artwork/feed/media cache namespace without
        // linking any old cache, media or network implementation.
        if let directory = legacyCacheDirectory, FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        // Current AsyncImage and API transport responses use the shared Foundation cache.
        cache.removeAllCachedResponses()
        for cookie in cookies.cookies ?? [] { cookies.deleteCookie(cookie) }
    }
    enum WebsiteCleanupError: Error { case recordsRemain, requestsRemain }
}
