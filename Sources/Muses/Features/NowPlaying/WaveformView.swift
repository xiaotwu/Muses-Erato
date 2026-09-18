import SwiftUI

/// Whole-track waveform thumbnail. The played portion is highlighted in accent color;
/// unplayed portion uses textSecondary at 30% opacity. Supports drag-to-seek.
public struct WaveformView: View {
    @Environment(PlaybackService.self) private var playback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var peaks: [Float] = []
    @State private var trackId: UUID?
    @State private var dragRatio: Double?
    @State private var cachePolling = false

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                    paused: reduceMotion || !playback.state.isPlaying)) { _ in
                Canvas { ctx, size in
                    drawWaveform(ctx: ctx, size: size)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let w = geo.size.width
                        guard w > 0 else { return }
                        dragRatio = min(1, max(0, Double(v.location.x / w)))
                    }
                    .onEnded { v in
                        let w = geo.size.width
                        guard w > 0 else { return }
                        let ratio = min(1, max(0, Double(v.location.x / w)))
                        let dur = playback.state.duration
                        guard dur > 0 else { return }
                        playback.seek(to: ratio * dur)
                        dragRatio = nil
                    }
            )
        }
        .frame(height: 60)
        .onAppear { reload() }
        .onChange(of: playback.state.track?.id) { _, _ in
            dragRatio = nil
            reload()
        }
    }

    private func reload() {
        let id = playback.state.track?.id
        trackId = id
        if let id, let cached = WaveformCache.default.load(forTrackId: id) {
            peaks = cached
            cachePolling = false
        } else {
            peaks = []
            cachePolling = (id != nil)
        }
    }

    private func drawWaveform(ctx: GraphicsContext, size: CGSize) {
        if cachePolling, let id = trackId,
           let cached = WaveformCache.default.load(forTrackId: id) {
            peaks = cached
            cachePolling = false
        }

        let n = peaks.count
        guard n > 0 else {
            // Soft scrubber fallback when waveform peaks are not cached yet.
            let progress: Double = {
                if let r = dragRatio { return r }
                let dur = playback.state.duration
                guard dur > 0 else { return 0 }
                return min(1, max(0, playback.state.position / dur))
            }()
            let track = Path(roundedRect: CGRect(x: 0, y: size.height * 0.42, width: size.width, height: 4), cornerRadius: 2)
            ctx.fill(track, with: .color(BrandColors.textSecondary.opacity(0.22)))
            let filled = Path(roundedRect: CGRect(x: 0, y: size.height * 0.42, width: size.width * progress, height: 4), cornerRadius: 2)
            ctx.fill(filled, with: .color(BrandColors.accent.opacity(0.9)))
            return
        }

        let width = size.width
        let height = size.height
        let midY = height / 2

        let dur = playback.state.duration
        let pos = playback.state.position
        let progress: Double
        if let r = dragRatio {
            progress = r
        } else if dur > 0 {
            progress = pos / dur
        } else {
            progress = 0
        }
        let playedIdx = min(n, max(0, Int(Double(n) * progress)))

        let unit = width / CGFloat(n)
        let barWidth = max(1, unit * 0.8)
        let playedShading = GraphicsContext.Shading.color(BrandColors.accent)
        let unplayedShading = GraphicsContext.Shading.color(BrandColors.textSecondary.opacity(0.3))

        for i in 0..<n {
            let v = CGFloat(peaks[i])
            let barH = v * height
            guard barH > 0 else { continue }
            let x = CGFloat(i) * unit
            let rect = CGRect(x: x, y: midY - barH / 2, width: barWidth, height: barH)
            let path = Path(roundedRect: rect, cornerRadius: 1)
            ctx.fill(path, with: i < playedIdx ? playedShading : unplayedShading)
        }
    }
}
