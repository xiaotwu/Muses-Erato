import Foundation

/// Parses YouTube Music `search` responses into playlist/search entries.
enum InnertubeSearchParser {
    /// Prefer song shelves; fall back to any musicResponsiveListItem with a video id.
    static func entries(from json: [String: Any], limit: Int = 20) -> [YTDlpPlaylistEntry] {
        var songs: [YTDlpPlaylistEntry] = []
        var other: [YTDlpPlaylistEntry] = []
        var seen = Set<String>()

        walk(json) { node in
            guard songs.count + other.count < limit * 2 else { return }
            if let shelf = node["musicShelfRenderer"] as? [String: Any] {
                let title = runsText(shelf["title"]).lowercased()
                let isSongs = title.contains("song") || title.isEmpty
                for item in (shelf["contents"] as? [[String: Any]]) ?? [] {
                    guard let renderer = item["musicResponsiveListItemRenderer"] as? [String: Any],
                          let entry = songEntry(renderer) else { continue }
                    guard seen.insert(entry.id).inserted else { continue }
                    if isSongs {
                        songs.append(entry)
                    } else {
                        other.append(entry)
                    }
                }
            }
        }

        // Some shapes nest cards outside musicShelfRenderer.
        if songs.isEmpty && other.isEmpty {
            walk(json) { node in
                guard songs.count < limit else { return }
                if let renderer = node["musicResponsiveListItemRenderer"] as? [String: Any],
                   let entry = songEntry(renderer),
                   seen.insert(entry.id).inserted {
                    songs.append(entry)
                }
            }
        }

        var combined = songs
        if combined.count < limit {
            for entry in other where combined.count < limit {
                combined.append(entry)
            }
        }
        return Array(combined.prefix(limit))
    }

    private static func songEntry(_ renderer: [String: Any]) -> YTDlpPlaylistEntry? {
        let videoId = ((renderer["playlistItemData"] as? [String: Any])?["videoId"] as? String)
            ?? firstVideoId(in: renderer)
        guard let videoId, videoId.count == 11 else { return nil }
        let columns = renderer["flexColumns"] as? [[String: Any]] ?? []
        let texts = columns.map { column -> String in
            let text = (column["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"] as? [String: Any]
            return runsText(text)
        }
        let title = texts.first ?? ""
        guard !title.isEmpty else { return nil }
        let uploader = texts.dropFirst().first
        let channelID = firstChannelId(in: renderer)
        let duration = lengthTextSeconds(renderer)
        let entry = YTDlpPlaylistEntry(
            id: videoId,
            title: title,
            uploader: uploader?.isEmpty == true ? nil : uploader,
            duration: duration,
            channelID: channelID
        )
        return entry.resourceKind == .video ? entry : nil
    }

    private static func lengthTextSeconds(_ renderer: [String: Any]) -> Double? {
        var text: String?
        walk(renderer) { node in
            if text != nil { return }
            if let runs = (node["lengthText"] as? [String: Any])?["runs"] as? [[String: Any]] {
                text = runs.compactMap { $0["text"] as? String }.joined()
            } else if let simple = (node["lengthText"] as? [String: Any])?["simpleText"] as? String {
                text = simple
            }
        }
        guard let text else { return nil }
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard !parts.isEmpty else { return nil }
        if parts.count == 3 {
            return Double(parts[0] * 3600 + parts[1] * 60 + parts[2])
        }
        if parts.count == 2 {
            return Double(parts[0] * 60 + parts[1])
        }
        return Double(parts[0])
    }

    private static func firstVideoId(in node: Any) -> String? {
        var found: String?
        walk(node) { dict in
            if found != nil { return }
            if let id = dict["videoId"] as? String, id.count == 11 {
                found = id
            }
        }
        return found
    }

    private static func firstChannelId(in node: Any) -> String? {
        var found: String?
        walk(node) { dict in
            if found != nil { return }
            if let browse = dict["browseEndpoint"] as? [String: Any],
               let id = browse["browseId"] as? String,
               id.hasPrefix("UC") {
                found = id
            }
        }
        return found
    }

    private static func runsText(_ value: Any?) -> String {
        if let s = value as? String { return s }
        guard let dict = value as? [String: Any] else { return "" }
        if let simple = dict["simpleText"] as? String { return simple }
        if let runs = dict["runs"] as? [[String: Any]] {
            return runs.compactMap { $0["text"] as? String }.joined()
        }
        return ""
    }

    private static func walk(_ node: Any, visit: ([String: Any]) -> Void) {
        if let dict = node as? [String: Any] {
            visit(dict)
            for value in dict.values { walk(value, visit: visit) }
        } else if let array = node as? [Any] {
            for value in array { walk(value, visit: visit) }
        }
    }
}
