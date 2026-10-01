import Foundation
import CryptoKit
import MusesNetworking

/// Temporary P3 boundary. P4 maps these values to P2's frozen Domain IDs/pages.
public enum VideoEmbeddingStatus: String, Sendable, Codable {
    case permitted, madeForKids, notEmbeddable, unknown
}

public struct VideoPlaybackMetadata: Sendable, Equatable {
    public let embeddingStatus: VideoEmbeddingStatus
    public let contentKind: CatalogItem.ContentKind?
    public let fetchedAt: Date
}

public struct CatalogItem: Sendable, Equatable, Codable {
    public enum ContentKind: String, Sendable, Codable { case music, video }
    public enum Kind: String, Sendable, Codable { case video, playlist, channel }
    public let kind: Kind
    public let id: String
    public let title: String
    public let channelID: String?
    public let channelTitle: String?
    public let thumbnailURL: URL?
    public let source: String
    public let description: String?
    public let listEntryID: String?
    public var rowID: String { kind.rawValue + ":" + (listEntryID ?? id) }
    public let fetchedAt: Date?
    public let uploadsPlaylistID: String?
    public let embeddingStatus: VideoEmbeddingStatus?
    public let contentKind: ContentKind?
    public init(kind: Kind, id: String, title: String, channelID: String?, thumbnailURL: URL?, source: String = "youtubeDataAPI", description: String? = nil, uploadsPlaylistID: String? = nil, fetchedAt: Date? = nil, listEntryID: String? = nil, embeddingStatus: VideoEmbeddingStatus? = nil, channelTitle: String? = nil, contentKind: ContentKind? = nil) {
        self.kind = kind; self.id = id; self.title = title; self.channelID = channelID; self.thumbnailURL = thumbnailURL; self.source = source
        self.channelTitle = channelTitle
        self.embeddingStatus = embeddingStatus
        self.contentKind = contentKind
        self.listEntryID = listEntryID; self.fetchedAt = fetchedAt; self.description = description; self.uploadsPlaylistID = uploadsPlaylistID
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

/// Application identity required for an iOS-restricted Google API key.
/// This is a restriction signal, not a secret or app attestation.
public struct CatalogClientIdentity: Sendable, Equatable {
    public let iOSBundleID: String
    public init?(iOSBundleID: String) {
        guard !iOSBundleID.isEmpty, iOSBundleID.count <= 255,
              iOSBundleID.split(separator: ".", omittingEmptySubsequences: false).allSatisfy({ !$0.isEmpty }),
              iOSBundleID.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 46 }) else { return nil }
        self.iOSBundleID = iOSBundleID
    }
}

