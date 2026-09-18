import SwiftUI

/// Home tab: local library shelves + discovery + situational recommendations.
/// Honest empty states when the library and feeds have nothing to show — no demo cards.
struct HomeView: View {
    @Bindable var playback: PlaybackService
    @Binding var showSettings: Bool

    @Environment(HomeDiscoveryService.self) private var homeDiscovery
    @Environment(LibraryService.self) private var library
    @Environment(SituationalRecommendationService.self) private var situational

    @State private var situationalSections: [SituationalSection] = []
    @State private var isLoadingSituational = false
    @AppStorage(PrefKey.homeRecommendationMode) private var homeRecommendationModeRaw: String = HomeRecommendationMode.muses.rawValue

    init(playback: PlaybackService, showSettings: Binding<Bool>) {
        self.playback = playback
        self._showSettings = showSettings
    }

    private var recentTracks: [TrackSnapshot] {
        library.recentlyPlayedTracks(limit: 12)
    }

    private var libraryIsEmpty: Bool {
        library.allTracks().isEmpty
    }

    private var hasAnyContent: Bool {
        !recentTracks.isEmpty
            || !homeDiscovery.sections.contains(where: { !$0.items.isEmpty })
            || !situationalSections.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionSpacing) {
                    if libraryIsEmpty && !hasAnyContent && !homeDiscovery.isRefreshing {
                        EmptyStateView(
                            icon: "music.note.house",
                            title: tr("Your library is empty", "资料库为空"),
                            subtitle: tr(
                                "Import music or search YouTube to start listening. Home will show Listen Again and recommendations here.",
                                "导入音乐或搜索 YouTube 后，首页会显示「再听一次」和推荐内容。"
                            )
                        )
                        .padding(.top, 40)
                    } else {
                        if !recentTracks.isEmpty {
                            listenAgainSection
                        }

                        if situational.isEnabled && !situationalSections.isEmpty {
                            ForEach(situationalSections) { section in
                                situationalShelf(section)
                            }
                        }

                        ForEach(homeDiscovery.sections.filter { !$0.items.isEmpty || $0.status == .loading }) { section in
                            discoveryShelf(section)
                        }

                        if homeDiscovery.isRefreshing && homeDiscovery.sections.isEmpty {
                            ProgressView()
                                .tint(BrandColors.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 24)
                        }
                    }

                    Color.clear.frame(height: 120)
                }
                .padding(.top, AppleMusicSpacing.pageTop)
            }
            .background(BrandColors.background)
            .navigationTitle(tr("Home", "首页"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker(
                            tr("Recommendation source", "推荐来源"),
                            selection: $homeRecommendationModeRaw
                        ) {
                            ForEach(HomeRecommendationMode.allCases) { mode in
                                Text(mode.title).tag(mode.rawValue)
                            }
                        }
                    } label: {
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(BrandColors.textPrimary)
                    }
                    .accessibilityLabel(tr("Recommendation source", "推荐来源"))
                }
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
            .onChange(of: homeRecommendationModeRaw) { _, _ in
                homeDiscovery.reload()
            }
            .task {
                homeDiscovery.load()
                await refreshSituational()
            }
            .refreshable {
                homeDiscovery.reload()
                await refreshSituational()
            }
        }
    }

    // MARK: - Listen Again

    private var listenAgainSection: some View {
        VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionHeaderToContent) {
            Text(tr("Listen Again", "再听一次"))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(BrandColors.textPrimary)
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppleMusicSpacing.shelfItemSpacing) {
                    ForEach(recentTracks) { track in
                        Button {
                            triggerHaptic()
                            playback.play(track, context: recentTracks, from: .recently)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ArtworkView(
                                    source: .resolve(for: track),
                                    cornerRadius: AppleMusicTokens.cardCornerRadius,
                                    glyphSize: 36,
                                    targetSize: 140
                                )
                                .frame(width: 140, height: 140)
                                .shadow(color: .black.opacity(0.1), radius: 6, y: 3)

                                Text(track.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(BrandColors.textPrimary)
                                    .lineLimit(1)
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
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
            }
        }
    }

    // MARK: - Situational

    private func situationalShelf(_ section: SituationalSection) -> some View {
        VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionHeaderToContent) {
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(BrandColors.textPrimary)
                if let subtitle = section.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(BrandColors.textSecondary)
                }
            }
            .padding(.horizontal, AppleMusicSpacing.pageHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppleMusicSpacing.shelfItemSpacing) {
                    ForEach(section.items) { track in
                        Button {
                            triggerHaptic()
                            playback.play(track, context: section.items, from: .songs)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ArtworkView(
                                    source: .resolve(for: track),
                                    cornerRadius: AppleMusicTokens.cardCornerRadius,
                                    glyphSize: 36,
                                    targetSize: 140
                                )
                                .frame(width: 140, height: 140)

                                Text(track.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(BrandColors.textPrimary)
                                    .lineLimit(1)
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
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
            }
        }
    }

    // MARK: - Discovery

    private func discoveryShelf(_ section: HomeSection) -> some View {
        VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionHeaderToContent) {
            HStack {
                Text(section.title)
                    .font(.system(size: 22, weight: .bold))
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
        guard let videoId = card.playableVideoID, !videoId.isEmpty else { return }
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
    }

    private func refreshSituational() async {
        guard situational.isEnabled else {
            situationalSections = []
            return
        }
        isLoadingSituational = true
        situationalSections = await situational.compute()
        isLoadingSituational = false
    }

    private func triggerHaptic() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
