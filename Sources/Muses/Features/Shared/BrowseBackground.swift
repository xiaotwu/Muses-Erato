import SwiftUI

private struct BrowseGradientKey: EnvironmentKey {
    static let defaultValue: [Color] = []
}

public extension EnvironmentValues {
    var browseGradient: [Color] {
        get { self[BrowseGradientKey.self] }
        set { self[BrowseGradientKey.self] = newValue }
    }
}

/// Soft multi-blob ambient wash so Liquid Glass has something to refract against.
/// Uses `browseGradient` when provided; otherwise deep charcoal + soft gray/white wash (logo brand).
public struct BrowseBackground: View {
    @Environment(\.browseGradient) private var colors
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion


    public init() {}

    public var body: some View {
        Group {
            if reduceTransparency {
                BrandColors.background
            } else {
                TimelineView(.animation(minimumInterval: reduceMotion ? 10 : 1 / 30, paused: reduceMotion)) { timeline in
                    let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, size in
                        let base = BrandColors.background
                        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))

                        let palette = resolvedPalette
                        let blobs: [(CGPoint, CGFloat, Color)] = [
                            (CGPoint(x: size.width * (0.18 + 0.04 * sin(t * 0.11)),
                                     y: size.height * (0.22 + 0.03 * cos(t * 0.09))),
                             size.width * 0.72, palette[0].opacity(0.42)),
                            (CGPoint(x: size.width * (0.82 + 0.03 * cos(t * 0.08)),
                                     y: size.height * (0.18 + 0.04 * sin(t * 0.10))),
                             size.width * 0.64, palette[1].opacity(0.36)),
                            (CGPoint(x: size.width * (0.55 + 0.05 * sin(t * 0.07)),
                                     y: size.height * (0.62 + 0.04 * cos(t * 0.12))),
                             size.width * 0.78, palette[2].opacity(0.28)),
                            (CGPoint(x: size.width * (0.28 + 0.03 * cos(t * 0.06)),
                                     y: size.height * (0.78 + 0.03 * sin(t * 0.08))),
                             size.width * 0.55, palette[0].opacity(0.18)),
                        ]

                        for (center, radius, color) in blobs {
                            let rect = CGRect(
                                x: center.x - radius / 2,
                                y: center.y - radius / 2,
                                width: radius,
                                height: radius
                            )
                            context.fill(
                                Path(ellipseIn: rect),
                                with: .radialGradient(
                                    Gradient(colors: [color, color.opacity(0.01)]),
                                    center: center,
                                    startRadius: 0,
                                    endRadius: radius / 2
                                )
                            )
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var resolvedPalette: [Color] {
        let fallback: [Color] = [
            Color(white: 0.14),
            Color(white: 0.42).opacity(0.55),
            Color(white: 0.72).opacity(0.28),
        ]
        if colors.count >= 3 { return Array(colors.prefix(3)) }
        if colors.count == 2 { return colors + [fallback[2]] }
        if colors.count == 1 { return [fallback[0], colors[0], fallback[2]] }
        return fallback
    }
}
