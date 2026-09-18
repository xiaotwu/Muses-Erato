import SwiftUI

/// Holographic laser edge: thin AngularGradient spectrum stroke over glass chrome.
struct LaserStrokeModifier<S: Shape>: ViewModifier {
    var shape: S
    var lineWidth: CGFloat
    var opacity: Double

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    init(shape: S, lineWidth: CGFloat = 1.0, opacity: Double = 0.70) {
        self.shape = shape
        self.lineWidth = lineWidth
        self.opacity = min(0.85, max(0.55, opacity))
    }

    func body(content: Content) -> some View {
        content.overlay {
            if reduceTransparency || contrast == .increased {
                shape.stroke(BrandColors.hairline, lineWidth: lineWidth)
                    .allowsHitTesting(false)
            } else {
                shape.stroke(
                    AngularGradient(
                        colors: BrandColors.laserSpectrum.map { $0.opacity(opacity) },
                        center: .center
                    ),
                    lineWidth: lineWidth
                )
                .allowsHitTesting(false)
            }
        }
    }
}

extension View {
    /// Capsule default (pills / tab bar).
    func laserStroke(lineWidth: CGFloat = 1.1, opacity: Double = 0.72) -> some View {
        modifier(LaserStrokeModifier(shape: Capsule(), lineWidth: lineWidth, opacity: opacity))
    }

    /// Shape-first API used across MainTab / Library.
    func laserStroke<S: Shape>(
        _ shape: S,
        lineWidth: CGFloat = 1.1,
        opacity: Double = 0.72
    ) -> some View {
        modifier(LaserStrokeModifier(shape: shape, lineWidth: lineWidth, opacity: opacity))
    }

    /// `in:` labeled shape (InsettableShape call sites).
    func laserStroke<S: Shape>(
        in shape: S,
        lineWidth: CGFloat = 1.0,
        opacity: Double = 0.70
    ) -> some View {
        modifier(LaserStrokeModifier(shape: shape, lineWidth: lineWidth, opacity: opacity))
    }

    /// Rounded-rectangle convenience matching continuous glass chrome.
    func laserStroke(
        cornerRadius: CGFloat,
        lineWidth: CGFloat = 1.0,
        opacity: Double = 0.70
    ) -> some View {
        laserStroke(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            lineWidth: lineWidth,
            opacity: opacity
        )
    }

    func laserStrokeCapsule(lineWidth: CGFloat = 0.9, opacity: Double = 0.65) -> some View {
        laserStroke(Capsule(), lineWidth: lineWidth, opacity: opacity)
    }

    func laserStrokeCircle(lineWidth: CGFloat = 1.0, opacity: Double = 0.70) -> some View {
        laserStroke(Circle(), lineWidth: lineWidth, opacity: opacity)
    }
}
