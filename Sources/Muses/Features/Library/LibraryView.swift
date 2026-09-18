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

                    // Core Native Features Grid
                    featureNavigationGrid

                    // Listening Analytics Chart
                    listeningStatsSection

                    // Song List
                    songListSection

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
                                        .musesGlassCapsule(tint: BrandColors.accent.opacity(0.25), role: .compactControl)
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

    // MARK: - Core Native Features Grid

    private var featureNavigationGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 12)], spacing: 12) {
            NavigationLink {
                PlaylistsView()
            } label: {
                featureCard(
                    title: tr("Playlists", "歌单"),
                    subtitle: tr("\(playlists.count) collections", "\(playlists.count) 个歌单"),
                    icon: "music.note.list",
                    tint: BrandColors.magenta
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                SongsListView()
            } label: {
                featureCard(
                    title: tr("Songs", "已存歌曲"),
                    subtitle: tr("\(tracks.count) tracks", "\(tracks.count) 首歌曲"),
                    icon: "music.quarternote.3",
                    tint: Color(red: 255/255, green: 149/255, blue: 0)
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                HistoryView()
            } label: {
                featureCard(
                    title: tr("History", "收听历史"),
                    subtitle: tr("Heatmap & Stats", "热力图与数据"),
                    icon: "flame.fill",
                    tint: Color(red: 255/255, green: 45/255, blue: 85)
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                InboxView()
            } label: {
                featureCard(
                    title: tr("Inbox", "音乐收件箱"),
                    subtitle: tr("Triage & Notes", "发现与整理"),
                    icon: "tray.and.arrow.down.fill",
                    tint: Color(red: 88/255, green: 86/255, blue: 214)
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                FocusView()
            } label: {
                featureCard(
                    title: tr("Focus Mode", "专注模式"),
                    subtitle: tr("Pomodoro Timer", "番茄钟与流态"),
                    icon: "brain.head.profile",
                    tint: Color(red: 52/255, green: 199/255, blue: 89)
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                YouTubeImportsView()
            } label: {
                featureCard(
                    title: tr("YouTube", "YouTube 导入"),
                    subtitle: tr("Sync & Cloud", "歌单同步"),
                    icon: "play.rectangle.on.rectangle.fill",
                    tint: Color(red: 255/255, green: 59/255, blue: 48)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
    }

    private func featureCard(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BrandColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(BrandColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(BrandColors.textTertiary.opacity(0.6))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .musesGlass(cornerRadius: 14, role: .compactControl)
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
            .musesGlass(cornerRadius: 16, role: .compactControl)
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
