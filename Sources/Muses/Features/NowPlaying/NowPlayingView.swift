import SwiftUI

/// Full-screen Now Playing: hero deck / lyrics glass stage, waveform, centered transport.
struct NowPlayingView: View {
    @Bindable var playback: PlaybackService
    @Binding var isPresented: Bool
    @Environment(LyricsService.self) private var lyricsService

    @State private var showLyrics = false
    @State private var showVideoSheet = false
    @State private var lyricsResult: LyricsResult?
    @State private var lyricsLoading = false

    init(playback: PlaybackService, isPresented: Binding<Bool>) {
        self.playback = playback
        self._isPresented = isPresented
    }

    private var currentTrack: TrackSnapshot? { playback.state.track }

    private var deckItems: [QueueItem] {
        if !playback.queue.items.isEmpty { return playback.queue.items }
        if let track = currentTrack {
            return [QueueItem(track: track, fromContext: .songs)]
        }
        return []
    }

    private var displayedLyrics: String? {
        lyricsResult?.syncedLyrics ?? lyricsResult?.plainLyrics
    }

    var body: some View {
        ZStack {
            AmbientMeshBackground(track: currentTrack)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                if showLyrics {
                    lyricsStage
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else if deckItems.isEmpty {
                    Spacer()
                    Text(tr("Not Playing", "未在播放"))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .musesTitleGlow()
                    Spacer()
                } else {
                    NowPlayingHeroDeck(
                        items: deckItems,
                        currentIndex: max(0, playback.queue.currentIndex),
                        isPlaying: playback.state.isPlaying,
                        onSelectIndex: { playback.playQueueIndex($0) },
                        onOpenLyrics: { showLyrics = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 8)
                }

                identity
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)

                if let message = playback.state.error?.errorDescription {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                }

                WaveformView()
                    .frame(height: 36)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 10)
                    .environment(playback)

                NowPlayingTransportBar(playback: playback) {
                    showVideoSheet = true
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            Task { await loadLyrics() }
            #if DEBUG
            applyDebugLyricsFlag()
            #endif
        }
        .onChange(of: currentTrack?.id) { _, _ in
            showLyrics = false
            Task { await loadLyrics() }
        }
        .sheet(isPresented: $showVideoSheet) {
            if let vid = currentTrack?.youTubeId, !vid.isEmpty {
                YouTubeVideoOverlay(videoId: vid, isPresented: $showVideoSheet)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                if showLyrics {
                    showLyrics = false
                } else {
                    isPresented = false
                }
            } label: {
                Image(systemName: showLyrics ? "rectangle.stack.fill" : "chevron.down")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 40, height: 40)
                    .musesGlass(in: Circle(), tint: Color.white.opacity(0.12), role: .compactControl)
                    .laserStrokeCircle(lineWidth: 0.85, opacity: 0.55)
            }
            .accessibilityLabel(
                showLyrics
                    ? tr("Show Cover", "显示封面", zhHant: "顯示封面")
                    : tr("Close", "关闭", zhHant: "關閉")
            )

            Spacer(minLength: 8)

            if showLyrics {
                Text(tr("Lyrics", "歌词", zhHant: "歌詞"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(BrandColors.hairline.opacity(0.55), lineWidth: 0.6)
                            .allowsHitTesting(false)
                    }
                    .laserStrokeCapsule(lineWidth: 0.9, opacity: 0.65)
            }

            Spacer(minLength: 8)

            Button {
                showLyrics.toggle()
            } label: {
                Image(systemName: showLyrics ? "music.note.list" : "quote.bubble.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 40, height: 40)
                    .musesGlass(in: Circle(), tint: Color.white.opacity(0.12), role: .compactControl)
                    .laserStrokeCircle(lineWidth: 0.85, opacity: 0.55)
            }
            .accessibilityLabel(
                showLyrics
                    ? tr("Show Cover", "显示封面", zhHant: "顯示封面")
                    : tr("Show Lyrics", "显示歌词", zhHant: "顯示歌詞")
            )
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
    }

    private var identity: some View {
        VStack(spacing: 4) {
            Text(currentTrack?.title ?? tr("Not Playing", "未在播放"))
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .musesTitleGlow()
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(currentTrack?.artist ?? "Muses")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var lyricsStage: some View {
        Group {
            if lyricsLoading && displayedLyrics == nil {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .laserStroke(cornerRadius: 28, lineWidth: 1.0, opacity: 0.70)
                    .padding(.horizontal, 16)
            } else {
                LyricsKaraokeView(
                    lyrics: displayedLyrics,
                    currentPosition: playback.state.position,
                    onSeek: { playback.seek(to: $0) }
                )
            }
        }
    }

    private func loadLyrics() async {
        guard let track = currentTrack else {
            lyricsResult = nil
            return
        }
        lyricsLoading = true
        if let cached = lyricsService.fetchCached(track: track) {
            lyricsResult = cached
        } else {
            lyricsResult = await lyricsService.fetch(track: track)
        }
        lyricsLoading = false
    }

    #if DEBUG
    private func applyDebugLyricsFlag() {
        let key = "muses.debug.showLyrics"
        if UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(false, forKey: key)
            showLyrics = true
        }
    }
    #endif
}
