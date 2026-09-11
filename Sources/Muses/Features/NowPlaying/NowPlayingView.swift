import SwiftUI
import MediaPlayer

/// Immersive/// Full screen immersive Now Playing modal with Liquid Glass controls,
/// ambient chromatic gradient mesh, and synchronized lyrics.
struct NowPlayingView: View {
    @Bindable var playback: PlaybackService
    @Binding var isPresented: Bool

    enum VisualizerMode: String, CaseIterable, Identifiable {
        case cover = "Cover"
        case vinyl = "Vinyl"
        case spectrum = "Spectrum"
        case waveform = "Waveform"
        case video = "Video"

        var id: String { rawValue }

        var localizedName: String {
            switch self {
            case .cover: return tr("Cover", "封面")
            case .vinyl: return tr("Vinyl", "黑胶")
            case .spectrum: return tr("Spectrum", "频谱")
            case .waveform: return tr("Waveform", "波形")
            case .video: return tr("Video", "视频")
            }
        }

        var icon: String {
            switch self {
            case .cover: return "square.fill"
            case .vinyl: return "record.circle.fill"
            case .spectrum: return "chart.bar.xaxis"
            case .waveform: return "waveform"
            case .video: return "play.rectangle.fill"
            }
        }
    }

    @State private var visualizerMode: VisualizerMode = .cover
    @State private var showLyrics: Bool = true
    @State private var showQueue: Bool = false
    @State private var showEQ: Bool = false
    @State private var showAudioNerd: Bool = false
    @State private var showNotesSheet: Bool = false
    @State private var showVideoSheet: Bool = false
    @State private var showSleepTimerSheet: Bool = false
    @State private var isScrubbing: Bool = false
    @State private var scrubPosition: Double = 0.0
    @State private var dragOffset: CGSize = .zero

    init(playback: PlaybackService, isPresented: Binding<Bool>) {
        self.playback = playback
        self._isPresented = isPresented
    }

