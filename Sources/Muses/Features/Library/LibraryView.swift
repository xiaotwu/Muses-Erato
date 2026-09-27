import SwiftUI
import SwiftData

/// iOS Music Library View with category navigation, listening history analytics, and song collection.
struct LibraryView: View {
    @Bindable var playback: PlaybackService
    @Query(sort: \Track.addedAt, order: .reverse) private var tracks: [Track]
    @Query(sort: \Playlist.createdAt, order: .reverse) private var playlists: [Playlist]

    @State private var selectedFilter: LibraryCategory = .songs

    enum LibraryCategory: String, CaseIterable, Identifiable {
        case playlists = "Playlists"
        case songs = "Songs"
        case liked = "Liked"

        var id: String { rawValue }

        var localizedTitle: String {
            switch self {
            case .playlists: return tr("Playlists", "歌单")
            case .songs: return tr("Songs", "已存歌曲")
            case .liked: return tr("Liked", "特别喜欢")
            }
        }
    }

    init(playback: PlaybackService) {
        self.playback = playback
    }

    @State private var scrubbedLetter: String?
    @State private var isScrubbing: Bool = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ZStack(alignment: .trailing) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionSpacing) {
                            filterPills

                            if selectedFilter == .playlists {
                                playlistsDestination
                            } else {
                                songListSection
                            }

                            Color.clear.frame(height: 160)
                        }
                        .padding(.top, AppleMusicSpacing.pageTop)
                    }

                    if selectedFilter != .playlists && !sections.isEmpty {
                        AlphabetIndexScrubber(
                            sections: sections.map(\.letter),
                            activeLetter: scrubbedLetter,
                            isScrubbing: isScrubbing,
                            onLetterChanged: { letter in
                                scrubbedLetter = letter
                                isScrubbing = true
                                triggerHapticFeedback()
                                withAnimation(.easeOut(duration: 0.15)) {
                                    proxy.scrollTo("section-\(letter)", anchor: .top)
                                }
                            },
                            onScrubEnded: {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    isScrubbing = false
                                }
                            }
                        )
                        .padding(.trailing, 4)
                        .padding(.top, 60)
                        .padding(.bottom, 120)
                    }

                    if isScrubbing, let letter = scrubbedLetter {
                        LetterPreviewBubble(letter: letter)
                            .padding(.trailing, 44)
                    }
                }
            }
            .background(BrowseBackground())
            .navigationTitle(tr("Library", "资料库"))
        }
    }

    // MARK: - Filter Pills

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibraryCategory.allCases) { cat in
                    let selected = selectedFilter == cat
                    Button {
                        triggerHapticFeedback()
                        withAnimation(.snappy(duration: 0.24)) {
                            selectedFilter = cat
                        }
                    } label: {
                        Text(cat.localizedTitle)
                            .font(.system(size: 14, weight: selected ? .semibold : .medium))
                            .foregroundStyle(selected ? BrandColors.textPrimary : BrandColors.textSecondary)
                            .padding(.horizontal, 16)
                            .frame(minHeight: AppleMusicSpacing.hitTarget)
                            .contentShape(Capsule())
                            .background {
                                if selected {
                                    Capsule()
                                        .fill(BrandColors.laurelGold.opacity(0.18))
                                        .overlay(
                                            Capsule().stroke(BrandColors.laurelGold.opacity(0.65), lineWidth: 0.8)
                                        )
                                } else {
                                    Capsule()
                                        .fill(BrandColors.surface.opacity(0.65))
                                        .overlay(
                                            Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.6)
                                        )
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

    // MARK: - Playlists

    private var playlistsDestination: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink {
                PlaylistsView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(BrandColors.textPrimary)
                        .frame(width: 40, height: 40)
                        .musesGlass(in: Circle(), role: .compactControl)
                        .overlay(Circle().stroke(BrandColors.glassRimGradient, lineWidth: 0.65))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("All Playlists", "全部歌单"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(BrandColors.textPrimary)
                        Text(tr("\(playlists.count) collections", "\(playlists.count) 个歌单"))
                            .font(.system(size: 13))
                            .foregroundStyle(BrandColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BrandColors.textTertiary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(BrandColors.surface.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppleMusicSpacing.pageHorizontal)

            NavigationLink {
                YouTubeImportsView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.rectangle.on.rectangle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(BrandColors.textPrimary)
                        .frame(width: 40, height: 40)
                        .musesGlass(in: Circle(), role: .compactControl)
                        .overlay(Circle().stroke(BrandColors.glassRimGradient, lineWidth: 0.65))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("YouTube Imports", "YouTube 导入"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(BrandColors.textPrimary)
                        Text(tr("Sync playlists from YouTube", "从 YouTube 同步歌单"))
                            .font(.system(size: 12))
                            .foregroundStyle(BrandColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BrandColors.textTertiary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(BrandColors.surface.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
        }
    }

    // MARK: - Song List Section

    private var songListSection: some View {
        VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionHeaderToContent) {
            Text(songListTitle)
                .font(EratoTypography.poeticTitle(size: 20, weight: .bold))
                .foregroundStyle(BrandColors.textPrimary)
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)

            if tracks.isEmpty {
                EmptyStateView(
                    icon: "music.note.list",
                    title: tr("No songs yet", "还没有歌曲"),
                    subtitle: tr(
                        "Import a YouTube playlist or use Search to add tracks.",
                        "导入 YouTube 歌单或用搜索添加曲目。"
                    ),
                    showsEratoLogo: true
                )
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
                .padding(.top, 12)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.letter)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(BrandColors.accent)
                                .padding(.top, 4)
                                .id("section-\(section.letter)")

                            VStack(spacing: 8) {
                                ForEach(section.tracks) { track in
                                    trackRow(track)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
            }
        }
    }

    private func trackRow(_ track: Track) -> some View {
        Button {
            triggerHapticFeedback()
            playback.play(TrackSnapshot(from: track))
        } label: {
            HStack(spacing: 12) {
                ArtworkView(
                    source: ArtworkSource.resolve(for: track),
                    cornerRadius: 8,
                    glyphSize: 16,
                    targetSize: 44,
                    presentation: .fill
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BrandColors.textPrimary)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(BrandColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if track.liked {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(BrandColors.accent)
                }

                Menu {
                    Button(tr("Play", "播放"), systemImage: "play.fill") {
                        playback.play(TrackSnapshot(from: track))
                    }
                    Button(
                        track.liked ? tr("Unlike", "取消喜欢") : tr("Like", "喜欢"),
                        systemImage: track.liked ? "heart.slash" : "heart"
                    ) {
                        toggleLike(track)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundStyle(BrandColors.textTertiary)
                        .frame(minWidth: AppleMusicSpacing.hitTarget, minHeight: AppleMusicSpacing.hitTarget)
                        .contentShape(Rectangle())
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var songListTitle: String {
        switch selectedFilter {
        case .playlists: return tr("Playlists", "歌单")
        case .liked: return tr("Liked", "特别喜欢")
        case .songs: return tr("Songs", "已存歌曲")
        }
    }

    private var filteredTracks: [Track] {
        switch selectedFilter {
        case .playlists: return []
        case .songs: return tracks
        case .liked: return tracks.filter { $0.liked }
        }
    }

    private var sections: [TrackAlphabetSection] {
        let grouped = Dictionary(grouping: filteredTracks) { track in
            alphabetIndexLetter(for: track.title)
        }
        let alphabet = (65...90).map { String(UnicodeScalar($0)) } + ["#"]
        return alphabet.compactMap { letter in
            guard let items = grouped[letter], !items.isEmpty else { return nil }
            let sorted = items.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            return TrackAlphabetSection(letter: letter, tracks: sorted)
        }
    }

    private func toggleLike(_ track: Track) {
        track.liked.toggle()
        try? track.modelContext?.save()
    }

    private func triggerHapticFeedback() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
}

// MARK: - Alphabet Index Helpers

struct TrackAlphabetSection: Identifiable {
    let letter: String
    let tracks: [Track]
    var id: String { letter }
}

func alphabetIndexLetter(for title: String) -> String {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let first = trimmed.first else { return "#" }
    let s = String(first).uppercased()
    if let char = s.first, char >= "A" && char <= "Z" {
        return String(char)
    }
    let mutable = NSMutableString(string: s) as CFMutableString
    if CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false) {
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        let latin = (mutable as String).uppercased()
        if let char = latin.first, char >= "A" && char <= "Z" {
            return String(char)
        }
    }
    return "#"
}

struct AlphabetIndexScrubber: View {
    let sections: [String]
    let activeLetter: String?
    let isScrubbing: Bool
    let onLetterChanged: (String) -> Void
    let onScrubEnded: () -> Void

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 1) {
                ForEach(sections, id: \.self) { letter in
                    let isCurrent = isScrubbing && activeLetter == letter
                    Text(letter)
                        .font(.system(size: 10, weight: isCurrent ? .heavy : .semibold))
                        .foregroundStyle(isCurrent ? BrandColors.accent : BrandColors.textSecondary.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .scaleEffect(isCurrent ? 1.35 : 1.0)
                        .animation(.easeOut(duration: 0.1), value: isCurrent)
                }
            }
            .frame(width: 18)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(BrandColors.surface.opacity(0.55))
                    .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let letterHeight = geo.size.height / CGFloat(max(1, sections.count))
                        let targetIndex = Int(value.location.y / letterHeight)
                        let clamped = max(0, min(sections.count - 1, targetIndex))
                        let letter = sections[clamped]
                        onLetterChanged(letter)
                    }
                    .onEnded { _ in
                        onScrubEnded()
                    }
            )
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(width: 22)
        .accessibilityHidden(true)
    }
}

struct LetterPreviewBubble: View {
    let letter: String

    var body: some View {
        Text(letter)
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(BrandColors.accent)
            .frame(width: 52, height: 52)
            .background(
                Circle()
                    .fill(BrandColors.surface.opacity(0.95))
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    .overlay(Circle().stroke(BrandColors.laurelGold.opacity(0.4), lineWidth: 1))
            )
            .transition(.scale.combined(with: .opacity))
    }
}

