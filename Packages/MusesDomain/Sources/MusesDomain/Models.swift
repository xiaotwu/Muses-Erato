import Foundation

public enum PlaybackSource: Hashable, Codable, Sendable {
    case youtubeVideo(VideoID)
    case localFile(BookmarkedFileID)
    case authorizedRemote(ProviderID, ResourceID)
}

public struct Track: Hashable, Codable, Sendable, Identifiable {
    public let id: TrackID
    public var title: String
    public var artist: String
    public var source: PlaybackSource
    public var provenance: Provenance
    public var durationMilliseconds: Int?
    /// nil marks legacy metadata whose source/time was not recorded.
    public enum MetadataOrigin: String, Codable, Sendable { case user, youtubeDataAPI, placeholder }
    public var metadataOrigin: MetadataOrigin?
    public var metadataFetchedAt: Date?
    public var liked: Bool
    public init(id: TrackID, title: String, artist: String, source: PlaybackSource, provenance: Provenance, durationMilliseconds: Int? = nil, liked: Bool = false, metadataOrigin: MetadataOrigin? = nil, metadataFetchedAt: Date? = nil) {
        self.id = id; self.title = title; self.artist = artist; self.source = source; self.provenance = provenance
        self.durationMilliseconds = durationMilliseconds; self.liked = liked
        self.metadataOrigin = metadataOrigin; self.metadataFetchedAt = metadataFetchedAt
    }
}

public enum CatalogItemKind: String, Codable, Sendable { case video, channel, playlist, release, artist }
public struct CatalogItem: Hashable, Codable, Sendable, Identifiable {
    public let id: CatalogID
    public let kind: CatalogItemKind
    public let title: String
    public let provenance: Provenance
    public let videoID: VideoID?
    public init(id: CatalogID, kind: CatalogItemKind, title: String, provenance: Provenance, videoID: VideoID? = nil) {
        self.id = id; self.kind = kind; self.title = title; self.provenance = provenance; self.videoID = videoID
    }
}

public struct Video: Hashable, Codable, Sendable, Identifiable {
    public let id: VideoID
    public let title: String
    public let channelID: ChannelID?
    public init(id: VideoID, title: String, channelID: ChannelID? = nil) { self.id = id; self.title = title; self.channelID = channelID }
}

public struct CatalogPage: Codable, Equatable, Sendable {
    public let items: [CatalogItem]
    public let nextToken: String?
    public let isComplete: Bool
    public let source: ProviderID
    public let fetchedAt: Date
    public init(items: [CatalogItem], nextToken: String?, isComplete: Bool, source: ProviderID, fetchedAt: Date) {
        self.items = items; self.nextToken = nextToken; self.isComplete = isComplete; self.source = source; self.fetchedAt = fetchedAt
    }
}

public struct CatalogSearchRequest: Sendable, Equatable { public let query: String; public let pageToken: String?; public init(query: String, pageToken: String? = nil) { self.query = query; self.pageToken = pageToken } }
public struct CatalogContext: Sendable, Equatable { public let accountID: String?; public init(accountID: String? = nil) { self.accountID = accountID } }
public protocol MusicCatalog: Sendable {
    func search(_ request: CatalogSearchRequest) async throws -> CatalogPage
    func home(context: CatalogContext) async throws -> CatalogPage
    func artist(id: ArtistID) async throws -> CatalogPage
    func release(id: ReleaseID) async throws -> CatalogPage
    func playlist(id: PlaylistID) async throws -> CatalogPage
}


extension Track {
    /// Delete API-derived fields before the 30-calendar-day storage ceiling.
    /// IDs and user-authored collection relationships are never removed here.
    /// Keep API display data in memory without depending on background cache expiry.
    public var localPersistenceSnapshot: Track {
        var saved = self
        if metadataOrigin == .youtubeDataAPI { saved.expireYouTubeMetadata(force: true) }
        return saved
    }

    public mutating func expireYouTubeMetadata(at now: Date = Date(), force: Bool = false) {
        guard case .youtubeVideo(let video) = source, metadataOrigin != .user, metadataOrigin != .placeholder else { return }
        guard force || metadataFetchedAt == nil || now.timeIntervalSince(metadataFetchedAt!) >= 29 * 86400 || metadataFetchedAt! > now else { return }
        title = "YouTube video \(video.rawValue)"; artist = "YouTube"
        durationMilliseconds = nil; metadataFetchedAt = nil; metadataOrigin = .placeholder
    }
}