    var body: some View {
        let currentTrack = playback.state.track

        ZStack {
            // Dynamic Ambient Chromatic Mesh
            AmbientMeshBackground(track: currentTrack)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Grabber & Navigation Bar
                topBar

                Spacer(minLength: 10)

                // Middle Stage: Album Artwork / Visualizer vs. Real-time Karaoke Lyrics
                if showLyrics {
                    LyricsKaraokeView(
                        lyrics: currentTrack?.lyrics,
                        currentPosition: isScrubbing ? scrubPosition : playback.state.position,
                        onSeek: { targetTime in
                            playback.seek(to: targetTime)
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    artworkStage(for: currentTrack)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }

                Spacer(minLength: 10)

                // Track Identity & Favorite Button
                trackIdentityRow(for: currentTrack)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 16)

                // Liquid Glass Transport Deck
                transportDeck
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showQueue) {
            QueueSheetView(queue: playback.queue, playback: playback)
        }
        .sheet(isPresented: $showEQ) {
            EQEditorView()
        }
        .sheet(isPresented: $showAudioNerd) {
            AudioInfoPanel(playback: playback)
        }
        .sheet(isPresented: $showNotesSheet) {
            if let track = playback.state.track {
                TrackNotesSheet(track: track)
            }
        }
        .sheet(isPresented: $showVideoSheet) {
            if let vid = playback.state.track?.youTubeId {
                YouTubeVideoOverlay(videoId: vid, isPresented: $showVideoSheet)
            }
        }
        .sheet(isPresented: $showSleepTimerSheet) {
            SleepTimerSheet()
        }
    }

    // MARK: - Top Navigation Bar

    private var topBar: some View {
        HStack {
            Button {
                triggerHapticFeedback()
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    isPresented = false
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Visualizer Mode Switcher Capsule
            Menu {
                Picker(tr("Visualizer", "视觉舞台"), selection: $visualizerMode) {
                    ForEach(VisualizerMode.allCases) { mode in
                        Label(mode.localizedName, systemImage: mode.icon).tag(mode)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: visualizerMode.icon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(visualizerMode.localizedName)
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .opacity(0.7)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .musesGlassCapsule(role: .compactControl)
            }

            Spacer()

            Menu {
                Section(tr("Audio & Effects", "音频与特效")) {
                    Button {
                        showEQ = true
                    } label: {
                        Label(tr("32-Band Equalizer", "32段图形均衡器"), systemImage: "slider.vertical.3")
                    }

                    Button {
                        showAudioNerd = true
                    } label: {
                        Label(tr("Audio Nerd Inspector", "音频参数极客面板"), systemImage: "waveform.badge.magnifyingglass")
                    }
                }

                if let track = playback.state.track {
                    Section(tr("Track", "歌曲工具")) {
                        Button {
                            showNotesSheet = true
                        } label: {
                            Label(tr("Notes & Bookmarks", "笔记与时间轴书签"), systemImage: "note.text")
                        }

                        Button {
                            playback.library?.toggleLike(id: track.id)
                        } label: {
                            Label(track.liked ? tr("Unlike", "取消喜欢") : tr("Like", "喜欢"),
                                  systemImage: track.liked ? "heart.slash" : "heart")
                        }
                    }
                }

                Button {
                    showSleepTimerSheet = true
                } label: {
                    Label(tr("Sleep Timer", "睡眠定时器"), systemImage: "moon.zzz")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
    }

    // MARK: - Artwork Stage

    @ViewBuilder
    private func artworkStage(for track: TrackSnapshot?) -> some View {
        let artworkSource = ArtworkSource.resolve(for: track)

        GeometryReader { geo in
            let side = min(geo.size.width - 48, geo.size.height - 20, AppleMusicTokens.nowPlayingMaxArtworkSize)

            VStack {
                Spacer()

                Group {
                    switch visualizerMode {
                    case .cover:
                        CoverArtModeView(source: artworkSource, size: side)
                            .scaleEffect(playback.state.isPlaying ? 1.02 : 0.98)
                            .rotation3DEffect(
                                .degrees(Double(dragOffset.width) / 18.0),
                                axis: (x: 0, y: 1, z: 0)
                            )
                            .offset(dragOffset)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        dragOffset = CGSize(width: value.translation.width * 0.25, height: value.translation.height * 0.15)
                                    }
                                    .onEnded { _ in
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            dragOffset = .zero
                                        }
                                    }
                            )
                            .onTapGesture {
                                triggerHapticFeedback()
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                                    showLyrics.toggle()
                                }
                            }
                    case .vinyl:
                        VinylModeView(source: artworkSource, size: side)
                    case .spectrum:
                        VStack(spacing: 12) {
                            SpectrumView()
                                .frame(width: side, height: side * 0.75)
                                .musesGlass(cornerRadius: 20, role: .compactControl)
                            Text(tr("64-Band Metal FFT Spectrum", "64频段 Metal GPU 音频频谱"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                    case .waveform:
                        VStack(spacing: 12) {
                            WaveformView()
                                .frame(width: side, height: side * 0.75)
                                .musesGlass(cornerRadius: 20, role: .compactControl)
                            Text(tr("2,000-Bucket Precision Waveform", "2,000采样点精准拖拽波形"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                    case .video:
                        if let vid = track?.youTubeId, !vid.isEmpty {
                            VStack(spacing: 10) {
                                YouTubeVideoWell(videoId: vid) {
                                    showVideoSheet = true
                                }
                                .frame(width: side, height: side * 0.6)
                                Text(tr("Tap to Expand Video", "轻点展开全屏画中画视频"))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.6))
                            }
                        } else {
                            CoverArtModeView(source: artworkSource, size: side)
                        }
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: visualizerMode)

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var fallbackArtwork: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.35, blue: 0.42), Color(red: 0.45, green: 0.2, blue: 0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Track Identity Row

    @ViewBuilder
    private func trackIdentityRow(for track: TrackSnapshot?) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(track?.title ?? tr("Not Playing", "未在播放"))
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(track?.artist ?? "Muses")
                    .font(.system(size: 17, weight: .medium, design: .default))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }

            Spacer()

            if let track {
                Button {
                    triggerHapticFeedback()
                    playback.library?.toggleLike(id: track.id)
                } label: {
                    Image(systemName: track.liked ? "heart.fill" : "heart")
                        .font(.system(size: 22))
                        .foregroundStyle(track.liked ? BrandColors.accent : .white.opacity(0.65))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Liquid Glass Transport Deck

    private var transportDeck: some View {
        VStack(spacing: 16) {
            // High-precision Time Scrubber
            scrubberView

            // Main Transport Buttons
            HStack(spacing: 0) {
                // Shuffle
                Button {
                    triggerHapticFeedback()
                    playback.queue.toggleShuffle()
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(playback.queue.shuffle ? BrandColors.accent : .white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }

                // Previous
                Button {
                    triggerHapticFeedback()
                    playback.previous()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                }

                // Big White Circular Play/Pause Button
                Button {
                    triggerHapticFeedback()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        playback.toggle()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 64, height: 64)
                            .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 5)

                        Image(systemName: playback.state.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color.black)
                            .offset(x: playback.state.isPlaying ? 0 : 2)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                // Next
                Button {
                    triggerHapticFeedback()
                    _ = playback.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                }

                // Repeat
                Button {
                    triggerHapticFeedback()
                    playback.queue.toggleRepeat()
                } label: {
                    Image(systemName: repeatIconName)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(playback.queue.repeatMode != .off ? BrandColors.accent : .white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
            }

            // Bottom Actions: Volume & Mode Buttons
            HStack(spacing: 24) {
                // Lyrics Toggle
                Button {
                    triggerHapticFeedback()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showLyrics.toggle()
                    }
                } label: {
                    Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                        .font(.system(size: 20))
                        .foregroundStyle(showLyrics ? BrandColors.accent : .white.opacity(0.65))
                        .frame(width: 38, height: 38)
                }

                Spacer()

                // AirPlay Route Picker / Output
                Button {
                    triggerHapticFeedback()
                } label: {
                    Image(systemName: "airplayaudio")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(width: 38, height: 38)
                }

                Spacer()

                // 32-Band EQ
                Button {
                    triggerHapticFeedback()
                    showEQ = true
                } label: {
                    Image(systemName: "slider.vertical.3")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(width: 38, height: 38)
                }

                Spacer()

                // Queue Sheet Button
                Button {
                    triggerHapticFeedback()
                    showQueue = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(width: 38, height: 38)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .musesGlass(cornerRadius: 28, role: .modalDeck)
    }

    // MARK: - Scrubber View

    private var scrubberView: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let duration = max(1.0, playback.state.duration)
                let current = isScrubbing ? scrubPosition : playback.state.position
                let progress = min(1.0, max(0.0, current / duration))

                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 5)

                    // Track active progress
                    Capsule()
                        .fill(Color.white)
                        .frame(width: geo.size.width * progress, height: 5)

                    // Thumb knob
                    Circle()
                        .fill(Color.white)
                        .frame(width: isScrubbing ? 16 : 8, height: isScrubbing ? 16 : 8)
                        .shadow(color: Color.black.opacity(0.3), radius: 4)
                        .offset(x: max(0, min(geo.size.width - (isScrubbing ? 16 : 8), geo.size.width * progress - (isScrubbing ? 8 : 4))))
                }
                .frame(height: 18)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            isScrubbing = true
                            let p = max(0.0, min(1.0, val.location.x / geo.size.width))
                            scrubPosition = p * duration
                        }
                        .onEnded { val in
                            let p = max(0.0, min(1.0, val.location.x / geo.size.width))
                            let target = p * duration
                            playback.seek(to: target)
                            isScrubbing = false
                        }
                )
            }
            .frame(height: 18)

            HStack {
                Text(formatTime(isScrubbing ? scrubPosition : playback.state.position))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))

                Spacer()

                let duration = playback.state.duration
                let current = isScrubbing ? scrubPosition : playback.state.position
                let remaining = max(0.0, duration - current)
                Text("-" + formatTime(remaining))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private var repeatIconName: String {
        switch playback.queue.repeatMode {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private func triggerHapticFeedback() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
}
