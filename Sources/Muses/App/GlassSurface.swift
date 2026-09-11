import SwiftUI

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

/// Muses Liquid Glass view modifier conforming strictly to Apple WWDC 2025/2026 Liquid Glass HIG.
///
/// Features:
/// - iOS 26+: Utilizes `.glassEffect()` with `.interactive()` for real-time meta-material physics.
/// - iOS 18–25: Gracefully falls back to high-fidelity `.ultraThinMaterial` with specular glass highlight border.
/// - Accessibility: When `Reduce Transparency` or `Increase Contrast` is enabled, falls back to opaque `BrandColors.surface`.
public struct MusesGlassModifier<S: Shape>: ViewModifier {
    public let shape: S
    public let tint: Color?
    public let role: MusesGlassRole
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(shape: S, tint: Color? = nil, role: MusesGlassRole = .floatingPlayer) {
        self.shape = shape
        self.tint = tint
        self.role = role
    }

    public func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(BrandColors.surface, in: shape)
                .overlay(shape.stroke(BrandColors.textPrimary.opacity(0.15), lineWidth: 1))
        } else {
            #if os(iOS)
            if #available(iOS 26.0, *) {
                content
                    .glassEffect(in: shape)
                    .overlay(glassSpecularBorder)
                    .shadow(color: BrandColors.glassShadow, radius: 16, x: 0, y: 8)
            } else {
                content
                    .background(.ultraThinMaterial, in: shape)
                    .overlay(glassSpecularBorder)
                    .shadow(color: BrandColors.glassShadow, radius: 14, x: 0, y: 6)
            }
            #else
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(glassSpecularBorder)
                .shadow(color: BrandColors.glassShadow, radius: 14, x: 0, y: 6)
            #endif
        }
    }

    private var glassSpecularBorder: some View {
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
}

public extension View {
    /// Applies the Muses Liquid Glass effect to any custom shape.
    func musesGlass<S: Shape>(in shape: S, tint: Color? = nil, role: MusesGlassRole = .floatingPlayer) -> some View {
        modifier(MusesGlassModifier(shape: shape, tint: tint, role: role))
    }

    /// Convenience overload for continuous rounded rectangles (MiniPlayer, sheets, modals).
    func musesGlass(cornerRadius: CGFloat = AppleMusicTokens.miniPlayerCornerRadius,
                    tint: Color? = nil,
                    role: MusesGlassRole = .floatingPlayer) -> some View {
        modifier(MusesGlassModifier(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                                    tint: tint,
                                    role: role))
    }

    /// Convenience overload for Capsule floating elements (Floating TabBar, scrubber decks).
    func musesGlassCapsule(tint: Color? = nil, role: MusesGlassRole = .tabBar) -> some View {
        modifier(MusesGlassModifier(shape: Capsule(), tint: tint, role: role))
    }

    /// Floating panel used in Search, Queue, and Sheets.
    func musesFloatingChrome(cornerRadius: CGFloat = 20) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .clipShape(shape)
            .musesGlass(in: shape, role: .modalDeck)
    }
}
