import SwiftUI

enum NowPlayingDeckMetrics {
    static func radius(width: CGFloat, landscape: Bool) -> Int {
        if width >= 1100 { return 3 }
        if landscape || width >= 700 { return 2 }
        return 1
    }

    static func cardSide(width: CGFloat, height: CGFloat, landscape: Bool) -> CGFloat {
        if landscape {
            return min(width * 0.38, height * 0.78, 280)
        }
        // Roomy hero card presence (takes dominant stage space without clipping bottom controls)
        return min(width - 56, height * 0.88, 350)
    }

    static let swipeThreshold: CGFloat = 64
    static let skipThreshold: CGFloat = 64
    static let velocityThreshold: CGFloat = 280
}

/// 3D flip card opacity modifier ensuring only the forward-facing side renders.
struct FlipCardSideModifier: AnimatableModifier {
    var angle: Double

    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        let normalized = angle.truncatingRemainder(dividingBy: 360)
        let a = normalized < 0 ? normalized + 360 : normalized
        let isFacingFront = a <= 90 || a >= 270
        return content
            .opacity(isFacingFront ? 1.0 : 0.0)
            .accessibilityHidden(!isFacingFront)
    }
}

/// Holographic foil sheen overlay reacting to card dragging and ambient light.
struct HolographicFoilOverlay: View {
    let dragProgress: Double
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { _ in
            let shift = CGFloat(dragProgress) * 0.35

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: Color(red: 1.0, green: 0.86, blue: 0.45).opacity(0.16), location: 0.22 + shift * 0.1),
                    .init(color: Color(red: 0.45, green: 0.82, blue: 1.0).opacity(0.14), location: 0.44 + shift * 0.1),
                    .init(color: Color(red: 0.96, green: 0.65, blue: 0.92).opacity(0.12), location: 0.64 + shift * 0.1),
                    .init(color: Color(red: 1.0, green: 0.86, blue: 0.45).opacity(0.20), location: 0.82 + shift * 0.1),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .allowsHitTesting(false)
        }
    }
}

/// Breathing laurel gold audio reactive backlight halo.
struct AudioReactiveAura: View {
    let isPlaying: Bool
    let side: CGFloat
    @State private var pulse: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 38, style: .continuous)
            .fill(
                RadialGradient(
                    colors: [
                        BrandColors.laurelGold.opacity(isPlaying ? 0.36 : 0.08),
                        BrandColors.laurelGold.opacity(isPlaying ? 0.14 : 0.0),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: side * 0.22,
                    endRadius: side * 0.70
                )
            )
            .frame(width: side * 1.18, height: side * 1.18)
            .scaleEffect(isPlaying && pulse ? 1.06 : 0.97)
            .opacity(isPlaying ? (pulse ? 0.92 : 0.60) : 0.0)
            .blur(radius: 26)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.3).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

