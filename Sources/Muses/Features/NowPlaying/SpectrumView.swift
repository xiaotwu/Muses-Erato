import SwiftUI

/// Mirrored bar spectrum visualization: upper half has 64 bars rising from midline,
/// lower half mirrors them at 30% opacity.
public struct SpectrumView: View {
    @Environment(PlaybackService.self) private var playback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(PrefKey.gpuAcceleration) private var gpuAcceleration = true

    @State private var current: SpectrumFrame?
    @State private var peaks: [Float] = Array(repeating: 0, count: 64)
    @State private var lastFrameDate: Date = .distantPast

    private let bandCount = 64
    private let peakDecayPerSecond: Float = 1.0 / 0.2

    public init() {}

    public var body: some View {
        if gpuAcceleration {
            MetalSpectrumView()
                .frame(height: 140)
        } else {
            canvasSpectrum
        }
    }

    private var canvasSpectrum: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: reduceMotion || !playback.state.isPlaying)) { timeline in
            let decayed = updatePeaks(date: timeline.date)
            Canvas { ctx, size in
                drawSpectrum(ctx: ctx, size: size, values: decayed)
            }
        }
        .frame(height: 140)
        .onAppear {
            playback.installSpectrumHandler { frame in
                DispatchQueue.main.async {
                    current = frame
                }
            }
        }
        .onDisappear {
            playback.removeSpectrumHandler()
        }
    }

    private func updatePeaks(date: Date) -> [Float] {
        let bands = current?.bands ?? Array(repeating: 0, count: bandCount)
        guard bands.count == bandCount else { return peaks }

        if reduceMotion {
            peaks = bands
            return peaks
        }

        let dt = max(0, min(1.0 / 10.0, date.timeIntervalSince(lastFrameDate)))
        let decay = peakDecayPerSecond * Float(dt)
        for i in 0..<bandCount {
            peaks[i] = max(bands[i], peaks[i] - decay)
        }
        lastFrameDate = date
        return peaks
    }

    private func drawSpectrum(ctx: GraphicsContext, size: CGSize, values: [Float]) {
        let width = size.width
        let height = size.height
        let midY = height / 2

        let totalGap = bandCount + 1
        let unit = width / CGFloat(totalGap)
        let barWidth = unit * 0.8
        let gap = unit * 0.2

        let gradient = Gradient(colors: [BrandColors.accent,
                                         BrandColors.accent.opacity(0.55)])
        let shading = GraphicsContext.Shading.linearGradient(
            gradient, startPoint: CGPoint(x: 0, y: midY), endPoint: CGPoint(x: 0, y: 0)
        )
        let mirrorColor = BrandColors.accent.opacity(0.3)

        for i in 0..<bandCount {
            let v = CGFloat(values[i])
            let barH = v * midY
            let x = unit + CGFloat(i) * (barWidth + gap)

            let upperRect = CGRect(x: x, y: midY - barH, width: barWidth, height: barH)
            ctx.fill(Path(upperRect), with: shading)

            let lowerRect = CGRect(x: x, y: midY, width: barWidth, height: barH)
            ctx.fill(Path(lowerRect), with: .color(mirrorColor))
        }
    }
}
