import SwiftUI

enum NowPlayingDeckMetrics {
    static func radius(width: CGFloat, landscape: Bool) -> Int {
        if landscape || width >= 700 { return 2 }
        return 1
    }

    static func cardSide(width: CGFloat, height: CGFloat, landscape: Bool) -> CGFloat {
        if landscape {
            return min(width * 0.38, height * 0.72, 280)
        }
        return min(width * 0.64, height * 0.52, 320)
    }

    static let skipThreshold: CGFloat = 56
}

struct NowPlayingHeroDeck: View {
    let items: [QueueItem]
    let currentIndex: Int
    let isPlaying: Bool
    var onSelectIndex: (Int) -> Void
    var onOpenLyrics: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var drag: CGSize = .zero

    private var landscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        GeometryReader { geo in
            let radius = NowPlayingDeckMetrics.radius(width: geo.size.width, landscape: landscape)
            let side = NowPlayingDeckMetrics.cardSide(
                width: geo.size.width,
                height: geo.size.height,
                landscape: landscape
            )
            let spread = side * 0.58
            let visible = CollectionDeckProjection.visibleIndices(
                count: items.count,
                position: CGFloat(currentIndex),
                radius: radius
            )

            ZStack {
                ForEach(visible, id: \.self) { index in
                    let item = items[index]
                    heroCard(item: item, side: side, isCenter: index == currentIndex)
                        .scaleEffect(index == currentIndex ? 1 : 0.78)
                        .offset(x: CGFloat(index - currentIndex) * spread + drag.width * 0.15)
                        .opacity(index == currentIndex ? 1 : 0.45)
                        .zIndex(index == currentIndex ? 2 : 0)
                        .allowsHitTesting(index == currentIndex)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 24)
                    .onChanged { value in
                        drag = value.translation
                    }
                    .onEnded { value in
                        let translation = value.translation
                        drag = .zero
                        guard abs(translation.height) > abs(translation.width) * 1.25,
                              abs(translation.height) >= NowPlayingDeckMetrics.skipThreshold else {
                            return
                        }
                        if translation.height < 0 {
                            skip(1)
                        } else {
                            skip(-1)
                        }
                    }
            )
        }
    }

    private func heroCard(item: QueueItem, side: CGFloat, isCenter: Bool) -> some View {
        let source = ArtworkSource.resolve(for: item.track)
        return ArtworkView(
            source: source,
            cornerRadius: side / 2,
            glyphSize: side * 0.18,
            clipCircle: true,
            targetSize: side
        )
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
        .modifier(NowPlayingSpinModifier(isPlaying: isCenter && isPlaying && !reduceMotion))
        .onTapGesture {
            if isCenter { onOpenLyrics() }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(item.track.title)
        .accessibilityHint(tr("Shows lyrics", "显示歌词", zhHant: "顯示歌詞"))
    }

    private func skip(_ delta: Int) {
        let next = min(items.count - 1, max(0, currentIndex + delta))
        guard next != currentIndex else { return }
        if reduceMotion {
            onSelectIndex(next)
        } else {
            withAnimation(.spring(duration: 0.38, bounce: 0.12)) {
                onSelectIndex(next)
            }
        }
    }
}

private struct NowPlayingSpinModifier: ViewModifier {
    let isPlaying: Bool
    @State private var accumulatedDegrees: Double = 0
    @State private var activeSince: Date?

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isPlaying)) { timeline in
            content.rotationEffect(.degrees(VinylRotation.angle(
                accumulatedDegrees: accumulatedDegrees,
                activeSince: activeSince,
                at: timeline.date,
                isRotating: isPlaying
            )))
        }
        .onAppear { synchronize(at: Date()) }
        .onChange(of: isPlaying) { _, _ in synchronize(at: Date()) }
    }

    private func synchronize(at date: Date) {
        if let activeSince {
            accumulatedDegrees = VinylRotation.angle(
                accumulatedDegrees: accumulatedDegrees,
                activeSince: activeSince,
                at: date,
                isRotating: true
            )
        }
        activeSince = isPlaying ? date : nil
    }
}
