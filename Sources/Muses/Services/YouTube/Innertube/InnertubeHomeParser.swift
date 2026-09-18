import Foundation

/// Parses YouTube Music `browse` home (`FEmusic_home`) into Home sections.
enum InnertubeHomeParser {
    struct ParsedSection: Sendable {
        let id: String
        let title: String
        let cards: [YouTubeDiscoveryCard]
    }

    static func sections(from json: [String: Any], maxSections: Int = 12, maxItems: Int = 12) -> [ParsedSection] {
        var out: [ParsedSection] = []
        var seenIDs = Set<String>()

        walk(json) { node in
            guard out.count < maxSections else { return }
            guard let shelf = node["musicCarouselShelfRenderer"] as? [String: Any] else { return }
            let title = shelfTitle(shelf) ?? tr("Recommended", "推荐")
            let cards = shelfCards(shelf, limit: maxItems)
            guard !cards.isEmpty else { return }
            let id = stableSectionID(title: title, index: out.count)
            guard seenIDs.insert(id).inserted else { return }
            out.append(ParsedSection(id: id, title: title, cards: cards))
        }

        return out
    }

    // MARK: - Private

    private static func shelfTitle(_ shelf: [String: Any]) -> String? {
        if let header = shelf["header"] as? [String: Any],
           let basic = header["musicCarouselShelfBasicHeaderRenderer"] as? [String: Any] {
            return runsText(basic["title"])
        }
        return nil
    }

    private static func shelfCards(_ shelf: [String: Any], limit: Int) -> [YouTubeDiscoveryCard] {
        guard let contents = shelf["contents"] as? [[String: Any]] else { return [] }
        var cards: [YouTubeDiscoveryCard] = []
        for item in contents where cards.count < limit {
            if let twoRow = item["musicTwoRowItemRenderer"] as? [String: Any],
               let card = twoRowCard(twoRow) {
                cards.append(card)
            } else if let responsive = item["musicResponsiveListItemRenderer"] as? [String: Any],
                      let card = responsiveCard(responsive) {
                cards.append(card)
            }
        }
        return cards
    }

    private static func twoRowCard(_ renderer: [String: Any]) -> YouTubeDiscoveryCard? {
        let title = runsText(renderer["title"]) ?? ""
        guard !title.isEmpty else { return nil }
        let subtitle = runsText(renderer["subtitle"])
        let videoID = videoID(from: renderer["navigationEndpoint"])
            ?? videoID(from: renderer["thumbnailOverlay"])
        let playlistID = playlistID(from: renderer["navigationEndpoint"])
        let browseID = browseID(from: renderer["navigationEndpoint"])
        let thumb = thumbnailURL(from: renderer["thumbnailRenderer"] ?? renderer["thumbnail"])
        let id = videoID ?? playlistID ?? browseID ?? title
        let play: HomeCardEndpoint?
        let browse: HomeCardEndpoint?
        let availability: HomeCardAvailability
        if let videoID {
            play = HomeCardEndpoint(kind: .video, identifier: videoID)
            browse = nil
            availability = .available
        } else if let playlistID {
            play = HomeCardEndpoint(kind: .playlist, identifier: playlistID)
            browse = HomeCardEndpoint(kind: .playlist, identifier: playlistID)
            availability = .available
        } else if let browseID {
            play = nil
            browse = HomeCardEndpoint(kind: .browse, identifier: browseID)
            availability = .available
        } else {
            play = nil
            browse = nil
            availability = .unavailable
        }
        return YouTubeDiscoveryCard(
            id: id,
            title: title,
            uploader: subtitle,
            duration: nil,
            thumbnailURL: thumb,
            browseEndpoint: browse,
            playEndpoint: play,
            availability: availability
        )
    }

    private static func responsiveCard(_ renderer: [String: Any]) -> YouTubeDiscoveryCard? {
        let title = flexText(renderer, column: 0) ?? runsText(renderer["flexColumns"]) ?? ""
        guard !title.isEmpty else { return nil }
        let artist = flexText(renderer, column: 1)
        let videoID = videoID(from: renderer["playlistItemData"])
            ?? videoID(from: renderer["navigationEndpoint"])
            ?? videoID(from: renderer["overlay"])
        let thumb = thumbnailURL(from: renderer["thumbnail"] ?? renderer["thumbnailRenderer"])
        guard let videoID else { return nil }
        return YouTubeDiscoveryCard(
            id: videoID,
            title: title,
            uploader: artist,
            duration: nil,
            thumbnailURL: thumb
        )
    }

    private static func flexText(_ renderer: [String: Any], column: Int) -> String? {
        guard let columns = renderer["flexColumns"] as? [[String: Any]],
              column < columns.count,
              let flex = columns[column]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any] else {
            return nil
        }
        return runsText(flex["text"])
    }

    private static func runsText(_ value: Any?) -> String? {
        if let s = value as? String, !s.isEmpty { return s }
        if let dict = value as? [String: Any] {
            if let simple = dict["simpleText"] as? String, !simple.isEmpty { return simple }
            if let runs = dict["runs"] as? [[String: Any]] {
                let joined = runs.compactMap { $0["text"] as? String }.joined()
                return joined.isEmpty ? nil : joined
            }
        }
        if let runs = value as? [[String: Any]] {
            let joined = runs.compactMap { $0["text"] as? String }.joined()
            return joined.isEmpty ? nil : joined
        }
        return nil
    }

    private static func videoID(from value: Any?) -> String? {
        guard let value else { return nil }
        var found: String?
        walk(value) { node in
            if found != nil { return }
            if let id = node["videoId"] as? String, !id.isEmpty {
                found = id
            }
        }
        return found
    }

    private static func playlistID(from value: Any?) -> String? {
        guard let value else { return nil }
        var found: String?
        walk(value) { node in
            if found != nil { return }
            if let id = node["playlistId"] as? String, !id.isEmpty {
                found = id
            }
            if let watch = node["watchEndpoint"] as? [String: Any],
               let id = watch["playlistId"] as? String, !id.isEmpty {
                found = id
            }
        }
        return found
    }

    private static func browseID(from value: Any?) -> String? {
        guard let value else { return nil }
        var found: String?
        walk(value) { node in
            if found != nil { return }
            if let browse = node["browseEndpoint"] as? [String: Any],
               let id = browse["browseId"] as? String, !id.isEmpty {
                found = id
            }
        }
        return found
    }

    private static func thumbnailURL(from value: Any?) -> String? {
        guard let value else { return nil }
        var best: String?
        walk(value) { node in
            if let thumbs = node["thumbnails"] as? [[String: Any]] {
                if let url = thumbs.last?["url"] as? String, !url.isEmpty {
                    best = url
                }
            }
        }
        return best
    }

    private static func stableSectionID(title: String, index: Int) -> String {
        let slug = title.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        let trimmed = String(slug.prefix(40))
        return trimmed.isEmpty ? "ytm-home-\(index)" : "ytm-\(trimmed)"
    }

    private static func walk(_ node: Any, visit: ([String: Any]) -> Void) {
        if let dict = node as? [String: Any] {
            visit(dict)
            for value in dict.values {
                walk(value, visit: visit)
            }
        } else if let array = node as? [Any] {
            for value in array {
                walk(value, visit: visit)
            }
        }
    }
}
