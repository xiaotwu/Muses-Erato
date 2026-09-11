import SwiftUI

/// A curated card item displayed on the iOS Home discovery tab.
struct HomeCardItem: Identifiable, Sendable {
    enum CardKind {
        case album, song, playlist
    }
    let id: String
    let title: String
    let subtitle: String
    var artworkUrl: String? = nil
    let kind: CardKind
}

/// iOS Home Discovery View with Top Picks carousel, Made For You shelves, and recent listens.
struct HomeView: View {
    @Bindable var playback: PlaybackService
    @Binding var showSettings: Bool

    // Curated discovery items
    private let heroItems: [HomeCardItem] = [
        HomeCardItem(
            id: "hero-1",
            title: "Triumph on the Ice",
            subtitle: "Streetwise Rhapsody • Rock Remix",
            artworkUrl: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop&q=80",
            kind: .album
        ),
        HomeCardItem(
            id: "hero-2",
            title: "酸橙色信笺 (Letter in Orange)",
            subtitle: "Monster Siren Records • Featured Single",
            artworkUrl: "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800&auto=format&fit=crop&q=80",
            kind: .song
        ),
        HomeCardItem(
            id: "hero-3",
            title: "芽吹の唄 (Spring Awakening)",
            subtitle: "Official Muses Project • Acoustic",
            artworkUrl: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&auto=format&fit=crop&q=80",
            kind: .playlist
        )
    ]

    private let madeForYouItems: [HomeCardItem] = [
        HomeCardItem(id: "mfy-1", title: "Chill Beats & Lo-Fi", subtitle: "Relax & Study", kind: .playlist),
        HomeCardItem(id: "mfy-2", title: "Neo Classical Muse", subtitle: "Acoustic Piano & Strings", kind: .playlist),
        HomeCardItem(id: "mfy-3", title: "Synthwave Night Drive", subtitle: "Electronic Energy", kind: .playlist),
        HomeCardItem(id: "mfy-4", title: "Anime OST Essentials", subtitle: "Soundtrack Masterpieces", kind: .playlist)
    ]

    init(playback: PlaybackService, showSettings: Binding<Bool>) {
        self.playback = playback
        self._showSettings = showSettings
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionSpacing) {
                    // Top Hero Carousel
                    heroCarousel

                    // Made For You Shelf
                    madeForYouSection

                    // Recently Played Shelf
                    recentListensSection

                    // Bottom padding for floating player and tab bar
                    Color.clear.frame(height: 120)
                }
                .padding(.top, AppleMusicSpacing.pageTop)
            }
            .background(BrandColors.background)
            .navigationTitle(tr("Home", "首页"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        triggerHapticFeedback()
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(BrandColors.textPrimary)
                    }
                }
            }
        }
    }

    // MARK: - Hero Carousel

    private var heroCarousel: some View {
        VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionHeaderToContent) {
            Text(tr("Top Picks", "精选推荐"))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(BrandColors.textPrimary)
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppleMusicSpacing.shelfItemSpacing) {
                    ForEach(heroItems) { item in
                        heroCard(for: item)
                    }
                }
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
            }
        }
    }

    private func heroCard(for item: HomeCardItem) -> some View {
        Button {
            triggerHapticFeedback()
            playDiscoveryItem(item)
        } label: {
            ZStack(alignment: .bottomLeading) {
                // Artwork Image / Gradient
                RoundedRectangle(cornerRadius: AppleMusicTokens.cardCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.98, green: 0.35, blue: 0.42), Color(red: 0.35, green: 0.15, blue: 0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Dark gradient overlay for text readability
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.85)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: AppleMusicTokens.cardCornerRadius, style: .continuous))

                // Text details and Play button
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(item.subtitle ?? "")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(BrandColors.accent)
                        .background(Circle().fill(Color.white).padding(4))
                        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .padding(16)
            }
            .frame(width: 300, height: 180)
            .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Made For You Section

    private var madeForYouSection: some View {
        VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionHeaderToContent) {
            Text(tr("Made For You", "为你精选"))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(BrandColors.textPrimary)
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppleMusicSpacing.shelfItemSpacing) {
                    ForEach(madeForYouItems) { item in
                        Button {
                            triggerHapticFeedback()
                            playDiscoveryItem(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                RoundedRectangle(cornerRadius: AppleMusicTokens.cardCornerRadius, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 140, height: 175)
                                    .overlay(
                                        Image(systemName: "music.quarternote.3")
                                            .font(.system(size: 36))
                                            .foregroundStyle(.white.opacity(0.75))
                                    )
                                    .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)

                                Text(item.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(BrandColors.textPrimary)
                                    .lineLimit(1)
                                    .frame(width: 140, alignment: .leading)

                                Text(item.subtitle ?? "")
                                    .font(.system(size: 12, weight: .regular))
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

    // MARK: - Recently Played Section

    private var recentListensSection: some View {
        VStack(alignment: .leading, spacing: AppleMusicSpacing.sectionHeaderToContent) {
            Text(tr("Recently Played", "最近播放"))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(BrandColors.textPrimary)
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)

            VStack(spacing: 8) {
                ForEach(heroItems) { item in
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(BrandColors.accent.opacity(0.8))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(BrandColors.textPrimary)
                                .lineLimit(1)

                            Text(item.subtitle ?? "")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(BrandColors.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            triggerHapticFeedback()
                            playDiscoveryItem(item)
                        } label: {
                            Image(systemName: "play.circle")
                                .font(.system(size: 24))
                                .foregroundStyle(BrandColors.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private func playDiscoveryItem(_ item: HomeCardItem) {
        let track = TrackSnapshot(
            id: UUID(),
            title: item.title,
            artist: item.subtitle,
            albumTitle: item.title,
            durationSeconds: 214,
            youTubeId: item.id,
            artworkUrl: item.artworkUrl,
            sampleRate: 44100,
            bitDepth: 16,
            codec: "AAC",
            isLossless: false,
            lyrics: "[00:00.00]Muses - \(item.title)\n[00:05.00]Music awakens the soul\n[00:12.50]Erato weaves the lyrics of romance\n[00:22.00]Flowing under Apple Liquid Glass design\n[00:34.00]Clear sound, pure melody\n[00:48.00]Harmonies resonate through the night"
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
