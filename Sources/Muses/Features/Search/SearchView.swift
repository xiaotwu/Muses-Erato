import SwiftUI

/// Real-time YouTube & Library search view for iOS.
struct SearchView: View {
    @Bindable var playback: PlaybackService

    @State private var query: String = ""
    @State private var isSearching: Bool = false
    @State private var results: [YTDlpPlaylistEntry] = []
    @State private var searchTask: Task<Void, Never>?

    private let suggestions = [
        "Triumph on the Ice", "Monster Siren Records", "酸橙色信笺",
        "芽吹の唄", "Radwimps", "Lo-Fi Chill", "Genshin Impact OST"
    ]

    init(playback: PlaybackService) {
        self.playback = playback
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    if query.isEmpty {
                        // Search Suggestions Tags
                        suggestionChipsSection
                    } else if isSearching {
                        // Searching progress indicator
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(BrandColors.accent)
                                .padding(.top, 40)
                            Spacer()
                        }
                    } else if results.isEmpty {
                        // Empty State
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundStyle(BrandColors.textTertiary)
                            Text(tr("No Results Found", "未找到相关内容"))
                                .font(.headline)
                                .foregroundStyle(BrandColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        // Results List
                        resultsListSection
                    }

                    Color.clear.frame(height: 120)
                }
                .padding(.top, AppleMusicSpacing.pageTop)
            }
            .background(BrandColors.background)
            .navigationTitle(tr("Search", "搜索"))
            .searchable(text: $query, prompt: tr("Artists, Songs, Lyrics, and More", "艺人、歌曲、歌词等"))
            .onChange(of: query) { _, newQuery in
                performSearch(query: newQuery)
            }
        }
    }

    // MARK: - Suggestion Chips

    private var suggestionChipsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("Trending Searches", "热门搜索"))
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(BrandColors.textPrimary)
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(suggestions, id: \.self) { tag in
                        Button {
                            triggerHapticFeedback()
                            query = tag
                        } label: {
                            Text(tag)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(BrandColors.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(BrandColors.surface, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
            }
        }
    }

    // MARK: - Results List

    private var resultsListSection: some View {
        VStack(spacing: 8) {
            ForEach(results) { entry in
                Button {
                    triggerHapticFeedback()
                    playEntry(entry)
                } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(BrandColors.surface)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 20))
                                    .foregroundStyle(BrandColors.accent)
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(BrandColors.textPrimary)
                                .lineLimit(1)

                            Text(entry.uploader ?? "YouTube Music")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(BrandColors.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if let dur = entry.duration {
                            Text(formatDuration(dur))
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(BrandColors.textTertiary)
                        }

                        Image(systemName: "play.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(BrandColors.accent)
                    }
                    .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        playEntry(entry)
                    } label: {
                        Label(tr("Play Now", "立即播放"), systemImage: "play")
                    }

                    Button {
                        addToQueue(entry)
                    } label: {
                        Label(tr("Play Next", "下一首播放"), systemImage: "text.insert")
                    }
                }
            }
        }
    }

    private func performSearch(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            if let res = try? await YouTubeResolver.shared.searchYouTube(query: trimmed, limit: 15) {
                guard !Task.isCancelled else { return }
                self.results = res
            }
            self.isSearching = false
        }
    }

    private func playEntry(_ entry: YTDlpPlaylistEntry) {
        let track = TrackSnapshot(
            id: UUID(),
            title: entry.title,
            artist: entry.uploader ?? "YouTube Artist",
            albumTitle: entry.playlistTitle,
            durationSeconds: entry.duration ?? 200,
            youTubeId: entry.id,
            artworkUrl: nil,
            sampleRate: 44100,
            bitDepth: 16,
            codec: "AAC",
            isLossless: false,
            lyrics: "[00:00.00]\(entry.title)\n[00:08.00]Artist: \(entry.uploader ?? "YouTube")\n[00:20.00]Playing via YouTube Resolver"
        )
        playback.play(track)
    }

    private func addToQueue(_ entry: YTDlpPlaylistEntry) {
        let track = TrackSnapshot(
            id: UUID(),
            title: entry.title,
            artist: entry.uploader ?? "YouTube Artist",
            albumTitle: entry.playlistTitle,
            durationSeconds: entry.duration ?? 200,
            youTubeId: entry.id,
            artworkUrl: nil,
            sampleRate: 44100,
            bitDepth: 16,
            codec: "AAC",
            isLossless: false
        )
        playback.queue.playNext(track)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func triggerHapticFeedback() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
}
