import SwiftUI

enum NowPlayingDeckMetrics {
    static func radius(width: CGFloat, landscape: Bool) -> Int {
        if width >= 1100 { return 3 }
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
                        let direction: CollectionExpansionDirection = translation.height < 0 ? .up : .down
                        let shouldSkip = CollectionDeckProjection.acceptsVerticalGesture(
                            translation: translation,
                            direction: direction,
                            threshold: NowPlayingDeckMetrics.skipThreshold
                        )
                        if shouldSkip {
                            drag = .zero
                            skip(translation.height < 0 ? 1 : -1)
                        } else {
                            // Horizontal peek only: snap neighbors back without changing tracks.
                            withAnimation(.spring(duration: 0.32, bounce: 0.18)) {
                                drag = .zero
                            }
                        }
                    }
            )
        }
    }

    private func heroCard(item: QueueItem, side: CGFloat, isCenter: Bool) -> some View {
        let source = ArtworkSource.resolve(for: item.track)
        // Rectangular cover card (matches CoverArtModeView), not vinyl circle.
        let corner = min(24, side * 0.08)
        return ArtworkView(
            source: source,
            cornerRadius: corner,
            glyphSize: side * 0.18,
            clipCircle: false,
            targetSize: side,
            presentation: .fill
        )
        .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
        .onTapGesture {
            if isCenter { onOpenLyrics() }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(item.track.title)
        .accessibilityValue(isPlaying && isCenter ? tr("Playing", "播放中", zhHant: "播放中") : "")
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
