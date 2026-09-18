import SwiftUI
import SwiftData

/// iOS Music Library View with category navigation, listening history analytics, and song collection.
struct LibraryView: View {
    @Bindable var playback: PlaybackService
    @Query(sort: \Track.addedAt, order: .reverse) private var tracks: [Track]
    @Query(sort: \Playlist.createdAt, order: .reverse) private var playlists: [Playlist]

    @State private var selectedFilter: LibraryCategory = .all

    enum LibraryCategory: String, CaseIterable, Identifiable {
        case all = "All"
        case playlists = "Playlists"
        case songs = "Songs"
        case liked = "Liked"

        var id: String { rawValue }

        var localizedTitle: String {
            switch self {
            case .all: return tr("All", "全部")
            case .playlists: return tr("Playlists", "歌单")
            case .songs: return tr("Songs", "已存歌曲")
            case .liked: return tr("Liked", "特别喜欢")
            }
        }
    }

    init(playback: PlaybackService) {
        self.playback = playback
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionSpacing) {
                    filterPills

                    if selectedFilter == .playlists {
                        playlistsDestination
                    } else {
                        songListSection
                    }

                    Color.clear.frame(height: 120)
                }
                .padding(.top, AppleMusicSpacing.pageTop)
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
                            .foregroundStyle(BrandColors.textPrimary)
                            .padding(.horizontal, 16)
                            .frame(minHeight: AppleMusicSpacing.hitTarget)
                            .contentShape(Capsule())
                            .background {
                                if selected {
                                    Color.clear
                                        .musesGlassCapsule(tint: BrandColors.accent.opacity(0.18), role: .compactControl)
                                        .laserStroke(Capsule(), lineWidth: 1.0, opacity: 0.7)
                                } else {
                                    Capsule().fill(BrandColors.surface.opacity(0.28))
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
                        .laserStroke(Circle(), lineWidth: 1.0, opacity: 0.65)

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
                .musesGlass(cornerRadius: 16, role: .compactControl)
                .laserStroke(RoundedRectangle(cornerRadius: 16, style: .continuous), lineWidth: 1.0, opacity: 0.55)
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
                .musesGlass(cornerRadius: 16, role: .compactControl)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
        }
    }

    // MARK: - Song List Section

    private var songListSection: some View {
        VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionHeaderToContent) {
            Text(songListTitle)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(BrandColors.textPrimary)
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)

            if tracks.isEmpty {
                // Fallback default sample items if library is fresh
                VStack(spacing: 8) {
                    sampleLibraryRow(title: "Triumph on the Ice (Rock Remix)", artist: "Streetwise Rhapsody", duration: "3:34")
                    sampleLibraryRow(title: "酸橙色信笺 (Letter in Orange)", artist: "Monster Siren Records", duration: "3:08")
                    sampleLibraryRow(title: "芽吹の唄 (Spring Awakening)", artist: "Official Muses Project", duration: "4:05")
                }
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
            } else {
                VStack(spacing: 8) {
                    ForEach(filteredTracks) { track in
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

                                Image(systemName: "ellipsis")
                                    .font(.system(size: 16))
                                    .foregroundStyle(BrandColors.textTertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
            }
        }
    }

    private func sampleLibraryRow(title: String, artist: String, duration: String) -> some View {
        Button {
            triggerHapticFeedback()
            let track = TrackSnapshot(
                id: UUID(),
                title: title,
                artist: artist,
                albumTitle: title,
                durationSeconds: 210,
                youTubeId: "sample-\(abs(title.hashValue))",
                artworkUrl: nil,
                sampleRate: 44100,
                bitDepth: 16,
                codec: "AAC",
                isLossless: false,
                lyrics: "[00:00.00]\(title)\n[00:06.00]Artist: \(artist)\n[00:15.00]Playing from Muses Library"
            )
            playback.play(track)
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(BrandColors.surface)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 18))
                            .foregroundStyle(BrandColors.accent)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BrandColors.textPrimary)
                        .lineLimit(1)

                    Text(artist)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(BrandColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(duration)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(BrandColors.textTertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var songListTitle: String {
        switch selectedFilter {
        case .liked: return tr("Liked", "特别喜欢")
        case .songs: return tr("Songs", "已存歌曲")
        default: return tr("Recently Added", "最近添加")
        }
    }

    private var filteredTracks: [Track] {
        switch selectedFilter {
        case .all, .songs, .playlists: return tracks
        case .liked: return tracks.filter { $0.liked }
        }
    }

    private func triggerHapticFeedback() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
}
