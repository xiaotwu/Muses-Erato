import Foundation
import CryptoKit
import MusesNetworking

/// Temporary P3 boundary. P4 maps these values to P2's frozen Domain IDs/pages.
public struct CatalogItem: Sendable, Equatable, Codable {
    public enum Kind: String, Sendable, Codable { case video, playlist, channel }
    public let kind: Kind
    public let id: String
    public let title: String
    public let channelID: String?
    public let thumbnailURL: URL?
    public let source: String
    public init(kind: Kind, id: String, title: String, channelID: String?, thumbnailURL: URL?, source: String = "youtubeDataAPI") {
        self.kind = kind; self.id = id; self.title = title; self.channelID = channelID; self.thumbnailURL = thumbnailURL; self.source = source
    }
}

public struct CatalogPage: Sendable, Equatable {
    public let items: [CatalogItem]
    public let nextPageToken: String?
    public let complete: Bool
    public let fetchedAt: Date
    public let source: String
    public init(items: [CatalogItem], nextPageToken: String?, fetchedAt: Date = Date()) {
        self.items = items; self.nextPageToken = nextPageToken; self.complete = nextPageToken == nil; self.fetchedAt = fetchedAt; self.source = "youtubeDataAPI"
    }
}

public enum CatalogEndpoint: String, Sendable {
    case search = "search", videos, playlists, playlistItems, subscriptions, channels
    var path: String { rawValue }
}

public protocol CatalogCredential: Sendable {
    func accessToken() async throws -> String
}

public actor YouTubeDataCatalog {
    private let apiKey: String?
    private let credential: (any CatalogCredential)?
    private let coalescer: GETCoalescer
    private let ledger: RequestLedger
    private let budget: RequestBudget?
    private var cache: [String: (CatalogPage, Date)] = [:]
    private let ttl: TimeInterval

    public init(apiKey: String? = nil, credential: (any CatalogCredential)? = nil, transport: any HTTPTransport = URLSessionTransport(), ledger: RequestLedger = RequestLedger(), budget: RequestBudget? = nil, cacheTTL: TimeInterval = 300) {
        self.apiKey = apiKey; self.credential = credential; self.coalescer = GETCoalescer(transport: transport); self.ledger = ledger; self.budget = budget; self.ttl = min(max(cacheTTL, 0), 3600)
    }
    public func requestCounts() async -> RequestLedger.Snapshot { await ledger.snapshot() }
    public func clearPrivateCache() { cache = cache.filter { !$0.key.hasPrefix("private:") } }
    public func clearAllCache() { cache.removeAll() }

    public func search(_ query: String, pageToken: String? = nil, pageSize: Int = 20) async throws -> CatalogPage {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return CatalogPage(items: [], nextPageToken: nil) }
        return try await fetch(.search, parameters: ["part":"snippet", "q":normalized, "type":"video", "videoEmbeddable":"true", "maxResults":String(min(max(pageSize, 1), 50))], pageToken: pageToken, authorized: false)
    }
    public func videos(_ ids: [String]) async throws -> CatalogPage {
        let unique = Array(Set(ids)).sorted()
        guard !unique.isEmpty else { return CatalogPage(items: [], nextPageToken: nil) }
        guard unique.count <= 50 else { throw APIError.invalidResponse }
        return try await fetch(.videos, parameters: ["part":"snippet", "id":unique.joined(separator: ","), "maxResults":"50"], pageToken: nil, authorized: false)
    }
    public func playlist(id: String, pageToken: String? = nil) async throws -> CatalogPage {
        try await fetch(.playlistItems, parameters: ["part":"snippet", "playlistId":id, "maxResults":"50"], pageToken: pageToken, authorized: false)
    }
    public func playlistMetadata(id: String) async throws -> CatalogPage {
        try await fetch(.playlists, parameters: ["part":"snippet", "id":id], pageToken: nil, authorized: false)
    }
    public func channel(id: String) async throws -> CatalogPage {
        try await fetch(.channels, parameters: ["part":"snippet", "id":id], pageToken: nil, authorized: false)
    }
    public func myPlaylists(pageToken: String? = nil) async throws -> CatalogPage {
        try await fetch(.playlists, parameters: ["part":"snippet", "mine":"true", "maxResults":"50"], pageToken: pageToken, authorized: true)
    }
    public func mySubscriptions(pageToken: String? = nil) async throws -> CatalogPage {
        try await fetch(.subscriptions, parameters: ["part":"snippet", "mine":"true", "maxResults":"50"], pageToken: pageToken, authorized: true)
    }
    public func myChannel() async throws -> CatalogPage {
        try await fetch(.channels, parameters: ["part":"snippet", "mine":"true"], pageToken: nil, authorized: true)
    }

    private func fetch(_ endpoint: CatalogEndpoint, parameters: [String:String], pageToken: String?, authorized: Bool) async throws -> CatalogPage {
        guard pageToken == nil || (!pageToken!.isEmpty && pageToken!.count < 512) else { throw APIError.invalidResponse }
        var query = parameters
        if let pageToken { query["pageToken"] = pageToken }
        if !authorized, let apiKey { query["key"] = apiKey }
        var parts = URLComponents(string: "https://www.googleapis.com/youtube/v3/\(endpoint.path)")!
        parts.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = parts.url else { throw APIError.invalidResponse }
        let token = try await authorized ? credential?.accessToken() : nil
        if authorized && token == nil { throw APIError.unauthorized }
        if !authorized && apiKey == nil { throw APIError.unauthorized }
        let accountMarker = token.map { Data(SHA256.hash(data: Data($0.utf8))).base64EncodedString() } ?? ""
        let identity = (authorized ? "private:\(accountMarker):" : "public:") + endpoint.rawValue + ":" + (parts.percentEncodedQuery ?? "")
        if let cached = cache[identity], cached.1 > Date() { return cached.0 }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let response: HTTPResponse
        do { response = try await coalescer.get(request, identity: identity, ledger: ledger, endpoint: endpoint.rawValue, budget: budget) }
        catch is CancellationError { throw CancellationError() }
        catch let error as APIError { throw error }
        catch { throw APIError.network }
        if let error = APIError.classify(response) { throw error }
        guard let decoded = try? JSONDecoder().decode(ListResponse.self, from: response.body) else { throw APIError.invalidResponse }
        let page = CatalogPage(items: decoded.items.compactMap { $0.catalogItem(endpoint: endpoint) }, nextPageToken: decoded.nextPageToken)
        cache[identity] = (page, Date().addingTimeInterval(ttl))
        return page
    }
}

