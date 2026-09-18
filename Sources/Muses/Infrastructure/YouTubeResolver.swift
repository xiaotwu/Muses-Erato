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

/// Backward compatibility namespace mapping to `YTDlpPlaylistEntry`.
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

/// Native Swift stream resolver for YouTube audio, replacing the macOS subprocess `yt-dlp` binary.
/// Uses YouTube InnerTube API with fallback to Piped / Invidious public streaming instances,
/// ensuring 100% iOS sandbox compliance and zero external executable dependencies.
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
                return tr("No audio stream found for video: \(id)", "未找到视频的音频流：\(id)")
            case .networkError(let msg):
                return tr("Network error: \(msg)", "网络错误：\(msg)")
            case .timeout:
                return tr("Request timed out", "请求超时")
            case .invalidResponse:
                return tr("Invalid response from YouTube service", "YouTube 服务响应无效")
            }
        }
    }

    public static let shared = YouTubeResolver()
    private let session: URLSession
    private let log = AppLog.for("YouTubeResolver")

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func version() async -> String? {
        "Muses-Erato Native Swift Engine 1.0 (iOS Sandboxed)"
    }

    /// Resolves direct audio stream URL for a given YouTube Video ID.
    public func resolveStreamURL(videoId: String, quality: String = "bestaudio", timeout: TimeInterval = 20) async throws -> URL {
        // 1. Check local memory / disk stream cache
        if let cached = StreamURLCache.default.get(videoId: videoId, quality: quality) {
            return cached
        }

        // 2. Check bundled sample audio
        if let sample = Bundle.main.url(forResource: videoId, withExtension: "mp3")
            ?? Bundle.main.url(forResource: videoId, withExtension: "m4a") {
            return sample
        }

        do {
            let url = try await resolveViaInnerTube(videoId: videoId, timeout: timeout)
            StreamURLCache.default.set(videoId: videoId, url: url, quality: quality)
            return url
        } catch {
            log.warning("InnerTube resolution failed for \(videoId): \(error.localizedDescription)")
        }

        do {
            let url = try await resolveViaPiped(videoId: videoId, timeout: timeout)
            StreamURLCache.default.set(videoId: videoId, url: url, quality: quality)
            return url
        } catch {
            log.warning("Piped resolution failed for \(videoId): \(error.localizedDescription)")
        }

        do {
            let url = try await resolveViaInvidious(videoId: videoId, timeout: timeout)
            StreamURLCache.default.set(videoId: videoId, url: url, quality: quality)
            return url
        } catch {
            log.error("All stream resolution methods failed for \(videoId): \(error.localizedDescription)")
            throw ResolverError.streamNotFound(videoId)
        }
    }

    /// Fetches playlist entries from a YouTube or YouTube Music playlist URL.
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

    /// Searches YouTube for tracks matching query.
    public func searchYouTube(query: String, limit: Int = 20, timeout: TimeInterval = 15) async throws -> [YTDlpPlaylistEntry] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }

        // Try Piped Music Search first
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
            let json = try await innertubeBrowse(
                browseId: continuation == nil ? browseId : nil,
                continuation: continuation,
                timeout: timeout
            )
            let parsed = YouTubePlaylistParser.innerTubeEntries(from: json)
            for entry in parsed.items where seen.insert(entry.id).inserted {
                collected.append(entry)
            }
            continuation = parsed.continuation
        } while continuation != nil && page < 25 && collected.count < 2_000
        return collected
    }

    private func innertubeBrowse(
        browseId: String?,
        continuation: String?,
        timeout: TimeInterval
    ) async throws -> [String: Any] {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/browse?prettyPrint=false") else {
            throw ResolverError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        var payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20240617.01.00"
                ]
            ]
        ]
        if let continuation {
            payload["continuation"] = continuation
        } else if let browseId {
            payload["browseId"] = browseId
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ResolverError.invalidResponse
        }
        return json
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
            let entries = YouTubePlaylistParser.pipedEntries(from: json)
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
            let entries = YouTubePlaylistParser.invidiousEntries(from: json)
            if !entries.isEmpty { return entries }
        }
        return nil
    }

    // MARK: - Private InnerTube Resolution

    private func resolveViaInnerTube(videoId: String, timeout: TimeInterval) async throws -> URL {
        for client in YouTubeInnerTubeClient.allCases {
            if let url = try? await playerURL(videoId: videoId, client: client, timeout: timeout) {
                return url
            }
        }
        throw ResolverError.streamNotFound(videoId)
    }

    private func playerURL(
        videoId: String,
        client: YouTubeInnerTubeClient,
        timeout: TimeInterval
    ) async throws -> URL {
        guard let endpoint = URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false") else {
            throw ResolverError.invalidResponse
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue(client.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: client.playerPayload(videoId: videoId))
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let url = YouTubeStreamParser.audioURL(from: json) else {
            throw ResolverError.invalidResponse
        }
        return url
    }

    // MARK: - Private Piped Fallback

    private func resolveViaPiped(videoId: String, timeout: TimeInterval) async throws -> URL {
        let instances = [
            "https://api.piped.private.coffee/streams/\(videoId)",
            "https://pipedapi.kavin.rocks/streams/\(videoId)",
            "https://pipedapi.adminforge.de/streams/\(videoId)"
        ]

        for instance in instances {
            guard let url = URL(string: instance) else { continue }
            var req = URLRequest(url: url)
            req.timeoutInterval = timeout
            req.setValue("Muses-Erato/1.0", forHTTPHeaderField: "User-Agent")
            if let (data, resp) = try? await session.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let audioStreams = json["audioStreams"] as? [[String: Any]] {
                let sorted = audioStreams.sorted {
                    (($0["bitrate"] as? Int) ?? 0) > (($1["bitrate"] as? Int) ?? 0)
                }
                if let best = sorted.first,
                   let streamUrlStr = best["url"] as? String,
                   let streamURL = URL(string: streamUrlStr) {
                    return streamURL
                }
            }
        }

        throw ResolverError.streamNotFound(videoId)
    }

    private func resolveViaInvidious(videoId: String, timeout: TimeInterval) async throws -> URL {
        let instances = [
            "https://yewtu.be/api/v1/videos/\(videoId)",
            "https://inv.nadeko.net/api/v1/videos/\(videoId)"
        ]
        for instance in instances {
            guard let url = URL(string: instance) else { continue }
            var req = URLRequest(url: url)
            req.timeoutInterval = timeout
            req.setValue("Muses-Erato/1.0", forHTTPHeaderField: "User-Agent")
            guard let (data, resp) = try? await session.data(for: req),
                  let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let stream = YouTubeStreamParser.invidiousAudioURL(from: json) else {
                continue
            }
            return stream
        }
        throw ResolverError.streamNotFound(videoId)
    }
}

