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
                            (CGPoint(x: size.width * (0.20 + 0.03 * sin(t * 0.05)),
                                     y: size.height * (0.18 + 0.02 * cos(t * 0.04))),
                             size.width * 0.85, palette[0].opacity(0.18)),
                            (CGPoint(x: size.width * (0.80 + 0.02 * cos(t * 0.04)),
                                     y: size.height * (0.24 + 0.03 * sin(t * 0.05))),
                             size.width * 0.70, palette[1].opacity(0.15)),
                            (CGPoint(x: size.width * (0.50 + 0.03 * sin(t * 0.03)),
                                     y: size.height * (0.65 + 0.02 * cos(t * 0.04))),
                             size.width * 0.90, palette[2].opacity(0.12)),
                            (CGPoint(x: size.width * (0.25 + 0.02 * cos(t * 0.04)),
                                     y: size.height * (0.82 + 0.02 * sin(t * 0.03))),
                             size.width * 0.65, palette[0].opacity(0.10)),
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
                                    Gradient(colors: [color, color.opacity(0.005)]),
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
            Color(red: 0.12, green: 0.12, blue: 0.15),
            Color(red: 0.18, green: 0.18, blue: 0.22),
            Color(red: 0.10, green: 0.10, blue: 0.12),
        ]
        if colors.count >= 3 { return Array(colors.prefix(3)) }
        if colors.count == 2 { return colors + [fallback[2]] }
        if colors.count == 1 { return [fallback[0], colors[0], fallback[2]] }
        return fallback
    }
}
