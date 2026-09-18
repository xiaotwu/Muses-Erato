import SwiftUI

/// Thin iridescent “laser” edge for glass chrome, matching the monochrome Muse logo brand.
struct LaserStrokeModifier<S: Shape>: ViewModifier {
    var lineWidth: CGFloat = 1.1
    var opacity: Double = 0.72
    var shape: S

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content.overlay {
            if reduceTransparency || contrast == .increased {
                shape.stroke(BrandColors.hairline, lineWidth: lineWidth)
            } else {
                shape.stroke(
                    AngularGradient(
                        colors: BrandColors.laserSpectrum.map { $0.opacity(opacity) },
                        center: .center
                    ),
                    lineWidth: lineWidth
                )
            }
        }
    }
}

extension View {
    func laserStroke(lineWidth: CGFloat = 1.1, opacity: Double = 0.72) -> some View {
        modifier(LaserStrokeModifier(lineWidth: lineWidth, opacity: opacity, shape: Capsule()))
    }

    func laserStroke<S: Shape>(
        _ shape: S,
        lineWidth: CGFloat = 1.1,
        opacity: Double = 0.72
    ) -> some View {
        modifier(LaserStrokeModifier(lineWidth: lineWidth, opacity: opacity, shape: shape))
    }
}