public actor YouTubeDataCatalog {
    private let clientIdentity: CatalogClientIdentity?
    private let apiKey: String?
    private let credential: (any CatalogCredential)?
    private let coalescer: GETCoalescer
    private let ledger: RequestLedger
    private let budget: RequestBudget?
    private var cache: [String: (CatalogPage, Date)] = [:]
    private let ttl: TimeInterval
    private var cacheEpoch: UInt64 = 0

    public init(apiKey: String? = nil, credential: (any CatalogCredential)? = nil, transport: any HTTPTransport = URLSessionTransport(), ledger: RequestLedger = RequestLedger(), budget: RequestBudget? = nil, cacheTTL: TimeInterval = 300, clientIdentity: CatalogClientIdentity? = nil) {
        self.clientIdentity = clientIdentity
        self.apiKey = apiKey; self.credential = credential; self.coalescer = GETCoalescer(transport: transport); self.ledger = ledger; self.budget = budget; self.ttl = min(max(cacheTTL, 0), 3600)
    }
    public func requestCounts() async -> RequestLedger.Snapshot { await ledger.snapshot() }
    public func clearPrivateCache() { cacheEpoch &+= 1; cache = cache.filter { !$0.key.hasPrefix("private:") } }
    public func purgeExpiredCache() { cache = cache.filter { $0.value.1 > Date() } }
    public func clearAllCache() { cacheEpoch &+= 1; cache.removeAll() }

    public func search(_ query: String, pageToken: String? = nil, pageSize: Int = 20, kind: CatalogItem.Kind = .video) async throws -> CatalogPage {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return CatalogPage(items: [], nextPageToken: nil) }
        var parameters = ["part":"snippet", "q":normalized, "type":kind.rawValue, "maxResults":String(min(max(pageSize, 1), 50))]
        if kind == .video { parameters["videoEmbeddable"] = "true" }
        return try await fetch(.search, parameters: parameters, pageToken: pageToken, authorized: false)
    }
    public func videos(_ ids: [String]) async throws -> CatalogPage {
        let unique = Array(Set(ids)).sorted()
        guard !unique.isEmpty else { return CatalogPage(items: [], nextPageToken: nil) }
        guard unique.count <= 50 else { throw APIError.invalidResponse }
        return try await fetch(.videos, parameters: ["part":"snippet", "id":unique.joined(separator: ","), "maxResults":"50"], pageToken: nil, authorized: false)
    }
    /// A fresh lookup before creating each embedded player. Search/import/cache data
    /// and missing fields never grant permission to embed.
    public func videoEmbeddingStatus(_ id: String) async throws -> VideoEmbeddingStatus {
        try await videoPlaybackMetadata(id).embeddingStatus
    }
    /// Reuses the existing fresh snippet/status lookup; never adds a classification request.
    public func videoPlaybackMetadata(_ id: String) async throws -> VideoPlaybackMetadata {
        guard id.utf8.count == 11, id.utf8.allSatisfy({
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95
        }) else { throw APIError.invalidResponse }
        let page = try await fetch(.videos, parameters: ["part":"id,snippet,status", "id":id],
                                   pageToken: nil, authorized: false, useCache: false)
        let matches = page.items.filter { $0.id == id && $0.kind == .video }
        guard matches.count == 1 else {
            return VideoPlaybackMetadata(embeddingStatus: .unknown, contentKind: nil, fetchedAt: page.fetchedAt)
        }
        return VideoPlaybackMetadata(embeddingStatus: matches[0].embeddingStatus ?? .unknown,
                                     contentKind: matches[0].contentKind, fetchedAt: page.fetchedAt)
    }
    public func playlist(id: String, pageToken: String? = nil, authorized: Bool = false) async throws -> CatalogPage {
        try await fetch(.playlistItems, parameters: ["part":"snippet", "playlistId":id, "maxResults":"50"], pageToken: pageToken, authorized: authorized)
    }
    public func playlistMetadata(id: String, authorized: Bool = false) async throws -> CatalogPage {
        try await fetch(.playlists, parameters: ["part":"snippet", "id":id], pageToken: nil, authorized: authorized)
    }
    public func channel(id: String, isHandle: Bool = false) async throws -> CatalogPage {
        try await fetch(.channels, parameters: ["part":"snippet,contentDetails", isHandle ? "forHandle" : "id":id], pageToken: nil, authorized: false)
    }
    public func channelPlaylists(id: String, pageToken: String? = nil) async throws -> CatalogPage {
        try await fetch(.playlists, parameters: ["part":"snippet", "channelId":id, "maxResults":"50"], pageToken: pageToken, authorized: false)
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

    private func fetch(_ endpoint: CatalogEndpoint, parameters: [String:String], pageToken: String?, authorized: Bool, useCache: Bool = true) async throws -> CatalogPage {
        let epoch = cacheEpoch
        guard pageToken == nil || (!pageToken!.isEmpty && pageToken!.count < 512) else { throw APIError.invalidResponse }
        // Google accepts OAuth credentials for the same read endpoints. This lets
        // a signed-in user browse when the public API key is not configured.
        let token = try await (authorized || apiKey == nil) ? credential?.accessToken() : nil
        if authorized && token == nil { throw APIError.unauthorized }
        if !authorized && apiKey == nil && token == nil { throw APIError.unauthorized }
        var query = parameters
        if let pageToken { query["pageToken"] = pageToken }
        if token == nil, let apiKey { query["key"] = apiKey }
        var parts = URLComponents(string: "https://www.googleapis.com/youtube/v3/\(endpoint.path)")!
        parts.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = parts.url else { throw APIError.invalidResponse }
        let accountMarker = token.map { Data(SHA256.hash(data: Data($0.utf8))).base64EncodedString() } ?? ""
        let identity = (token != nil ? "private:\(accountMarker):" : "public:") + endpoint.rawValue + ":" + (parts.percentEncodedQuery ?? "")
        purgeExpiredCache()
        if useCache, let cached = cache[identity], cached.1 > Date() { return cached.0 }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        if !useCache { request.cachePolicy = .reloadIgnoringLocalCacheData }
        if token == nil, let clientIdentity {
            request.setValue(clientIdentity.iOSBundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let response: HTTPResponse
        do { response = try await coalescer.get(request, identity: identity, ledger: ledger, endpoint: endpoint.rawValue, budget: budget) }
        catch is CancellationError { throw CancellationError() }
        catch let error as APIError { throw error }
        catch { throw APIError.network }
        if let error = APIError.classify(response) { throw error }
        guard let decoded = try? JSONDecoder().decode(ListResponse.self, from: response.body) else { throw APIError.invalidResponse }
        let items = decoded.items.compactMap { $0.catalogItem(endpoint: endpoint) }
        if endpoint == .playlistItems, items.count != decoded.items.count { throw PlaylistImportError.incomplete }
        let page = CatalogPage(items: items, nextPageToken: decoded.nextPageToken)
        guard epoch == cacheEpoch else { throw CancellationError() }
        if useCache { cache[identity] = (page, Date().addingTimeInterval(ttl)) }
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
    struct CategoryID: Decodable {
        let value: String?
        init(from decoder: Decoder) throws {
            value = try? decoder.singleValueContainer().decode(String.self)
        }
    }
    struct Snippet: Decodable { let title: String?; let description: String?; let videoOwnerChannelId: String?; let videoOwnerChannelTitle: String?; let channelId: String?; let channelTitle: String?; let resourceId: ResourceID?; let thumbnails: Thumbs?; let categoryId: CategoryID? }
    struct ContentDetails: Decodable {
        struct Related: Decodable { let uploads: String? }
        let relatedPlaylists: Related?
    }
    struct Status: Decodable {
        let madeForKids: Bool?
        let embeddable: Bool?
        var embeddingStatus: VideoEmbeddingStatus {
            if madeForKids == true { return .madeForKids }
            if embeddable == false { return .notEmbeddable }
            guard madeForKids == false, embeddable == true else { return .unknown }
            return .permitted
        }
    }
    let status: Status?
    let contentDetails: ContentDetails?
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
        let contentKind: CatalogItem.ContentKind?
        if kind == .video, let category = snippet.categoryId?.value, !category.isEmpty,
           category.utf8.allSatisfy({ (48...57).contains($0) }), let number = Int(category), number > 0 {
            contentKind = number == 10 ? .music : .video
        } else { contentKind = nil }
        return CatalogItem(kind: kind, id: rawID, title: title, channelID: endpoint == .playlistItems ? snippet.videoOwnerChannelId : snippet.channelId, thumbnailURL: snippet.thumbnails?.medium?.url ?? snippet.thumbnails?.default?.url, description: snippet.description, uploadsPlaylistID: contentDetails?.relatedPlaylists?.uploads, fetchedAt: Date(), listEntryID: endpoint == .playlistItems ? id?.stringValue : nil, embeddingStatus: endpoint == .videos ? (status?.embeddingStatus ?? .unknown) : nil, channelTitle: endpoint == .playlistItems ? snippet.videoOwnerChannelTitle : snippet.channelTitle, contentKind: contentKind)
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