private struct ListResponse: Decodable {
    let nextPageToken: String?
    let items: [DataItem]
}
private struct DataItem: Decodable {
    struct ResourceID: Decodable { let kind: String?; let videoId: String?; let playlistId: String?; let channelId: String? }
    struct Thumb: Decodable { let url: URL? }
    struct Thumbs: Decodable { let `default`: Thumb?; let medium: Thumb? }
    struct Snippet: Decodable { let title: String?; let channelId: String?; let resourceId: ResourceID?; let thumbnails: Thumbs? }
    let id: IDValue?
    let snippet: Snippet?
    func catalogItem(endpoint: CatalogEndpoint) -> CatalogItem? {
        guard let snippet, let title = snippet.title, !title.isEmpty else { return nil }
        let kind: CatalogItem.Kind
        let rawID: String?
        switch endpoint {
        case .search:
            guard case .resource(let resource) = id else { return nil }
            if let video = resource.videoId { kind = .video; rawID = video }
            else if let playlist = resource.playlistId { kind = .playlist; rawID = playlist }
            else { kind = .channel; rawID = resource.channelId }
        case .videos: kind = .video; rawID = id?.stringValue
        case .playlistItems: kind = .video; rawID = snippet.resourceId?.videoId
        case .playlists: kind = .playlist; rawID = id?.stringValue
        case .subscriptions: kind = .channel; rawID = snippet.resourceId?.channelId
        case .channels: kind = .channel; rawID = id?.stringValue
        }
        guard let rawID, !rawID.isEmpty else { return nil }
        return CatalogItem(kind: kind, id: rawID, title: title, channelID: snippet.channelId, thumbnailURL: snippet.thumbnails?.medium?.url ?? snippet.thumbnails?.default?.url)
    }
}
private enum IDValue: Decodable {
    case string(String), resource(DataItem.ResourceID)
    var stringValue: String? { if case .string(let value) = self { value } else { nil } }
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) { self = .string(value) }
        else { self = .resource(try container.decode(DataItem.ResourceID.self)) }
    }
}