enum YouTubeInnerTubeClient: CaseIterable {
    case androidVR
    case ios
    case webEmbedded

    var userAgent: String {
        switch self {
        case .androidVR:
            return "com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12; eureka-user Build/SQ3A.220605.009.A1) gzip"
        case .ios:
            return "com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 18_0 like Mac OS X)"
        case .webEmbedded:
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15"
        }
    }

    func playerPayload(videoId: String) -> [String: Any] {
        switch self {
        case .androidVR:
            return [
                "videoId": videoId,
                "context": [
                    "client": [
                        "clientName": "ANDROID_VR",
                        "clientVersion": "1.60.19",
                        "deviceMake": "Oculus",
                        "deviceModel": "Quest 3",
                        "androidSdkVersion": 32,
                        "osName": "Android",
                        "osVersion": "12",
                        "hl": "en",
                        "gl": "US"
                    ]
                ]
            ]
        case .ios:
            return [
                "videoId": videoId,
                "context": [
                    "client": [
                        "clientName": "IOS",
                        "clientVersion": "19.29.1",
                        "deviceMake": "Apple",
                        "deviceModel": "iPhone16,2",
                        "osName": "iOS",
                        "osVersion": "18.0.0"
                    ]
                ]
            ]
        case .webEmbedded:
            return [
                "videoId": videoId,
                "context": [
                    "client": [
                        "clientName": "WEB_EMBEDDED_PLAYER",
                        "clientVersion": "1.20240324.01.00",
                        "hl": "en",
                        "gl": "US"
                    ],
                    "thirdParty": [
                        "embedUrl": "https://www.youtube.com/"
                    ]
                ]
            ]
        }
    }
}

enum YouTubeStreamParser {
    static func audioURL(from playerJSON: [String: Any]) -> URL? {
        guard let streaming = playerJSON["streamingData"] as? [String: Any] else { return nil }
        let adaptive = streaming["adaptiveFormats"] as? [[String: Any]] ?? []
        let progressive = streaming["formats"] as? [[String: Any]] ?? []
        let combined = adaptive + progressive
        let audio = combined.filter { format in
            let mime = (format["mimeType"] as? String) ?? ""
            return mime.contains("audio/") || format["audioQuality"] != nil
        }
        let ranked = (audio.isEmpty ? combined : audio).sorted {
            numericBitrate($0) > numericBitrate($1)
        }
        for format in ranked {
            if let url = url(fromFormat: format) { return url }
        }
        return nil
    }