/// Gamified Hero Deck with 3D Holographic Card Flip, pure artwork front, and pure lyrics back stage.
struct NowPlayingHeroDeck: View {
    let items: [QueueItem]
    let currentIndex: Int
    let isPlaying: Bool
    var lyrics: String? = nil
    var playbackPosition: Double = 0
    var onSelectIndex: (Int) -> Void
    var onOpenLyrics: () -> Void
    var onToggleLike: (() -> Void)? = nil
    var onSeek: ((Double) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var isFlipped: Bool = false
    @State private var flipAngle: Double = 0.0
    @State private var showHeartBurst: Bool = false
    @State private var heartBurstScale: CGFloat = 0.5
    @State private var heartBurstOpacity: Double = 0.0

    private var landscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        GeometryReader { geo in
            let side = NowPlayingDeckMetrics.cardSide(
                width: geo.size.width,
                height: geo.size.height,
                landscape: landscape
            )
            // Distance between card centers in the horizontal carousel
            let spread = side * 0.94

            let minIdx = max(0, currentIndex - 2)
            let maxIdx = min(items.count - 1, currentIndex + 2)
            let visibleIndices = minIdx <= maxIdx ? Array(minIdx...maxIdx) : []

            ZStack {
                ForEach(visibleIndices, id: \.self) { index in
                    let item = items[index]
                    let relative = index - currentIndex
                    let baseOffset = CGFloat(relative) * spread
                    let currentOffset = baseOffset + dragOffset
                    let isCenter = (index == currentIndex)

                    // Normalized progress [-1.0 ... 1.0] of current drag relative to card width
                    let dragProgress = side > 0 ? Double(dragOffset / side) : 0.0

                    cardContainer(
                        item: item,
                        index: index,
                        side: side,
                        isCenter: isCenter,
                        relative: relative,
                        dragProgress: dragProgress
                    )
                    .offset(x: currentOffset)
                    .zIndex(isCenter ? 10 : Double(5 - abs(relative)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        // Only capture primarily horizontal gestures
                        let h = value.translation.width
                        let v = value.translation.height
                        guard abs(h) > abs(v) * 0.6 else { return }

                        isDragging = true
                        let isFirst = currentIndex <= 0
                        let isLast = currentIndex >= items.count - 1

                        if (isFirst && h > 0) || (isLast && h < 0) {
                            // Rubber-band resistance at boundaries
                            dragOffset = h * 0.28
                        } else {
                            dragOffset = h
                        }
                    }
                    .onEnded { value in
                        isDragging = false
                        let h = value.translation.width
                        let predicted = value.predictedEndTranslation.width
                        let threshold = NowPlayingDeckMetrics.swipeThreshold
                        let velThreshold = NowPlayingDeckMetrics.velocityThreshold

                        let shouldGoNext = (h < -threshold) || (predicted < -velThreshold && h < -20)
                        let shouldGoPrev = (h > threshold) || (predicted > velThreshold && h > 20)

                        if shouldGoNext && currentIndex < items.count - 1 {
                            commitTrackSwitch(delta: 1)
                        } else if shouldGoPrev && currentIndex > 0 {
                            commitTrackSwitch(delta: -1)
                        } else {
                            // Snap back with natural spring
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .onChange(of: currentIndex) { _, _ in
                // Flip back to artwork smoothly when track changes
                if isFlipped {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                        isFlipped = false
                        flipAngle = 0.0
                    }
                }
            }
            #if DEBUG
            .task {
                let key = "muses.debug.flipHeroCard"
                if UserDefaults.standard.bool(forKey: key) {
                    UserDefaults.standard.set(false, forKey: key)
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    withAnimation(.spring(response: 0.52, dampingFraction: 0.80)) {
                        isFlipped = true
                        flipAngle = 180.0
                    }
                }
            }
            #endif
        }
    }

    private func cardContainer(
        item: QueueItem,
        index: Int,
        side: CGFloat,
        isCenter: Bool,
        relative: Int,
        dragProgress: Double
    ) -> some View {
        // Base scale: breathing physics when paused/playing
        let baseCenterScale: CGFloat = isPlaying ? 1.0 : 0.91
        let neighborScale: CGFloat = 0.82

        let dynamicScale: CGFloat = {
            if relative == 0 {
                // Shrink slightly as dragged away from center
                return baseCenterScale - CGFloat(abs(dragProgress)) * 0.12
            } else if (relative == -1 && dragProgress > 0) {
                // Previous card coming into center
                return neighborScale + CGFloat(dragProgress) * (baseCenterScale - neighborScale)
            } else if (relative == 1 && dragProgress < 0) {
                // Next card coming into center
                return neighborScale + CGFloat(-dragProgress) * (baseCenterScale - neighborScale)
            }
            return neighborScale
        }()

        let dynamicOpacity: Double = {
            if relative == 0 {
                return 1.0 - abs(dragProgress) * 0.35
            } else if (relative == -1 && dragProgress > 0) {
                return 0.38 + dragProgress * 0.62
            } else if (relative == 1 && dragProgress < 0) {
                return 0.38 + (-dragProgress) * 0.62
            }
            return 0.38
        }()

        // 3D perspective rotation tilt during swipe (adds tangible tactile weight)
        let dynamicAngle: Double = {
            if relative == 0 {
                return dragProgress * 6.5
            }
            return 0
        }()

        let corner: CGFloat = min(28, side * 0.08)

        return ZStack {
            // Audio reactive aura behind center card
            if isCenter {
                AudioReactiveAura(isPlaying: isPlaying, side: side)
            }

            if isCenter {
                // 3D Flippable card for center item
                ZStack {
                    heroCardFront(
                        item: item,
                        side: side,
                        corner: corner,
                        isCenter: true,
                        dragProgress: dragProgress
                    )
                    .modifier(FlipCardSideModifier(angle: flipAngle))
                    .rotation3DEffect(
                        .degrees(flipAngle),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.45
                    )

                    heroCardBack(
                        item: item,
                        side: side,
                        corner: corner
                    )
                    .modifier(FlipCardSideModifier(angle: flipAngle - 180))
                    .rotation3DEffect(
                        .degrees(flipAngle - 180),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.45
                    )
                }
                .frame(width: side, height: side)
                .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                .onTapGesture(count: 2) {
                    triggerHeartBurst()
                }
                .onTapGesture(count: 1) {
                    toggleFlip()
                }
            } else {
                // Neighboring preview cards (always front)
                heroCardFront(
                    item: item,
                    side: side,
                    corner: corner,
                    isCenter: false,
                    dragProgress: 0
                )
                .frame(width: side, height: side)
            }
        }
        .scaleEffect(dynamicScale)
        .opacity(dynamicOpacity)
        .rotationEffect(.degrees(dynamicAngle))
        .animation(isDragging ? nil : .spring(response: 0.42, dampingFraction: 0.78), value: isPlaying)
        .animation(isDragging ? nil : .spring(response: 0.38, dampingFraction: 0.82), value: dynamicScale)
        .allowsHitTesting(isCenter)
    }

    // MARK: - Card Front (Pure Artwork with Holographic Sheen & Specular Glass Rim)
    private func heroCardFront(
        item: QueueItem,
        side: CGFloat,
        corner: CGFloat,
        isCenter: Bool,
        dragProgress: Double
    ) -> some View {
        let source = ArtworkSource.resolve(for: item.track)

        return ZStack {
            // Base album artwork
            ArtworkView(
                source: source,
                cornerRadius: corner,
                glyphSize: side * 0.20,
                clipCircle: false,
                targetSize: side,
                presentation: .fill
            )

            // Holographic foil sheen overlay
            if isCenter {
                HolographicFoilOverlay(dragProgress: dragProgress, cornerRadius: corner)
            }

            // Clean specular Liquid Glass rim
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(BrandColors.glassRimGradient, lineWidth: 0.85)

            // Double tap heart burst overlay
            if isCenter && showHeartBurst {
                Image(systemName: "heart.fill")
                    .font(.system(size: side * 0.28, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [BrandColors.laurelGold, Color.white],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: BrandColors.laurelGold.opacity(0.85), radius: 24)
                    .scaleEffect(heartBurstScale)
                    .opacity(heartBurstOpacity)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: side, height: side)
        // Deep layered shadows matching Apple HIG
        .shadow(
            color: .black.opacity(isPlaying && isCenter ? 0.45 : 0.22),
            radius: isPlaying && isCenter ? 32 : 16,
            x: 0,
            y: isPlaying && isCenter ? 14 : 8
        )
        .shadow(
            color: .black.opacity(0.20),
            radius: 6,
            x: 0,
            y: 3
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(item.track.title)
        .accessibilityValue(isPlaying && isCenter ? tr("Playing", "播放中", zhHant: "播放中") : "")
        .accessibilityHint(tr("Tap to view lyrics, double tap to like, swipe to skip tracks", "轻点翻转查看歌词，双击收藏，滑动切换歌曲", zhHant: "輕點翻轉查看歌詞，按兩下收藏，滑動切換歌曲"))
    }

    // MARK: - Card Back (Pure Synced Lyrics Stage + Minimal Action Icons)
    private func heroCardBack(
        item: QueueItem,
        side: CGFloat,
        corner: CGFloat
    ) -> some View {
        ZStack {
            // Obsidian dark glass tablet background
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.11).opacity(0.95))

            // Clean specular glass rim
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(BrandColors.glassRimGradient, lineWidth: 0.85)

            // Content container: purely dedicated to lyrics and minimal corner actions
            VStack(spacing: 0) {
                // Top controls row: Cover button (left) and Fullscreen button (right)
                HStack {
                    // Left: Cover flip icon button (minimal, icon only)
                    Button {
                        toggleFlip()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(BrandColors.laurelGold.opacity(0.95))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08), in: Circle())
                            .overlay(Circle().stroke(BrandColors.glassRimGradient, lineWidth: 0.6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("Show Cover", "显示封面", zhHant: "顯示封面"))

                    Spacer()

                    // Right: Fullscreen lyrics expand icon button (minimal, icon only)
                    Button {
                        onOpenLyrics()
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(BrandColors.laurelGold.opacity(0.95))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08), in: Circle())
                            .overlay(Circle().stroke(BrandColors.glassRimGradient, lineWidth: 0.6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("Fullscreen Lyrics", "全屏歌词", zhHant: "全螢幕歌詞"))
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 4)

                // Middle: Pure Lyrics Stage (dominates the entire card)
                HeroDeckCardLyricsView(
                    lyrics: lyrics ?? item.track.lyrics,
                    currentPosition: playbackPosition,
                    onSeek: onSeek
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .frame(width: side, height: side)
        .shadow(color: .black.opacity(0.40), radius: 24, x: 0, y: 12)
    }

    private func toggleFlip() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.52, dampingFraction: 0.80)) {
            isFlipped.toggle()
            flipAngle = isFlipped ? 180.0 : 0.0
        }
    }

    private func commitTrackSwitch(delta: Int) {
        let next = min(items.count - 1, max(0, currentIndex + delta))
        guard next != currentIndex else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                dragOffset = 0
            }
            return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if isFlipped {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                isFlipped = false
                flipAngle = 0.0
            }
        }

        if reduceMotion {
            dragOffset = 0
            onSelectIndex(next)
        } else {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                dragOffset = 0
                onSelectIndex(next)
            }
        }
    }

    private func triggerHeartBurst() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        onToggleLike?()
        showHeartBurst = true
        heartBurstScale = 0.4
        heartBurstOpacity = 0.95
        withAnimation(.spring(response: 0.42, dampingFraction: 0.58)) {
            heartBurstScale = 1.25
        }
        withAnimation(.easeOut(duration: 0.42).delay(0.28)) {
            heartBurstOpacity = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            showHeartBurst = false
        }
    }
}

/// Compact scrolling lyrics view embedded directly into the card back.
struct HeroDeckCardLyricsView: View {
    let lyrics: String?
    let currentPosition: Double
    var onSeek: ((Double) -> Void)?

