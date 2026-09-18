import SwiftUI

/// Real-time YouTube & Library search. Suggestions come from recent queries and
/// local top artists — never hard-coded demo fixtures.
struct SearchView: View {
    @Bindable var playback: PlaybackService
    @Environment(LibraryService.self) private var library
    @Environment(YouTubeSearchService.self) private var youTubeSearch

    @State private var query: String = ""
    @State private var isSearching: Bool = false
    @State private var results: [YTDlpPlaylistEntry] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var recentSearches: [String] = SearchView.loadRecentSearches()
    var isPresented: Binding<Bool>? = nil

    private static let recentSearchesKey = "muses.search.recentQueries"
    private static let recentLimit = 8

    init(playback: PlaybackService, isPresented: Binding<Bool>? = nil) {
        self.playback = playback
        self.isPresented = isPresented
    }

    private var localArtistSuggestions: [String] {
        // Prefer a single top artist, then distinct artists from recent plays.
        var names: [String] = []
        if let top = library.topArtistName() {
            names.append(top)
        }
        for track in library.recentlyPlayedTracks(limit: 20) {
            let artist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !artist.isEmpty, !names.contains(where: { $0.caseInsensitiveCompare(artist) == .orderedSame }) else {
                continue
            }
            names.append(artist)
            if names.count >= 6 { break }
        }
        return names
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    if query.isEmpty {
                        suggestionChipsSection
                    } else if isSearching {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(BrandColors.accent)
                                .padding(.top, 40)
                            Spacer()
                        }
                    } else if results.isEmpty {
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
                        resultsListSection
                    }

                    Color.clear.frame(height: 120)
                }
                .padding(.top, AppleMusicSpacing.pageTop)
            }
            .background(BrowseBackground())
            .navigationTitle(tr("Search", "搜索"))
            .searchable(text: $query, prompt: tr("Artists, Songs, Lyrics, and More", "艺人、歌曲、歌词等"))

            .onChange(of: query) { _, newQuery in
                performSearch(query: newQuery)
            }
        }
    }

    // MARK: - Suggestion Chips

    private var suggestionChipsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !recentSearches.isEmpty {
                chipSection(
                    title: tr("Recent Searches", "最近搜索"),
                    tags: recentSearches
                )
            }

            if !localArtistSuggestions.isEmpty {
                chipSection(
                    title: tr("From Your Library", "来自资料库"),
                    tags: localArtistSuggestions
                )
            }

            if recentSearches.isEmpty && localArtistSuggestions.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: tr("Search your music", "搜索你的音乐"),
                    subtitle: tr(
                        "Recent searches and top artists from your library will show up here.",
                        "最近搜索和资料库中的常用艺人会出现在这里。"
                    )
                )
                .padding(.top, 24)
            }
        }
    }

    private func chipSection(title: String, tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(BrandColors.textPrimary)
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(tags, id: \.self) { tag in
                        Button {
                            triggerHapticFeedback()
                            query = tag
                        } label: {
                            Text(tag)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(BrandColors.textPrimary)
                                .padding(.horizontal, 14)
                                .frame(minHeight: AppleMusicSpacing.hitTarget)
                                .contentShape(Capsule())
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

            do {
                let res = try await youTubeSearch.search(query: trimmed, limit: 15)
                guard !Task.isCancelled else { return }
                self.results = res
                if !res.isEmpty {
                    self.rememberSearch(trimmed)
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.results = []
            }
            self.isSearching = false
        }
    }

    private func rememberSearch(_ term: String) {
        var updated = recentSearches.filter { $0.caseInsensitiveCompare(term) != .orderedSame }
        updated.insert(term, at: 0)
        if updated.count > Self.recentLimit {
            updated = Array(updated.prefix(Self.recentLimit))
        }
        recentSearches = updated
        UserDefaults.standard.set(updated, forKey: Self.recentSearchesKey)
    }

    private static func loadRecentSearches() -> [String] {
        UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []
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
            isLossless: false
        )
        playback.play(track, from: .search)
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
