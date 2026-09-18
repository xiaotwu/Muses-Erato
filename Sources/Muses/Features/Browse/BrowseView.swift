import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Browse / discovery: Innertube new releases + charts, genre search chips.
/// No demo tracks or fake `sample-…` video IDs.
struct BrowseView: View {
    @Bindable var playback: PlaybackService
    @Environment(YouTubeSearchService.self) private var searchService

    @State private var newReleases: [YTDlpPlaylistEntry] = []
    @State private var charts: [YTDlpPlaylistEntry] = []
    @State private var genreResults: [YTDlpPlaylistEntry] = []
    @State private var selectedGenre: String?
    @State private var isLoading = false
    @State private var isSearchingGenre = false
    @State private var loadError: String?

    private let genres = [
        "J-Pop", "Anime", "Lo-Fi", "Electronic",
        "Classical", "Rock", "R&B", "Hip-Hop"
    ]

    init(playback: PlaybackService) {
        self.playback = playback
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionSpacing) {
                    if let loadError, newReleases.isEmpty && charts.isEmpty {
                        EmptyStateView(
                            icon: "wifi.exclamationmark",
                            title: tr("Couldn’t load Browse", "无法加载发现页"),
                            subtitle: loadError
                        )
                        .padding(.top, 32)
                    } else {
                        shelfSection(
                            title: tr("New Releases", "新发行"),
                            entries: newReleases,
                            loading: isLoading && newReleases.isEmpty
                        )
                        shelfSection(
                            title: tr("Charts", "排行榜"),
                            entries: charts,
                            loading: isLoading && charts.isEmpty
                        )
                        genreGridSection
                        if selectedGenre != nil {
                            genreResultsSection
                        }
                    }
                    Color.clear.frame(height: 160)
                }
                .padding(.top, AppleMusicSpacing.pageTop)
            }
            .background(BrowseBackground())
            .navigationTitle(tr("Browse", "发现"))
            .refreshable { await loadCatalog(force: true) }
            .task { await loadCatalog(force: false) }
        }
    }

    private func shelfSection(title: String, entries: [YTDlpPlaylistEntry], loading: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionHeaderToContent) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(BrandColors.textPrimary)
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)

            if loading {
                ProgressView()
                    .tint(BrandColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if entries.isEmpty {
                Text(tr("Nothing here yet", "这里还没有内容"))
                    .font(.subheadline)
                    .foregroundStyle(BrandColors.textSecondary)
                    .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppleMusicSpacing.shelfItemSpacing) {
                        ForEach(entries) { entry in
                            entryCard(entry, width: 140)
                        }
                    }
                    .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
                }
            }
        }
    }

    private var genreGridSection: some View {
        VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionHeaderToContent) {
            Text(tr("Browse by Category", "按分类浏览"))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(BrandColors.textPrimary)
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(genres, id: \.self) { genre in
                    let selected = selectedGenre == genre
                    Button {
                        Task { await selectGenre(genre) }
                    } label: {
                        Text(genre)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(BrandColors.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: AppleMusicSpacing.hitTarget)
                            .background {
                                if selected {
                                    Color.clear
                                        .musesGlassCapsule(tint: BrandColors.accent.opacity(0.18), role: .compactControl)
                                        .laserStroke(Capsule(), lineWidth: 1.0, opacity: 0.7)
                                } else {
                                    Capsule().fill(BrandColors.surface.opacity(0.35))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
        }
    }

    private var genreResultsSection: some View {
        VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionHeaderToContent) {
            HStack {
                Text(selectedGenre.map { tr("Results · \($0)", "结果 · \($0)") } ?? "")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(BrandColors.textPrimary)
                Spacer()
                if isSearchingGenre {
                    ProgressView().tint(BrandColors.accent)
                }
            }
            .padding(.horizontal, AppleMusicSpacing.pageHorizontal)

            if !isSearchingGenre && genreResults.isEmpty {
                Text(tr("No tracks found for this category", "该分类暂无结果"))
                    .font(.subheadline)
                    .foregroundStyle(BrandColors.textSecondary)
                    .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
            } else {
                VStack(spacing: 8) {
                    ForEach(genreResults) { entry in
                        entryRow(entry)
                    }
                }
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
            }
        }
    }

    private func entryCard(_ entry: YTDlpPlaylistEntry, width: CGFloat) -> some View {
        Button {
            play(entry)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ArtworkView(
                    source: .resolve(remoteURL: YouTubeThumbnail.urlString(videoId: entry.id), youTubeId: entry.id),
                    cornerRadius: AppleMusicTokens.cardCornerRadius,
                    glyphSize: 36,
                    targetSize: width,
                    presentation: .fill
                )
                .frame(width: width, height: width)
                .clipped()

                Text(entry.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BrandColors.textPrimary)
                    .lineLimit(2)
                    .frame(width: width, alignment: .leading)

                Text(entry.uploader ?? "")
                    .font(.system(size: 12))
                    .foregroundStyle(BrandColors.textSecondary)
                    .lineLimit(1)
                    .frame(width: width, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private func entryRow(_ entry: YTDlpPlaylistEntry) -> some View {
        Button {
            play(entry)
        } label: {
            HStack(spacing: 12) {
                ArtworkView(
                    source: .resolve(remoteURL: YouTubeThumbnail.urlString(videoId: entry.id), youTubeId: entry.id),
                    cornerRadius: 8,
                    glyphSize: 16,
                    targetSize: 44,
                    presentation: .fill
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BrandColors.textPrimary)
                        .lineLimit(1)
                    Text(entry.uploader ?? "")
                        .font(.system(size: 13))
                        .foregroundStyle(BrandColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                if let duration = entry.duration, duration > 0 {
                    Text(formatDuration(duration))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(BrandColors.textTertiary)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: AppleMusicSpacing.hitTarget)
    }

    private func loadCatalog(force: Bool) async {
        if !force, (!newReleases.isEmpty || !charts.isEmpty) { return }
        isLoading = true
        loadError = nil
        let client = YouTubeResolver.shared.sharedInnertube
        async let releases = InnertubeCatalogBrowse.entries(
            client: client,
            browseId: YouTubeMusicCatalog.BrowseID.newReleases,
            limit: 16
        )
        async let chartEntries = InnertubeCatalogBrowse.entries(
            client: client,
            browseId: YouTubeMusicCatalog.BrowseID.charts,
            limit: 16
        )
        do {
            let (a, b) = try await (releases, chartEntries)
            newReleases = a
            charts = b
            if a.isEmpty && b.isEmpty {
                loadError = tr(
                    "Catalog returned no items. Pull to refresh or try again later.",
                    "目录为空，下拉刷新或稍后再试。"
                )
            }
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    private func selectGenre(_ genre: String) async {
        selectedGenre = genre
        isSearchingGenre = true
        genreResults = []
        do {
            genreResults = try await searchService.search(query: "\(genre) music", limit: 20)
        } catch {
            genreResults = []
        }
        isSearchingGenre = false
    }

    private func play(_ entry: YTDlpPlaylistEntry) {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        let track = TrackSnapshot(
            id: UUID(),
            title: entry.title,
            artist: entry.uploader ?? "",
            albumTitle: entry.album ?? entry.playlistTitle,
            durationSeconds: entry.duration ?? 0,
            youTubeId: entry.id,
            artworkUrl: YouTubeThumbnail.urlString(videoId: entry.id),
            sampleRate: nil,
            bitDepth: nil,
            codec: nil,
            isLossless: false
        )
        playback.play(track, from: .search)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
