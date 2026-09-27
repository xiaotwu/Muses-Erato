import Foundation

/// P4 supplies an index of the user's saved records. This port never calls the network.
public protocol LocalCatalogIndex: Sendable {
    func searchSaved(query: String, limit: Int) async throws -> [CatalogItem]
    func recentSaved(limit: Int) async throws -> [CatalogItem]
}

public struct CatalogSearchResult: Sendable {
    public let saved: [CatalogItem]
    public let online: CatalogPage?
    public let onlineError: Error?
    public init(saved: [CatalogItem], online: CatalogPage?, onlineError: Error? = nil) { self.saved = saved; self.online = online; self.onlineError = onlineError }
}

public struct CatalogHome: Sendable {
    public let saved: [CatalogItem]
    public let subscriptions: CatalogPage?
    public let fetchedAt: Date
    public init(saved: [CatalogItem], subscriptions: CatalogPage?, fetchedAt: Date = Date()) {
        self.saved = saved; self.subscriptions = subscriptions; self.fetchedAt = fetchedAt
    }
}

public struct CatalogDiscovery: Sendable {
    public let remote: YouTubeDataCatalog
    public let local: any LocalCatalogIndex
    public init(remote: YouTubeDataCatalog, local: any LocalCatalogIndex) { self.remote = remote; self.local = local }
    /// UI calls online only after explicit submit/debounce; local results remain available on quota failure.
    public func search(_ query: String, includeOnline: Bool) async throws -> CatalogSearchResult {
        let saved = try await local.searchSaved(query: query, limit: 50)
        guard includeOnline else { return CatalogSearchResult(saved: saved, online: nil) }
        do { return CatalogSearchResult(saved: saved, online: try await remote.search(query)) }
        catch is CancellationError { throw CancellationError() }
        catch { return CatalogSearchResult(saved: saved, online: nil, onlineError: error) }
    }
    public func home(includeSubscriptions: Bool) async throws -> CatalogHome {
        let saved = try await local.recentSaved(limit: 50)
        let subscriptions = includeSubscriptions ? try await remote.mySubscriptions() : nil
        return CatalogHome(saved: saved, subscriptions: subscriptions)
    }
}