    static func url(fromFormat format: [String: Any]) -> URL? {
        if let raw = format["url"] as? String, let url = URL(string: raw) {
            return url
        }
        let cipher = (format["signatureCipher"] as? String) ?? (format["cipher"] as? String)
        guard let cipher else { return nil }
        return url(fromCipher: cipher)
    }

    static func url(fromCipher cipher: String) -> URL? {
        var items: [String: String] = [:]
        for pair in cipher.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            items[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
        }
        guard var urlString = items["url"], !urlString.isEmpty else { return nil }
        if urlString.contains("sig=") || urlString.contains("signature=") {
            return URL(string: urlString)
        }
        guard let signature = items["s"], !signature.isEmpty else {
            return URL(string: urlString)
        }
        let parameter = items["sp"] ?? "signature"
        let separator = urlString.contains("?") ? "&" : "?"
        let encoded = signature.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? signature
        urlString += "\(separator)\(parameter)=\(encoded)"
        return URL(string: urlString)
    }

    static func invidiousAudioURL(from json: [String: Any]) -> URL? {
        let adaptive = json["adaptiveFormats"] as? [[String: Any]] ?? []
        let progressive = json["formatStreams"] as? [[String: Any]] ?? []
        let combined = adaptive + progressive
        let audio = combined.filter { format in
            let type = (format["type"] as? String) ?? ""
            return type.contains("audio/")
        }
        let ranked = (audio.isEmpty ? combined : audio).sorted {
            numericBitrate($0) > numericBitrate($1)
        }
        for format in ranked {
            if let raw = format["url"] as? String, let url = URL(string: raw) {
                return url
            }
        }
        return nil
    }

    private static func numericBitrate(_ format: [String: Any]) -> Int {
        (format["bitrate"] as? Int)
            ?? (format["bitrate"] as? String).flatMap(Int.init)
            ?? 0
    }
}

enum YouTubePlaylistURL {
    static func playlistID(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidates = trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
            ? [trimmed]
            : [trimmed, "https://\(trimmed)"]
        for candidate in candidates {
            if let comps = URLComponents(string: candidate),
               let list = comps.queryItems?.first(where: { $0.name == "list" })?.value,
               !list.isEmpty {
                return list
            }
        }
        guard let match = trimmed.range(of: #"list=([A-Za-z0-9_-]+)"#, options: .regularExpression) else {
            return nil
        }
        let token = String(trimmed[match]).replacingOccurrences(of: "list=", with: "")
        return token.isEmpty ? nil : token
    }
}

enum YouTubePlaylistParser {
    static func innerTubeEntries(from json: [String: Any]) -> (items: [YTDlpPlaylistEntry], continuation: String?) {
        let title = ((json["microformat"] as? [String: Any])?["microformatDataRenderer"] as? [String: Any])?["title"] as? String
        var items: [YTDlpPlaylistEntry] = []
        var continuation: String?

        func ingest(_ node: Any) {
            walk(node) { candidate in
                if continuation == nil,
                   let token = (candidate["continuationCommand"] as? [String: Any])?["token"] as? String {
                    continuation = token
                }
                if let renderer = candidate["musicResponsiveListItemRenderer"] as? [String: Any],
                   let entry = musicShelfEntry(renderer, playlistTitle: title) {
                    items.append(entry)
                } else if let renderer = candidate["playlistVideoRenderer"] as? [String: Any],
                          let entry = webVideoEntry(renderer, playlistTitle: title) {
                    items.append(entry)
                }
            }
        }

        var foundShelf = false
        walk(json) { node in
            if let shelf = node["musicPlaylistShelfRenderer"] {
                foundShelf = true
                ingest(shelf)
            }
            if let list = node["playlistVideoListRenderer"] {
                foundShelf = true
                ingest(list)
            }
            if let append = node["appendContinuationItemsAction"] {
                foundShelf = true
                ingest(append)
            }
        }
        if !foundShelf {
            ingest(json)
        }
        return (items, continuation)
    }

