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
                    // Category Filter Pills
                    filterPills

                    // Listening Analytics Chart
                    listeningStatsSection

                    // Song List
                    songListSection

                    Color.clear.frame(height: 120)
                }
                .padding(.top, AppleMusicSpacing.pageTop)
            }
            .background(BrandColors.background)
            .navigationTitle(tr("Library", "资料库"))
        }
    }

    // MARK: - Filter Pills

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(LibraryCategory.allCases) { cat in
                    Button {
                        triggerHapticFeedback()
                        selectedFilter = cat
                    } label: {
                        Text(cat.localizedTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selectedFilter == cat ? Color.white : BrandColors.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedFilter == cat ? BrandColors.accent : BrandColors.surface,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
        }
    }

    // MARK: - Listening Stats Chart

    private var listeningStatsSection: some View {
        VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionHeaderToContent) {
            Text(tr("Listening Trends", "收听趋势"))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(BrandColors.textPrimary)
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .bottom, spacing: 14) {
                    // Mock weekly listening hours
                    barView(day: tr("Mon", "周一"), height: 42, isToday: false)
                    barView(day: tr("Tue", "周二"), height: 68, isToday: false)
                    barView(day: tr("Wed", "周三"), height: 95, isToday: false)
                    barView(day: tr("Thu", "周四"), height: 55, isToday: false)
                    barView(day: tr("Fri", "周五"), height: 110, isToday: false)
                    barView(day: tr("Sat", "周六"), height: 84, isToday: false)
                    barView(day: tr("Sun", "周日"), height: 120, isToday: true)
                }
                .frame(height: 140)
                .padding(.horizontal, 16)
                .padding(.top, 14)

                Divider().background(Color.white.opacity(0.1))

                HStack {
                    Label(tr("42 Songs Played this week", "本周收听 42 首歌曲"), systemImage: "flame.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(BrandColors.accent)
                    Spacer()
                    Text(tr("Average 2.4 hrs/day", "平均 2.4 小时/天"))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(BrandColors.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .background(BrandColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
        }
    }

    private func barView(day: String, height: CGFloat, isToday: Bool) -> some View {
        VStack(spacing: 6) {
            Spacer()
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isToday ? BrandColors.accent : BrandColors.accent.opacity(0.45))
                .frame(height: height)

            Text(day)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(isToday ? BrandColors.textPrimary : BrandColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Song List Section

    private var songListSection: some View {
        VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionHeaderToContent) {
            Text(tr("Recently Added", "最近添加"))
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
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(BrandColors.surface)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.system(size: 18))
                                            .foregroundStyle(BrandColors.accent)
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

    private var filteredTracks: [Track] {
        switch selectedFilter {
        case .all, .songs: return tracks
        case .liked: return tracks.filter { $0.liked }
        case .playlists: return tracks
        }
    }

    private func triggerHapticFeedback() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
}