    struct ParsedLine: Identifiable {
        let id = UUID()
        let time: Double
        let text: String
    }

    @State private var lines: [ParsedLine] = []

    var body: some View {
        Group {
            if lines.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 26))
                        .foregroundStyle(BrandColors.laurelGold.opacity(0.6))
                    Text(tr("No Lyrics Available", "暂无歌词", zhHant: "暫無歌詞"))
                        .font(EratoTypography.poeticTitle(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.70))
                    Text(tr("Tap card to return to cover", "轻点卡片返回封面", zhHant: "輕點卡片返回封面"))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 12) {
                            Color.clear.frame(height: 16)

                            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                                let distance = abs(index - max(activeIndex, 0))
                                let isActive = index == activeIndex

                                Button {
                                    onSeek?(line.time)
                                } label: {
                                    Text(line.text)
                                        .font(
                                            isActive
                                                ? .system(size: 16, weight: .bold, design: .serif)
                                                : .system(size: 13.5, weight: .medium, design: .serif)
                                        )
                                        .foregroundStyle(foreground(for: distance, active: isActive))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)
                                        .lineSpacing(4)
                                        .padding(.vertical, isActive ? 4 : 2)
                                        .padding(.horizontal, 6)
                                        .scaleEffect(isActive ? 1.04 : 1.0)
                                        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: isActive)
                                }
                                .buttonStyle(.plain)
                                .id(line.id)
                            }

                            Color.clear.frame(height: 24)
                        }
                    }
                    .onChange(of: activeIndex) { _, newIdx in
                        guard newIdx >= 0, newIdx < lines.count else { return }
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                            proxy.scrollTo(lines[newIdx].id, anchor: .center)
                        }
                    }
                }
            }
        }
        .onAppear { parseLyrics() }
        .onChange(of: lyrics) { _, _ in parseLyrics() }
    }

    private func foreground(for distance: Int, active: Bool) -> Color {
        if active { return BrandColors.laurelGold }
        switch distance {
        case 1: return Color.white.opacity(0.55)
        case 2: return Color.white.opacity(0.32)
        default: return Color.white.opacity(0.18)
        }
    }

    private var activeIndex: Int {
        guard !lines.isEmpty else { return -1 }
        var res = -1
        for (i, line) in lines.enumerated() {
            if line.time <= currentPosition {
                res = i
            } else {
                break
            }
        }
        return res
    }

    private func parseLyrics() {
        guard let text = lyrics, !text.isEmpty else {
            lines = []
            return
        }

        var res: [ParsedLine] = []
        for raw in text.components(separatedBy: .newlines) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if let open = trimmed.firstIndex(of: "["),
               let close = trimmed.firstIndex(of: "]"),
               open < close {
                let tag = String(trimmed[trimmed.index(after: open)..<close])
                let lyricText = String(trimmed[trimmed.index(after: close)...]).trimmingCharacters(in: .whitespaces)
                if let t = parseTag(tag), !lyricText.isEmpty {
                    res.append(ParsedLine(time: t, text: lyricText))
                }
            } else {
                res.append(ParsedLine(time: 0, text: trimmed))
            }
        }
        lines = res.sorted { $0.time < $1.time }
    }

    private func parseTag(_ tag: String) -> Double? {
        let parts = tag.components(separatedBy: ":")
        guard parts.count == 2,
              let m = Double(parts[0]),
              let s = Double(parts[1]) else { return nil }
        return m * 60.0 + s
    }
}
