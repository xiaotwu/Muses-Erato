import SwiftUI

/// Semantic glass roles keep native glass behavior centralized instead of
/// scattering material choices through feature views.
public enum MusesGlassRole: Equatable {
    case navigationBar
    case floatingPlayer
    case tabBar
    case modalDeck
    case compactControl

    public var isInteractive: Bool {
        self == .floatingPlayer || self == .compactControl || self == .modalDeck
    }
}

/// Pure decision logic (testable, no SwiftUI environment rendering required).
public enum GlassMode: Equatable {
    case opaque, glass, material

    /// `supportsGlass`: whether the runtime supports native Liquid Glass (iOS 26+).
    public static func mode(
        reduceTransparency: Bool,
        increaseContrast: Bool,
        supportsGlass: Bool
    ) -> GlassMode {
        if reduceTransparency || increaseContrast { return .opaque }
        return supportsGlass ? .glass : .material
    }
}

/// Whether the runtime supports `glassEffect` (isolates `#available` for test injection).
private var supportsLiquidGlass: Bool {
    if #available(iOS 26.0, *) { return true }
    return false
}

/// Muses glass primitive: one glass presentation for all persistent/floating chrome surfaces.
///
/// - iOS 26+: native `glassEffect(_:in:)` — the system provides real Liquid Glass.
/// - iOS 18/25: falls back to `.ultraThinMaterial` with a light specular rim.
/// - Reduce Transparency or Increase Contrast: opaque `BrandColors.surface`.
///
/// `tint` is semantic only (playing/selected states); `nil` means neutral glass.
public struct MusesGlassModifier<S: Shape>: ViewModifier {
    public let shape: S
    public let tint: Color?
    public let role: MusesGlassRole
    public let showsLaserEdge: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    public init(shape: S, tint: Color? = nil, role: MusesGlassRole = .floatingPlayer, showsLaserEdge: Bool = true) {
        self.shape = shape
        self.tint = tint
        self.role = role
        self.showsLaserEdge = showsLaserEdge
    }

    public func body(content: Content) -> some View {
        let mode = GlassMode.mode(
            reduceTransparency: reduceTransparency,
            increaseContrast: contrast == .increased,
            supportsGlass: supportsLiquidGlass
        )
        switch mode {
        case .opaque:
            content.background(BrandColors.surface, in: shape)
        case .glass:
            if #available(iOS 26.0, *) {
                content
                    .glassEffect(glassVariant, in: shape)
                    .overlay { laserEdgeOverlay }
            } else {
                materialFallback(content)
            }
        case .material:
            materialFallback(content)
        }
    }

    @ViewBuilder
    private func materialFallback(_ content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: shape)
            .overlay(specularBorder)
            .overlay { laserEdgeOverlay }
            .shadow(color: BrandColors.glassShadow, radius: 14, x: 0, y: 6)
    }

    private var specularBorder: some View {
        shape.stroke(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.35),
                    Color.white.opacity(0.08),
                    Color.black.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: 0.6
        )
    }

    
    @ViewBuilder
    private var laserEdgeOverlay: some View {
        if showsLaserEdge {
            shape.stroke(
                AngularGradient(
                    colors: BrandColors.laserSpectrum.map { $0.opacity(0.58) },
                    center: .center
                ),
                lineWidth: 0.75
            )
            .allowsHitTesting(false)
        }
    }

    @available(iOS 26.0, *)
    private var glassVariant: Glass {
        let base = tint.map { Glass.regular.tint($0) } ?? .regular
        return role.isInteractive ? base.interactive(!reduceMotion) : base
    }
}

public extension View {
    func musesTitleGlow() -> some View {
        shadow(color: BrandColors.textPrimary.opacity(0.28), radius: AppleMusicTokens.selectedGlowRadius)
            .shadow(color: BrandColors.textPrimary.opacity(0.12), radius: 1)
    }

    /// Applies the Muses Liquid Glass effect to any custom shape.
    func musesGlass<S: Shape>(
        in shape: S,
        tint: Color? = nil,
        role: MusesGlassRole = .floatingPlayer,
        showsLaserEdge: Bool = true
    ) -> some View {
        modifier(MusesGlassModifier(shape: shape, tint: tint, role: role, showsLaserEdge: showsLaserEdge))
    }

    /// Convenience overload for continuous rounded rectangles (MiniPlayer, sheets, modals).
    func musesGlass(
        cornerRadius: CGFloat = AppleMusicTokens.miniPlayerCornerRadius,
        tint: Color? = nil,
        role: MusesGlassRole = .floatingPlayer,
        showsLaserEdge: Bool = true
    ) -> some View {
        modifier(
            MusesGlassModifier(
                shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                tint: tint,
                role: role,
                showsLaserEdge: showsLaserEdge
            )
        )
    }

    /// Convenience overload for Capsule floating elements (Floating TabBar, scrubber decks).
    func musesGlassCapsule(
        tint: Color? = nil,
        role: MusesGlassRole = .tabBar,
        showsLaserEdge: Bool = true
    ) -> some View {
        modifier(MusesGlassModifier(shape: Capsule(), tint: tint, role: role, showsLaserEdge: showsLaserEdge))
    }

    /// Floating panel used in Search, Queue, and Sheets.
    func musesFloatingChrome(cornerRadius: CGFloat = 20) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .clipShape(shape)
            .musesGlass(in: shape, role: .modalDeck)
    }
}

/// A bounded chrome group; browsing artwork never participates in glass morphs.
public struct MusesGlassGroup<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: () -> Content

    public init(spacing: CGFloat = 12, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing, content: content)
        } else {
            content()
        }
    }
}
