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

        // 1. Direct playable video cards from sections (e.g. music videos)
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

        // 2. If no direct video cards found (e.g. FEmusic_charts contains curated playlists),
        // resolve the chart playlists to extract top chart tracks
        if out.isEmpty {
            for section in sections {
                for card in section.cards {
                    let pid = card.playEndpoint?.identifier ?? card.browseEndpoint?.identifier
                    if let pid, !pid.isEmpty {
                        let playlistBrowseId = pid.hasPrefix("VL") ? pid : (pid.hasPrefix("PL") ? "VL\(pid)" : pid)
                        if let playlistJson = try? await client.browse(browseId: playlistBrowseId, continuation: nil, timeout: timeout) {
                            let (items, _) = InnertubeBrowseParser.innerTubeEntries(from: playlistJson)
                            for entry in items where seen.insert(entry.id).inserted {
                                out.append(entry)
                                if out.count >= limit { return out }
                            }
                        }
                    }
                    if out.count >= limit { return out }
                }
            }
        }

        // 3. Fall back to direct shelf entries in root json
        if out.isEmpty {
            let (items, _) = InnertubeBrowseParser.innerTubeEntries(from: json)
            for entry in items where seen.insert(entry.id).inserted {
                out.append(entry)
                if out.count >= limit { break }
            }
        }

        // 4. If still empty, map available discovery cards directly so they can be browsed/played
        if out.isEmpty {
            for section in sections {
                for card in section.cards {
                    let id = card.playEndpoint?.identifier ?? card.browseEndpoint?.identifier ?? card.id
                    guard seen.insert(id).inserted else { continue }
                    out.append(
                        YTDlpPlaylistEntry(
                            id: id,
                            title: card.title,
                            uploader: card.uploader,
                            duration: card.duration,
                            playlistTitle: section.title
                        )
                    )
                    if out.count >= limit { return out }
                }
            }
        }

        return out
    }
}
