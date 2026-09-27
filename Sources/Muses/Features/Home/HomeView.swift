import SwiftUI

/// Home tab: local library shelves + discovery + situational recommendations.
/// Honest empty states when the library and feeds have nothing to show — no demo cards.
struct HomeView: View {
    @Bindable var playback: PlaybackService
    @Binding var showSettings: Bool

    @Environment(HomeDiscoveryService.self) private var homeDiscovery
    @Environment(LibraryService.self) private var library

    init(playback: PlaybackService, showSettings: Binding<Bool>) {
        self.playback = playback
        self._showSettings = showSettings
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionSpacing) {
                    if homeDiscovery.sections.isEmpty && !homeDiscovery.isRefreshing {
                        EmptyStateView(
                            icon: "music.note.house",
                            title: tr("YouTube Music", "YouTube Music"),
                            subtitle: tr(
                                "Pull down to refresh YouTube Music recommendations.",
                                "下拉刷新以载入 YouTube Music 推荐内容。"
                            ),
                            showsEratoLogo: true
                        )
                        .padding(.top, 40)
                    } else {
                        ForEach(homeDiscovery.sections.filter { !$0.items.isEmpty || $0.status == .loading }) { section in
                            discoveryShelf(section)
                        }

                        if homeDiscovery.isRefreshing && homeDiscovery.sections.isEmpty {
                            ProgressView()
                                .tint(BrandColors.laurelGold)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 24)
                        }
                    }

                    Color.clear.frame(height: 160)
                }
                .padding(.top, AppleMusicSpacing.pageTop)
            }
            .background(BrowseBackground())
            .navigationTitle(tr("Home", "首页"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ChromeIconButton(
                        systemName: "gearshape",
                        help: tr("Settings", "设置"),
                        accessibility: tr("Settings", "设置")
                    ) {
                        triggerHaptic()
                        showSettings = true
                    }
                }
            }
            .task {
                homeDiscovery.load()
            }
            .refreshable {
                homeDiscovery.reload()
            }
        }
    }

    // MARK: - Discovery

    private func discoveryShelf(_ section: HomeSection) -> some View {
        VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionHeaderToContent) {
            HStack {
                Text(section.title)
                    .font(EratoTypography.poeticTitle(size: 22, weight: .bold))
                    .foregroundStyle(BrandColors.textPrimary)
                if case .loading = section.status {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, AppleMusicSpacing.pageHorizontal)

            if case .failed(let message) = section.status, section.items.isEmpty {
                Text(message ?? tr("Couldn’t load this shelf", "无法加载此分区"))
                    .font(.system(size: 13))
                    .foregroundStyle(BrandColors.textSecondary)
                    .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppleMusicSpacing.shelfItemSpacing) {
                        ForEach(section.items) { item in
                            discoveryCard(item)
                        }
                    }
                    .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
                }
            }
        }
    }

    @ViewBuilder
    private func discoveryCard(_ item: DiscoveryItem) -> some View {
        switch item {
        case .youTube(let card):
            Button {
                triggerHaptic()
                playYouTubeCard(card)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    ArtworkView(
                        source: .resolve(remoteURL: card.thumbnailURL, youTubeId: card.playableVideoID),
                        cornerRadius: AppleMusicTokens.cardCornerRadius,
                        glyphSize: 36,
                        targetSize: 140
                    )
                    .frame(width: 140, height: 140)
                    .clipped()

                    Text(card.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BrandColors.textPrimary)
                        .lineLimit(2)
                        .frame(width: 140, alignment: .leading)

                    Text(card.uploader ?? "")
                        .font(.system(size: 12))
                        .foregroundStyle(BrandColors.textSecondary)
                        .lineLimit(1)
                        .frame(width: 140, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

        case .track(let track):
            Button {
                triggerHaptic()
                playback.play(track, from: .songs)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    ArtworkView(
                        source: .resolve(for: track),
                        cornerRadius: AppleMusicTokens.cardCornerRadius,
                        glyphSize: 36,
                        targetSize: 140
                    )
                    .frame(width: 140, height: 140)
                    .clipped()

                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BrandColors.textPrimary)
                        .lineLimit(2)
                        .frame(width: 140, alignment: .leading)

                    Text(track.artist)
                        .font(.system(size: 12))
                        .foregroundStyle(BrandColors.textSecondary)
                        .lineLimit(1)
                        .frame(width: 140, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func playYouTubeCard(_ card: YouTubeDiscoveryCard) {
        if let videoId = card.playableVideoID, !videoId.isEmpty {
            let track = TrackSnapshot(
                id: UUID(),
                title: card.title,
                artist: card.uploader ?? "",
                albumTitle: nil,
                durationSeconds: card.duration ?? 0,
                youTubeId: videoId,
                artworkUrl: card.thumbnailURL,
                sampleRate: nil,
                bitDepth: nil,
                codec: nil,
                isLossless: false
            )
            playback.play(track, from: .search)
            return
        }

        // If card is a playlist or album without immediate video ID
        let identifier = card.playEndpoint?.identifier ?? card.browseEndpoint?.identifier
        guard let identifier, !identifier.isEmpty else { return }

        Task {
            let playlistURL: String
            if identifier.hasPrefix("http") {
                playlistURL = identifier
            } else if identifier.hasPrefix("VL") {
                playlistURL = "https://music.youtube.com/playlist?list=\(identifier.dropFirst(2))"
            } else if identifier.hasPrefix("MPREb_") {
                playlistURL = "https://music.youtube.com/playlist?list=\(identifier)"
            } else {
                playlistURL = "https://music.youtube.com/playlist?list=\(identifier)"
            }

            do {
                let entries = try await YouTubeResolver.shared.fetchPlaylist(url: playlistURL)
                let snaps = entries.filter { $0.resourceKind == .video || $0.id.count == 11 }.map { entry in
                    TrackSnapshot(
                        id: UUID(),
                        title: entry.title,
                        artist: entry.uploader ?? card.uploader ?? "",
                        albumTitle: card.title,
                        durationSeconds: entry.duration ?? 0,
                        youTubeId: entry.id,
                        artworkUrl: YouTubeThumbnail.urlString(videoId: entry.id),
                        sampleRate: nil,
                        bitDepth: nil,
                        codec: nil,
                        isLossless: false
                    )
                }
                if let first = snaps.first {
                    playback.playTrack(first, context: snaps, from: .playlist)
                }
            } catch {
                if let results = try? await YouTubeResolver.shared.searchYouTube(query: "\(card.title) \(card.uploader ?? "")", limit: 10),
                   let first = results.first {
                    let track = TrackSnapshot(
                        id: UUID(),
                        title: first.title,
                        artist: first.uploader ?? card.uploader ?? "",
                        albumTitle: card.title,
                        durationSeconds: first.duration ?? 0,
                        youTubeId: first.id,
                        artworkUrl: YouTubeThumbnail.urlString(videoId: first.id),
                        sampleRate: nil,
                        bitDepth: nil,
                        codec: nil,
                        isLossless: false
                    )
                    playback.play(track, from: .search)
                }
            }
        }
    }

    private func triggerHaptic() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

