import Foundation

/// A single entry from a YouTube playlist or search result stream.
public struct YTDlpPlaylistEntry: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let uploader: String?
    public let duration: Double?
    public let playlistTitle: String?
    public let channelID: String?
    public let track: String?
    public let album: String?
    public let releaseYear: Int?

    public init(id: String,
                title: String,
                uploader: String? = nil,
                duration: Double? = nil,
                playlistTitle: String? = nil,
                channelID: String? = nil,
                track: String? = nil,
                album: String? = nil,
                releaseYear: Int? = nil) {
        self.id = id
        self.title = title
        self.uploader = uploader
        self.duration = duration
        self.playlistTitle = playlistTitle
        self.channelID = channelID
        self.track = track
        self.album = album
        self.releaseYear = releaseYear
    }

    var inferredMediaKind: TrackMediaKind {
        if track != nil || album != nil { return .song }
        let normalized = title.lowercased()
        let videoMarkers = [
            "official music video", "official video", "music video", "m/v", " mv",
            "官方mv", "音乐录像", "音樂錄影帶"
        ]
        return videoMarkers.contains(where: normalized.contains) ? .musicVideo : .song
    }

    enum ResourceKind: String, Sendable {
        case video, channel, playlist, unknown
    }

    /// Channels and playlists can appear in flat playlist dumps; only 11-character video ids are playable.
    var resourceKind: ResourceKind {
        guard id.utf8.allSatisfy({
            (65...90).contains($0) || (97...122).contains($0)
                || (48...57).contains($0) || $0 == 45 || $0 == 95
        }) else { return .unknown }
        if id.hasPrefix("UC"), id.count == 24 { return .channel }
        if id.count > 11, ["PL", "OLAK", "UU", "RD"].contains(where: id.hasPrefix) { return .playlist }
        return id.count == 11 ? .video : .unknown
    }
}

/// Backward compatibility namespace mapping to `YouTubeResolver`.
public typealias YTDlpBridge = YouTubeResolver

@MainActor
public protocol YTDlpBridgeProtocol: AnyObject {
    func resolveStreamURL(videoId: String, quality: String, timeout: TimeInterval) async throws -> URL
    func fetchPlaylist(url: String, timeout: TimeInterval) async throws -> [YTDlpPlaylistEntry]
    func searchYouTube(query: String, limit: Int, timeout: TimeInterval) async throws -> [YTDlpPlaylistEntry]
    func version() async -> String?
}

public extension YTDlpBridgeProtocol {
    func resolveStreamURL(videoId: String, quality: String = "bestaudio", timeout: TimeInterval = 20) async throws -> URL {
        try await resolveStreamURL(videoId: videoId, quality: quality, timeout: timeout)
    }

    func fetchPlaylist(url: String, timeout: TimeInterval = 20) async throws -> [YTDlpPlaylistEntry] {
        try await fetchPlaylist(url: url, timeout: timeout)
    }

    func searchYouTube(query: String, limit: Int = 20, timeout: TimeInterval = 15) async throws -> [YTDlpPlaylistEntry] {
        try await searchYouTube(query: query, limit: limit, timeout: timeout)
    }
}

/// Compatibility façade over `YouTubePlaybackResolver` + `InnertubeClient`.
/// New call sites should prefer those types directly; this type remains for existing bridges.
@MainActor
public final class YouTubeResolver: YTDlpBridgeProtocol {
    public typealias YTDlpPlaylistEntry = Muses.YTDlpPlaylistEntry

    public enum ResolverError: LocalizedError, Equatable, Sendable {
        case streamNotFound(String)
        case networkError(String)
        case timeout
        case invalidResponse

        public var errorDescription: String? {
            switch self {
            case .streamNotFound(let id):
                return InnertubeError.streamNotFound(id).errorDescription
            case .networkError(let msg):
                return InnertubeError.networkError(msg).errorDescription
            case .timeout:
                return InnertubeError.timeout.errorDescription
            case .invalidResponse:
                return InnertubeError.invalidResponse.errorDescription
            }
        }

        static func from(_ error: InnertubeError) -> ResolverError {
            switch error {
            case .streamNotFound(let id): return .streamNotFound(id)
            case .networkError(let msg): return .networkError(msg)
            case .timeout: return .timeout
            case .invalidResponse: return .invalidResponse
            }
        }
    }

    public static let shared = YouTubeResolver()
    private let session: URLSession
    private let playbackResolver: YouTubePlaybackResolver
    private let innertube: InnertubeClient
    private let log = AppLog.for("YouTubeResolver")

    public init(session: URLSession = .shared) {
        self.session = session
        let configuration = InnertubeConfiguration.default
        let client = InnertubeClient(session: session, configuration: configuration)
        self.innertube = client
        self.playbackResolver = YouTubePlaybackResolver(
            session: session,
            innertube: client,
            configuration: configuration
        )
    }

    public func version() async -> String? {
        "Muses-Erato Native Swift Engine 1.0 (iOS Sandboxed)"
    }

