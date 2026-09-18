import SwiftUI

/// Full-screen Now Playing: queue hero cards, spinning cover, simple transport.
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
                    .padding(.bottom, 8)

                if let message = playback.state.error?.errorDescription {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                }

                NowPlayingTransportBar(playback: playback) {
                    showVideoSheet = true
                }
                .padding(.bottom, 16)
            }
        }
        .onAppear { Task { await loadLyrics() } }
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
        HStack {
            Button {
                isPresented = false
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(tr("Close", "关闭", zhHant: "關閉"))
            Spacer()
        }
        .padding(.horizontal, 12)
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
                ProgressView().tint(.white)
            } else {
                LyricsKaraokeView(
                    lyrics: displayedLyrics,
                    currentPosition: playback.state.position,
                    onSeek: { playback.seek(to: $0) }
                )
            }
        }
        .onTapGesture { showLyrics = false }
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
}
