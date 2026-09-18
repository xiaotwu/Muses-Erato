import Foundation

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

enum InnertubeBrowseParser {
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

typealias YouTubePlaylistParser = InnertubeBrowseParser
