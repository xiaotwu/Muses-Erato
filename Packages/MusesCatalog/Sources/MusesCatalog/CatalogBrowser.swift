import Foundation
import Observation

/// A page is loaded only by an explicit caller action. Failed next pages retain
/// their cursor and existing rows. Reset invalidates even non-cooperative tasks.
@MainActor @Observable
public final class CatalogPager {
    public private(set) var items: [CatalogItem] = []
    public private(set) var nextPageToken: String?
    public private(set) var loading = false
    public private(set) var loaded = false
    public private(set) var error: String?
    public private(set) var fetchedAt: Date?
    private var generation = UUID()
    private var consumedTokens = Set<String>()
    public init() {}
    public func reset() {
        generation = UUID(); items = []; nextPageToken = nil
        loading = false; loaded = false; error = nil; fetchedAt = nil; consumedTokens = []
    }
    public func expire(at now: Date = Date()) {
        if let fetchedAt, now.timeIntervalSince(fetchedAt) >= 29 * 86400 || fetchedAt > now { reset() }
    }
    public func load(_ fetch: (String?) async throws -> CatalogPage) async {
        guard !loading, !loaded || nextPageToken != nil else { return }
        let current = generation
        let token = nextPageToken
        loading = true; error = nil
        defer { if current == generation { loading = false } }
        do {
            let page = try await fetch(token)
            guard current == generation, !Task.isCancelled else { return }
            var keys = Set(items.map { $0.rowID })
            items += page.items.filter { keys.insert($0.rowID).inserted }
            if let token { consumedTokens.insert(token) }
            nextPageToken = page.nextPageToken.flatMap { consumedTokens.contains($0) || $0.isEmpty ? nil : $0 }
            loaded = true; fetchedAt = min(fetchedAt ?? page.fetchedAt, page.fetchedAt)
        } catch is CancellationError { }
        catch { if current == generation { self.error = error.localizedDescription } }
    }
}

public enum YouTubeCatalogLink: Hashable, Sendable, Identifiable {
    case video(String), playlist(String), channel(String), handle(String)
    public var id: String { String(describing: self) }
    public static func parse(_ input: String) -> Self? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        func valid(_ value: String, count: Int? = nil) -> Bool {
            !value.isEmpty && value.count <= 150 && (count == nil || value.count == count!) && value.utf8.allSatisfy {
                (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95
            }
        }
        if valid(text, count: 11) { return .video(text) }
        guard let url = URLComponents(string: text), url.scheme == "https", url.user == nil, url.password == nil,
              url.port == nil, let host = url.host?.lowercased(),
              ["youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be"].contains(host) else { return nil }
        let path = url.path.split(separator: "/").map(String.init)
        let value = { (name: String) in url.queryItems?.first { $0.name == name }?.value }
        if host == "youtu.be", path.count == 1, valid(path[0], count: 11) { return .video(path[0]) }
        guard host != "youtu.be" else { return nil }
        if path == ["watch"], let id = value("v"), valid(id, count: 11) { return .video(id) }
        if path == ["playlist"], let id = value("list"), valid(id) { return .playlist(id) }
        if path.count == 2, ["shorts", "embed", "live"].contains(path[0]), valid(path[1], count: 11) { return .video(path[1]) }
        if path.count == 2, path[0] == "channel", valid(path[1], count: 24), path[1].hasPrefix("UC") { return .channel(path[1]) }
        if path.count == 1, path[0].hasPrefix("@"), path[0].count > 1, path[0].count <= 100 { return .handle(path[0]) }
        return nil
    }
}