    static func pipedEntries(from json: [String: Any]) -> [YTDlpPlaylistEntry] {
        let playlistTitle = json["name"] as? String
        let streams: [[String: Any]]
        if let related = json["relatedStreams"] as? [[String: Any]], !related.isEmpty {
            streams = related
        } else if let videos = json["videos"] as? [[String: Any]], !videos.isEmpty {
            streams = videos
        } else {
            streams = []
        }
        return streams.compactMap { stream in
            pipedStreamEntry(stream, playlistTitle: playlistTitle)
        }
    }

    static func invidiousEntries(from json: [String: Any]) -> [YTDlpPlaylistEntry] {
        let playlistTitle = json["title"] as? String
        let videos = json["videos"] as? [[String: Any]] ?? []
        return videos.compactMap { video in
            let id = (video["videoId"] as? String) ?? (video["videoID"] as? String)
            let title = video["title"] as? String
            guard let id, let title else { return nil }
            let entry = YTDlpPlaylistEntry(
                id: id,
                title: title,
                uploader: video["author"] as? String,
                duration: (video["lengthSeconds"] as? Double) ?? (video["lengthSeconds"] as? Int).map(Double.init),
                playlistTitle: playlistTitle
            )
            return entry.resourceKind == .video ? entry : nil
        }
    }

    private static func musicShelfEntry(_ renderer: [String: Any], playlistTitle: String?) -> YTDlpPlaylistEntry? {
        let videoId = ((renderer["playlistItemData"] as? [String: Any])?["videoId"] as? String)
            ?? firstVideoId(in: renderer)
        guard let videoId else { return nil }
        let columns = renderer["flexColumns"] as? [[String: Any]] ?? []
        let texts = columns.map { column -> String in
            let text = (column["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"] as? [String: Any]
            return runsText(text)
        }
        let title = texts.first ?? ""
        guard !title.isEmpty else { return nil }
        let entry = YTDlpPlaylistEntry(
            id: videoId,
            title: title,
            uploader: texts.dropFirst().first,
            playlistTitle: playlistTitle
        )
        return entry.resourceKind == .video ? entry : nil
    }

    private static func webVideoEntry(_ renderer: [String: Any], playlistTitle: String?) -> YTDlpPlaylistEntry? {
        guard let videoId = renderer["videoId"] as? String else { return nil }
        let title = runsText(renderer["title"] as? [String: Any])
        guard !title.isEmpty else { return nil }
        let entry = YTDlpPlaylistEntry(
            id: videoId,
            title: title,
            uploader: runsText(renderer["shortBylineText"] as? [String: Any]),
            playlistTitle: playlistTitle
        )
        return entry.resourceKind == .video ? entry : nil
    }

    private static func pipedStreamEntry(_ stream: [String: Any], playlistTitle: String?) -> YTDlpPlaylistEntry? {
        guard let title = stream["title"] as? String else { return nil }
        let id: String
        if let videoId = stream["id"] as? String, !videoId.isEmpty {
            id = videoId
        } else if let urlStr = stream["url"] as? String {
            if let comps = URLComponents(string: urlStr.replacingOccurrences(of: "/watch?", with: "https://youtube.com/watch?")),
               let v = comps.queryItems?.first(where: { $0.name == "v" })?.value, !v.isEmpty {
                id = v
            } else {
                id = urlStr.replacingOccurrences(of: "/watch?v=", with: "")
            }
        } else {
            return nil
        }
        let entry = YTDlpPlaylistEntry(
            id: id,
            title: title,
            uploader: stream["uploaderName"] as? String,
            duration: (stream["duration"] as? Double) ?? (stream["duration"] as? Int).map(Double.init),
            playlistTitle: playlistTitle
        )
        return entry.resourceKind == .video ? entry : nil
    }

    private static func runsText(_ node: [String: Any]?) -> String {
        guard let node else { return "" }
        if let simple = node["simpleText"] as? String { return simple }
        let runs = node["runs"] as? [[String: Any]] ?? []
        return runs.compactMap { $0["text"] as? String }.joined()
    }

    private static func firstVideoId(in node: [String: Any]) -> String? {
        var found: String?
        walk(node) { candidate in
            if found == nil, let videoId = candidate["videoId"] as? String,
               YTDlpPlaylistEntry(id: videoId, title: "x").resourceKind == .video {
                found = videoId
            }
        }
        return found
    }

    private static func walk(_ value: Any, visit: ([String: Any]) -> Void) {
        if let dict = value as? [String: Any] {
            visit(dict)
            for nested in dict.values {
                walk(nested, visit: visit)
            }
        } else if let array = value as? [Any] {
            for nested in array {
                walk(nested, visit: visit)
            }
        }
    }
}
