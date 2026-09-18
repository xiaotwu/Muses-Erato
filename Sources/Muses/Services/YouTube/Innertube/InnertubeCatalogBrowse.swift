import Foundation

/// Thin catalog browse helpers over Innertube `browse` + home/shelf parsers.
enum InnertubeCatalogBrowse {
    /// Browse a Music catalog shelf (charts / new releases / moods) into search-compatible entries.
    @MainActor
    static func entries(
        client: InnertubeClient,
        browseId: String,
        limit: Int = 20,
        timeout: TimeInterval = 20
    ) async throws -> [YTDlpPlaylistEntry] {
        let json = try await client.browse(browseId: browseId, continuation: nil, timeout: timeout)
        let sections = InnertubeHomeParser.sections(from: json, maxSections: 8, maxItems: limit)
        var out: [YTDlpPlaylistEntry] = []
        var seen = Set<String>()
        for section in sections {
            for card in section.cards {
                guard let videoID = card.playableVideoID, seen.insert(videoID).inserted else { continue }
                out.append(
                    YTDlpPlaylistEntry(
                        id: videoID,
                        title: card.title,
                        uploader: card.uploader,
                        duration: card.duration,
                        playlistTitle: section.title
                    )
                )
                if out.count >= limit { return out }
            }
        }
        if out.isEmpty {
            let (items, _) = InnertubeBrowseParser.innerTubeEntries(from: json)
            for entry in items where seen.insert(entry.id).inserted {
                out.append(entry)
                if out.count >= limit { break }
            }
        }
        return out
    }
}
