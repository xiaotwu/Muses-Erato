import SwiftUI

/// Browse / New Releases discovery view with landscape editorial cards and best new songs matrix.
struct BrowseView: View {
    @Bindable var playback: PlaybackService

    private let editorialReleases = [
        ("Liquid Resonance", "Erato Ensemble", Color(red: 0.98, green: 0.35, blue: 0.42)),
        ("Spatial Odyssey", "Cyber Soundscapes", Color(red: 0.25, green: 0.45, blue: 0.95)),
        ("Anime Piano Chronicles", "Emotional Soundtracks", Color(red: 0.55, green: 0.2, blue: 0.8))
    ]

    private let genres = [
        "J-Pop", "ACG / Anime", "Lo-Fi & Study", "Electronic / EDM",
        "Classical & Piano", "Rock & Metal", "R&B / Soul", "Hip-Hop"
    ]

    init(playback: PlaybackService) {
        self.playback = playback
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionSpacing) {
                    // Featured Editorial Carousel
                    editorialSection

                    // Best New Songs
                    bestNewSongsSection

                    // Browse by Genre
                    genreGridSection

                    Color.clear.frame(height: 120)
                }
                .padding(.top, AppleMusicSpacing.pageTop)
            }
            .background(BrowseBackground())
            .navigationTitle(tr("Browse", "新发现"))
        }
    }

    // MARK: - Editorial Section

    private var editorialSection: some View {
        VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionHeaderToContent) {
            Text(tr("New Releases", "新发行"))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(BrandColors.textPrimary)
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppleMusicSpacing.shelfItemSpacing) {
                    ForEach(editorialReleases, id: \.0) { item in
                        Button {
                            triggerHapticFeedback()
                            playRelease(title: item.0, artist: item.1)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(tr("FEATURED SPOTLIGHT", "焦点推荐"))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(BrandColors.accent)
                                    .tracking(0.5)

                                Text(item.0)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(BrandColors.textPrimary)
                                    .lineLimit(1)

                                Text(item.1)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(BrandColors.textSecondary)
                                    .lineLimit(1)

                                RoundedRectangle(cornerRadius: AppleMusicTokens.cardCornerRadius, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [item.2, item.2.opacity(0.6)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 290, height: 165)
                                    .overlay(
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.white.opacity(0.8))
                                    )
                                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
            }
        }
    }

    // MARK: - Best New Songs Section

    private var bestNewSongsSection: some View {
        VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionHeaderToContent) {
            Text(tr("Best New Songs", "精选新歌"))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(BrandColors.textPrimary)
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)

            VStack(spacing: 6) {
                songRow(title: "Triumph on the Ice (Rock Remix)", artist: "Streetwise Rhapsody", duration: "3:34")
                songRow(title: "酸橙色信笺 (Letter in Orange)", artist: "Monster Siren Records", duration: "3:08")
                songRow(title: "芽吹の唄 (Spring Awakening)", artist: "Official Muses Project", duration: "4:05")
                songRow(title: "Moonlight Sonata (Lo-Fi Rework)", artist: "Erato Ensemble", duration: "2:52")
            }
            .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
        }
    }

    private func songRow(title: String, artist: String, duration: String) -> some View {
        Button {
            triggerHapticFeedback()
            playRelease(title: title, artist: artist)
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

                VStack(alignment: .leading, spacing: 2) {
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
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(BrandColors.textTertiary)

                Image(systemName: "play.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(BrandColors.accent)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Genres Section

    private var genreGridSection: some View {
        VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionHeaderToContent) {
            Text(tr("Browse by Category", "按分类浏览"))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(BrandColors.textPrimary)
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(genres, id: \.self) { genre in
                    Button {
                        triggerHapticFeedback()
                    } label: {
                        ZStack(alignment: .bottomLeading) {
                            RoundedRectangle(cornerRadius: AppleMusicTokens.cardCornerRadius, style: .continuous)
                                .fill(BrandColors.surface)
                                .frame(height: 72)

                            Text(genre)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(BrandColors.textPrimary)
                                .padding(12)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
        }
    }

    private func playRelease(title: String, artist: String) {
        let track = TrackSnapshot(
            id: UUID(),
            title: title,
            artist: artist,
            albumTitle: title,
            durationSeconds: 200,
            youTubeId: "sample-\(abs(title.hashValue))",
            artworkUrl: nil,
            sampleRate: 44100,
            bitDepth: 16,
            codec: "AAC",
            isLossless: false,
            lyrics: "[00:00.00]\(title)\n[00:08.00]Performed by \(artist)\n[00:20.00]Streamed via Muses-Erato iOS Engine\n[00:35.00]Liquid Glass and pure music"
        )
        playback.play(track)
    }

    private func triggerHapticFeedback() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
}