    public func resolveStreamURL(videoId: String, quality: String = "bestaudio", timeout: TimeInterval = 20) async throws -> URL {
        do {
            return try await playbackResolver.resolveStreamURL(videoID: videoId, quality: quality)
        } catch let error as InnertubeError {
            throw ResolverError.from(error)
        } catch {
            throw ResolverError.networkError(error.localizedDescription)
        }
    }

    public func invalidateCachedStream(videoId: String, quality: String = "bestaudio") {
        // Keep sync semantics for playback callers; cache is the source of truth.
        StreamURLCache.default.invalidate(videoId: videoId, quality: quality)
    }

    public func fetchPlaylist(url: String, timeout: TimeInterval = 20) async throws -> [YTDlpPlaylistEntry] {
        guard let listId = YouTubePlaylistURL.playlistID(from: url) else {
            return []
        }

        if let inner = try? await fetchPlaylistViaInnerTube(playlistId: listId, timeout: timeout),
           !inner.isEmpty {
            return inner
        }
        if let piped = await fetchPlaylistViaPiped(playlistId: listId, timeout: timeout),
           !piped.isEmpty {
            return piped
        }
        if let invidious = await fetchPlaylistViaInvidious(playlistId: listId, timeout: timeout),
           !invidious.isEmpty {
            return invidious
        }
        return []
    }

    public func searchYouTube(query: String, limit: Int = 20, timeout: TimeInterval = 15) async throws -> [YTDlpPlaylistEntry] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }

        let pipedEndpoints = [
            "https://pipedapi.kavin.rocks/search?q=\(encoded)&filter=music_songs",
            "https://api.piped.private.coffee/search?q=\(encoded)&filter=music_songs"
        ]

        for endpoint in pipedEndpoints {
            guard let reqUrl = URL(string: endpoint) else { continue }
            var req = URLRequest(url: reqUrl)
            req.timeoutInterval = timeout
            if let (data, resp) = try? await session.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let items = json["items"] as? [[String: Any]] {
                let parsed = items.prefix(limit).compactMap { item -> YTDlpPlaylistEntry? in
                    guard let urlStr = item["url"] as? String,
                          let id = urlStr.components(separatedBy: "v=").last,
                          let title = item["title"] as? String else { return nil }
                    let uploader = item["uploaderName"] as? String
                    let duration = (item["duration"] as? Double)
                        ?? (item["duration"] as? Int).map { Double($0) }
                    return YTDlpPlaylistEntry(
                        id: id,
                        title: title,
                        uploader: uploader,
                        duration: duration
                    )
                }
                if !parsed.isEmpty {
                    return parsed
                }
            }
        }

        return []
    }

    // MARK: - Playlist backends

    private func fetchPlaylistViaInnerTube(playlistId: String, timeout: TimeInterval) async throws -> [YTDlpPlaylistEntry] {
        let browseId = playlistId.hasPrefix("VL") ? playlistId : "VL" + playlistId
        var collected: [YTDlpPlaylistEntry] = []
        var seen = Set<String>()
        var continuation: String? = nil
        var page = 0
        repeat {
            page += 1
            let json = try await innertube.browse(
                browseId: continuation == nil ? browseId : nil,
                continuation: continuation,
                timeout: timeout
            )
            let parsed = InnertubeBrowseParser.innerTubeEntries(from: json)
            for entry in parsed.items where seen.insert(entry.id).inserted {
                collected.append(entry)
            }
            continuation = parsed.continuation
        } while continuation != nil && page < 25 && collected.count < 2_000
        return collected
    }

    private func fetchPlaylistViaPiped(playlistId: String, timeout: TimeInterval) async -> [YTDlpPlaylistEntry]? {
        let endpoints = [
            "https://api.piped.private.coffee/playlists/\(playlistId)",
            "https://pipedapi.kavin.rocks/playlists/\(playlistId)"
        ]
        for endpoint in endpoints {
            guard let reqUrl = URL(string: endpoint) else { continue }
            var req = URLRequest(url: reqUrl)
            req.timeoutInterval = timeout
            req.setValue("Muses-Erato/1.0", forHTTPHeaderField: "User-Agent")
            guard let (data, resp) = try? await session.data(for: req),
                  let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            let entries = InnertubeBrowseParser.pipedEntries(from: json)
            if !entries.isEmpty { return entries }
        }
        return nil
    }

    private func fetchPlaylistViaInvidious(playlistId: String, timeout: TimeInterval) async -> [YTDlpPlaylistEntry]? {
        let endpoints = [
            "https://yewtu.be/api/v1/playlists/\(playlistId)",
            "https://inv.nadeko.net/api/v1/playlists/\(playlistId)"
        ]
        for endpoint in endpoints {
            guard let reqUrl = URL(string: endpoint) else { continue }
            var req = URLRequest(url: reqUrl)
            req.timeoutInterval = timeout
            req.setValue("Muses-Erato/1.0", forHTTPHeaderField: "User-Agent")
            guard let (data, resp) = try? await session.data(for: req),
                  let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            let entries = InnertubeBrowseParser.invidiousEntries(from: json)
            if !entries.isEmpty { return entries }
        }
        return nil
    }
}
