import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

struct VinylModeView: View {
    let source: ArtworkSource
    var size: CGFloat = 340
    @Environment(PlaybackService.self) private var playback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var accumulatedDegrees: Double = 0
    @State private var activeSince: Date?

    init(source: ArtworkSource, size: CGFloat = 340) {
        self.source = source
        self.size = size
    }

    private var shouldRotate: Bool { playback.state.isPlaying && !reduceMotion }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !shouldRotate)) { timeline in
            ZStack {
                // Vinyl outer grooved ring
                Circle()
                    .fill(Color(white: 0.12))
                    .frame(width: size, height: size)
                    .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 12)
                
                // Fine grooves
                Circle()
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    .frame(width: size * 0.92, height: size * 0.92)
                Circle()
                    .strokeBorder(Color.white.opacity(0.04), lineWidth: 1)
                    .frame(width: size * 0.82, height: size * 0.82)
                Circle()
                    .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                    .frame(width: size * 0.72, height: size * 0.72)

                // Vinyl sheen gradient
                AngularGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.0),
                        Color.white.opacity(0.12),
                        Color.white.opacity(0.0),
                        Color.white.opacity(0.08),
                        Color.white.opacity(0.0)
                    ]),
                    center: .center
                )
                .frame(width: size, height: size)
                .clipShape(Circle())

                // Center label (Album Art)
                ArtworkView(source: source, cornerRadius: size * 0.3, glyphSize: size * 0.15, clipCircle: true, targetSize: size * 0.6)
                    .clipShape(Circle())
                    .overlay(
                        Circle().strokeBorder(Color.black.opacity(0.2), lineWidth: 2)
                    )

                // Spindle hole
                Circle()
                    .fill(Color.black)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .rotationEffect(.degrees(VinylRotation.angle(
                accumulatedDegrees: accumulatedDegrees,
                activeSince: activeSince,
                at: timeline.date,
                isRotating: shouldRotate
            )))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .onAppear { synchronizeRotation(at: Date()) }
        .onChange(of: playback.state.isPlaying) { _, _ in
            synchronizeRotation(at: Date())
        }
        .onChange(of: reduceMotion) { _, _ in
            synchronizeRotation(at: Date())
        }
        .onChange(of: playback.state.track?.id) { _, _ in
            accumulatedDegrees = 0
            activeSince = shouldRotate ? Date() : nil
        }
    }

    private func synchronizeRotation(at date: Date) {
        if let activeSince {
            accumulatedDegrees = VinylRotation.angle(
                accumulatedDegrees: accumulatedDegrees,
                activeSince: activeSince,
                at: date,
                isRotating: true
            )
        }
        activeSince = shouldRotate ? date : nil
    }
}

public enum VinylRotation {
    public static let secondsPerRevolution: Double = 16
    public static let rpm: Double = 60.0 / secondsPerRevolution
    public static let degreesPerSecond = rpm * 360.0 / 60.0

    public static func angle(accumulatedDegrees: Double,
                             activeSince: Date?,
                             at date: Date,
                             isRotating: Bool) -> Double {
        guard isRotating, let activeSince else {
            return normalized(accumulatedDegrees)
        }
        let elapsed = max(0, date.timeIntervalSince(activeSince))
        return normalized(accumulatedDegrees + elapsed * degreesPerSecond)
    }

    private static func normalized(_ angle: Double) -> Double {
        let value = angle.truncatingRemainder(dividingBy: 360)
        return value >= 0 ? value : value + 360
    }
}
