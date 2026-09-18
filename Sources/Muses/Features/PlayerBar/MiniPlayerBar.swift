import SwiftUI

/// Floating Liquid Glass MiniPlayer capsule docked just above the tab bar.
struct MiniPlayerBar: View {
    @Bindable var playback: PlaybackService
    @Binding var isNowPlayingExpanded: Bool

    @State private var dragOffset: CGFloat = 0

    init(playback: PlaybackService, isNowPlayingExpanded: Binding<Bool>) {
        self.playback = playback
        self._isNowPlayingExpanded = isNowPlayingExpanded
    }

    public var body: some View {
        if let track = playback.state.track {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Album Artwork
                    artworkView(for: track)
                        .frame(width: 42, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)

                    // Track Title & Artist
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 15, weight: .semibold, design: .default))
                            .foregroundStyle(BrandColors.textPrimary)
                            .lineLimit(1)

                        Text(track.artist)
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundStyle(BrandColors.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    // Play/Pause Button
                    Button {
                        triggerHapticFeedback()
                        playback.toggle()
                    } label: {
                        Image(systemName: playback.state.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(BrandColors.textPrimary)
                            .frame(width: 38, height: 38)
                            .frame(minWidth: AppleMusicSpacing.hitTarget, minHeight: AppleMusicSpacing.hitTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(MusesPressStyle(scale: MusesMotion.pressScale))

                    // Next Button
                    Button {
                        triggerHapticFeedback()
                        _ = playback.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(BrandColors.textSecondary)
                            .frame(width: 36, height: 36)
                            .frame(minWidth: AppleMusicSpacing.hitTarget, minHeight: AppleMusicSpacing.hitTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(MusesPressStyle(scale: MusesMotion.pressScale))
                }
                .padding(.horizontal, 14)
                .frame(height: AppleMusicTokens.miniPlayerHeight)

                // Hairline Track Progress Bar
                GeometryReader { geo in
                    let progress = playback.state.duration > 0
                        ? min(1.0, max(0.0, playback.state.position / playback.state.duration))
                        : 0.0

                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.12))

                        Rectangle()
                            .fill(BrandColors.accent)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 2.5)
            }
            .musesGlass(cornerRadius: AppleMusicTokens.miniPlayerCornerRadius, role: .floatingPlayer)
            .laserStroke(cornerRadius: AppleMusicTokens.miniPlayerCornerRadius, lineWidth: 0.9, opacity: 0.62)
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height < 0 {
                            dragOffset = value.translation.height * 0.5
                        }
                    }
                    .onEnded { value in
                        if value.translation.height < -30 {
                            triggerHapticFeedback()
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                isNowPlayingExpanded = true
                            }
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
            )
            .onTapGesture {
                triggerHapticFeedback()
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    isNowPlayingExpanded = true
                }
            }
        }
    }

    @ViewBuilder
    private func artworkView(for track: TrackSnapshot) -> some View {
        if let urlStr = track.artworkUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    placeholderArtwork
                }
            }
        } else {
            placeholderArtwork
        }
    }

    private var placeholderArtwork: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gray.opacity(0.45), Color.gray.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: 18))
                .foregroundStyle(.white)
        }
    }

    private func triggerHapticFeedback() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
}
