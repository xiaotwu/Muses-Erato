import SwiftUI

/// Full-screen Now Playing: hero deck / lyrics glass stage, waveform, centered transport.
struct NowPlayingView: View {
    @Bindable var playback: PlaybackService
    @Binding var isPresented: Bool
    @Environment(LyricsService.self) private var lyricsService
    @Environment(LibraryService.self) private var library

    @State private var showLyrics = false
    @State private var showVideoSheet = false
    @State private var showQueue = false
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
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "muses.debug.mockLyrics") {
            return """
            [00:00.00] 威風堂々 (Ifuudoudou)
            [00:01.00] さあ 始めよう 魅惑のステージへ
            [00:04.50] 瞳を閉じて 奏でるメロディ
            [00:08.20] 誰も追いつけない 圧倒的な光
            [00:12.00] 心の鼓動が高鳴っていく
            [00:16.80] 威風堂々と 歩き出そう
            """
        }
        #endif
        return lyricsResult?.syncedLyrics ?? lyricsResult?.plainLyrics
    }

    var body: some View {
        ZStack {
            AmbientMeshBackground(track: currentTrack)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .frame(maxWidth: 640)

                if showLyrics {
                    lyricsStage
                        .frame(maxWidth: 640)
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
                        lyrics: displayedLyrics,
                        playbackPosition: playback.state.position,
                        onSelectIndex: { playback.playQueueIndex($0) },
                        onOpenLyrics: { showLyrics = true },
                        onToggleLike: {
                            if let track = currentTrack {
                                library.toggleLike(id: track.id)
                            }
                        },
                        onSeek: { playback.seek(to: $0) }
                    )
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 8)
                }

                identity
                    .frame(maxWidth: 540)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)

                if let message = playback.state.error?.errorDescription {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                        .frame(maxWidth: 540)
                }

                timelineScrubber
                    .frame(maxWidth: 520)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 12)

                NowPlayingTransportBar(playback: playback) {
                    showVideoSheet = true
                }
                .frame(maxWidth: 520)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            Task { await loadLyrics() }
        }
        .task {
            #if DEBUG
            // After first layout so track onChange does not clear the one-shot flag.
            try? await Task.sleep(nanoseconds: 350_000_000)
            applyDebugLyricsFlag()
            #endif
        }
        .onChange(of: currentTrack?.id) { oldId, newId in
            guard oldId != nil, oldId != newId else {
                Task { await loadLyrics() }
                return
            }
            showLyrics = false
            Task { await loadLyrics() }
        }
        .sheet(isPresented: $showVideoSheet) {
            if let vid = currentTrack?.youTubeId, !vid.isEmpty {
                YouTubeVideoOverlay(videoId: vid, isPresented: $showVideoSheet)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showQueue) {
            QueueSheetView(queue: playback.queue, playback: playback)
                .environment(playback)
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
                    .musesGlass(in: Circle(), role: .compactControl)
                    .overlay {
                        Circle().stroke(BrandColors.glassRimGradient, lineWidth: 0.65)
                    }
            }
            .accessibilityLabel(
                showLyrics
                    ? tr("Show Cover", "显示封面", zhHant: "顯示封面")
                    : tr("Close", "关闭", zhHant: "關閉")
            )

            Spacer(minLength: 8)

            VStack(spacing: 2) {
                if showLyrics {
                    Text(tr("Lyrics", "歌词", zhHant: "歌詞"))
                        .font(EratoTypography.poeticTitle(size: 15, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.85))
                } else {
                    Text(tr("PLAYING FROM QUEUE", "播放队列", zhHant: "播放佇列"))
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(BrandColors.laurelGold.opacity(0.88))
                    if !playback.queue.items.isEmpty {
                        Text("\(playback.queue.currentIndex + 1) of \(playback.queue.items.count)")
                            .font(EratoTypography.mono(size: 11, weight: .regular))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                Button {
                    showLyrics.toggle()
                } label: {
                    Image(systemName: showLyrics ? "music.note.list" : "quote.bubble.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(showLyrics ? BrandColors.laurelGold : .white.opacity(0.9))
                        .frame(width: 40, height: 40)
                        .musesGlass(in: Circle(), role: .compactControl)
                        .overlay {
                            Circle().stroke(
                                showLyrics ? AnyShapeStyle(BrandColors.laurelGold.opacity(0.6)) : AnyShapeStyle(BrandColors.glassRimGradient),
                                lineWidth: 0.65
                            )
                        }
                }
                .accessibilityLabel(
                    showLyrics
                        ? tr("Show Cover", "显示封面", zhHant: "顯示封面")
                        : tr("Show Lyrics", "显示歌词", zhHant: "顯示歌詞")
                )

                Button {
                    showQueue = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 40, height: 40)
                        .musesGlass(in: Circle(), role: .compactControl)
                        .overlay {
                            Circle().stroke(BrandColors.glassRimGradient, lineWidth: 0.65)
                        }
                }
                .accessibilityLabel(tr("Playing Next", "播放队列", zhHant: "播放佇列"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 70 && abs(value.translation.height) > abs(value.translation.width) * 1.3 {
                        isPresented = false
                    }
                }
        )
    }

    private var identity: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(currentTrack?.title ?? tr("Not Playing", "未在播放"))
                    .font(EratoTypography.poeticTitle(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .musesTitleGlow()
                    .lineLimit(1)
                Text(currentTrack?.artist ?? "Muses")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(BrandColors.laurelGold.opacity(0.88))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let track = currentTrack {
                let isLiked = library.isLiked(id: track.id)
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    library.toggleLike(id: track.id)
                } label: {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(isLiked ? BrandColors.laurelGold : .white.opacity(0.78))
                        .frame(width: 42, height: 42)
                        .musesGlass(in: Circle(), role: .compactControl)
                        .overlay {
                            Circle().stroke(
                                isLiked ? AnyShapeStyle(BrandColors.laurelGold.opacity(0.65)) : AnyShapeStyle(BrandColors.glassRimGradient),
                                lineWidth: 0.65
                            )
                        }
                }
                .buttonStyle(MusesPressStyle(scale: MusesMotion.pressScale))
                .accessibilityLabel(isLiked ? tr("Favorited", "已收藏", zhHant: "已收藏") : tr("Favorite", "收藏", zhHant: "收藏"))

                Menu {
                    TrackContextMenuItems(snapshot: track, onPlay: {})
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(width: 42, height: 42)
                        .musesGlass(in: Circle(), role: .compactControl)
                        .overlay {
                            Circle().stroke(BrandColors.glassRimGradient, lineWidth: 0.65)
                        }
                }
            }
        }
        .frame(maxWidth: 540)
    }

    private var timelineScrubber: some View {
        VStack(spacing: 6) {
            WaveformView()
                .frame(height: 38)
                .environment(playback)

            HStack {
                Text(formatTime(playback.state.position))
                    .font(EratoTypography.mono(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))

                Spacer()

                let dur = playback.state.duration
                let pos = playback.state.position
                let remaining = max(0, dur - pos)
                Text("-" + formatTime(remaining))
                    .font(EratoTypography.mono(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 4)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private var lyricsStage: some View {
        Group {
            if lyricsLoading && displayedLyrics == nil {
                ProgressView()
                    .tint(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
