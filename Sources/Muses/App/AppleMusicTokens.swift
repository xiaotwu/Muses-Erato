import SwiftUI

/// Semantic spacing and geometry tokens for Muses iOS.
public enum AppleMusicSpacing {
    public static let pageHorizontal: CGFloat = 20
    public static let pageTop: CGFloat = 16
    public static let sectionHeaderToContent: CGFloat = 14
    public static let sectionSpacing: CGFloat = 28
    public static let shelfItemSpacing: CGFloat = 16
    public static let gridSpacing: CGFloat = 16
    public static let chromeOuter: CGFloat = 16
    public static let chromeInner: CGFloat = 12
    public static let tableCellPadding: CGFloat = 12
    public static let tableCell: CGFloat = 12
    public static let related: CGFloat = 16
    public static let section: CGFloat = 28
    public static let browseTitleTop: CGFloat = 16
    public static let headerToPrimary: CGFloat = 28
    /// Minimum comfortable hit target (Apple HIG).
    public static let hitTarget: CGFloat = 44
}

public enum OverlayChromeMetrics {
    public static let scrollBottomInset: CGFloat = 140
}

enum PlaylistOverviewMetrics {
    static let minimumColumnWidth: CGFloat = 250
    static let maximumColumnWidth: CGFloat = 280
    static let cardWidth: CGFloat = 260
    static let artworkHeight: CGFloat = 230
    static let footerHeight: CGFloat = 100
    static let cardHeight: CGFloat = artworkHeight + footerHeight
    static let cornerRadius: CGFloat = 20
    static let columnSpacing: CGFloat = 24
    static let rowSpacing: CGFloat = 30
    static let hoverLift: CGFloat = 5
    static let pressedScale: CGFloat = 0.992
}

enum HomeMediaCardMetrics {
    static let footerHeight: CGFloat = 72
}

/// Core visual design tokens for Muses (iOS Liquid Glass Edition).
public enum AppleMusicTokens {
    /// Neutral brand key — classical lyre & laurel gold.
    public static let keyColorHex = "C7A66B"
    public static var keyColor: Color { BrandColors.laurelGold }

    // Layout Dimensions for iOS
    public static let tabBarHeight: CGFloat = 58
    public static let tabBarFloatingInset: CGFloat = 16
    public static let miniPlayerHeight: CGFloat = 54
    public static let miniPlayerCornerRadius: CGFloat = 16
    public static let selectedGlowRadius: CGFloat = 8
    public static let miniPlayerDockMargin: CGFloat = 8

    public static let cardCornerRadius: CGFloat = 14
    public static let cardCorner: CGFloat = 14
    public static let contentPaddingX: CGFloat = 20
    public static let pageTitleSize: CGFloat = 34
    public static let sectionTitleSize: CGFloat = 22
    public static let albumCoverCornerRadius: CGFloat = 22
    public static let editorialAspect: CGFloat = 16.0 / 9.0
    public static let scrollBottomInset: CGFloat = OverlayChromeMetrics.scrollBottomInset

    public static let collectionDeckRoomyCardWidth: CGFloat = 220
    public static let collectionDeckCompactCardWidth: CGFloat = 175
    public static let collectionDeckRoomyFooterHeight: CGFloat = 68
    public static let collectionDeckCompactFooterHeight: CGFloat = 56
    public static let collectionDeckRoomySpread: CGFloat = 110
    public static let collectionDeckMediumSpread: CGFloat = 96
    public static let collectionDeckCompactSpread: CGFloat = 84
    public static let collectionDeckWideBreakpoint: CGFloat = 810
    public static let collectionDeckCompactBreakpoint: CGFloat = 620
    public static let collectionDeckCompactHeight: CGFloat = 680
    public static let collectionDeckHoverLift: CGFloat = 12
    public static let collectionDeckExpansionThreshold: CGFloat = 48
    public static let collectionDeckScrubberHeight: CGFloat = 52
    public static let collectionDeckHandleHeight: CGFloat = 44
    public static let trackArtworkSize: CGFloat = 38

    // Now Playing Stage
    public static let nowPlayingMaxArtworkSize: CGFloat = 340
    public static let nowPlayingMinArtworkSize: CGFloat = 240
    public static let nowPlayingControlHeight: CGFloat = 64
}

/// Dynamic semantic brand colors — Erato Muse classical palette + authentic Liquid Glass optics.
public enum BrandColors {
    /// Classical lyre & laurel warm gold accent for subtle, noble highlights (strings, playhead, active indicators).
    public static var laurelGold: Color {
        Color(red: 0.82, green: 0.68, blue: 0.44)
    }

    /// Primary interactive accent, matching the classical laurel gold tone.
    public static var accent: Color { laurelGold }

    /// Legacy aliases redirected to laurel gold accent.
    public static var magenta: Color { laurelGold }
    public static var pink: Color { laurelGold }
    public static var scrim: Color { Color.black.opacity(0.4) }
    public static var hairline: Color { Color.white.opacity(0.14) }

    /// Soft gray used for secondary chrome fills.
    public static var neutralGray: Color {
        Color(white: 0.55)
    }

    /// Monochrome specular reflection for glass rim highlights (replaces rainbow laser spectrum).
    public static var laserSpectrum: [Color] {
        [
            Color.white.opacity(0.40),
            Color.white.opacity(0.20),
            Color.white.opacity(0.08),
            Color.white.opacity(0.04),
            Color.white.opacity(0.18),
            Color.white.opacity(0.40),
        ]
    }

    /// Directional specular rim gradient simulating top-left light incidence on Liquid Glass.
    public static var glassRimGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.45),
                Color.white.opacity(0.15),
                Color.white.opacity(0.05),
                Color.black.opacity(0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Dynamic background: Obsidian/Pure Ink in Dark Mode and Crisp Alabaster in Light Mode.
    public static var background: Color {
        #if os(iOS)
        Color(uiColor: .systemBackground)
        #else
        Color(red: 9 / 255, green: 9 / 255, blue: 11 / 255)
        #endif
    }

    /// Dynamic grouped background for secondary panels and lists.
    public static var surface: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemBackground)
        #else
        Color(red: 22 / 255, green: 22 / 255, blue: 25 / 255)
        #endif
    }

    /// Elevated surface for cards and floating drawers.
    public static var elevatedSurface: Color {
        #if os(iOS)
        Color(uiColor: .tertiarySystemBackground)
        #else
        Color(red: 32 / 255, green: 32 / 255, blue: 36 / 255)
        #endif
    }

    /// Primary dynamic label text.
    public static var textPrimary: Color {
        #if os(iOS)
        Color(uiColor: .label)
        #else
        Color.white
        #endif
    }

    /// Secondary dynamic label text.
    public static var textSecondary: Color {
        #if os(iOS)
        Color(uiColor: .secondaryLabel)
        #else
        Color.gray
        #endif
    }

    /// Tertiary dynamic label text.
    public static var textTertiary: Color {
        #if os(iOS)
        Color(uiColor: .tertiaryLabel)
        #else
        Color.gray.opacity(0.6)
        #endif
    }

    /// Specular hairline highlight for Liquid Glass edges.
    public static var glassBorder: Color {
        Color.white.opacity(0.22)
    }

    /// Liquid Glass natural depth shadow color.
    public static var glassShadow: Color {
        Color.black.opacity(0.20)
    }
}

/// Poetic and classical typography tokens inspired by Erato and Apple New York.
public enum EratoTypography {
    /// Poetic title font using Apple system serif (New York) for lyrical and editorial headers.
    public static func poeticTitle(size: CGFloat = 28, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Classical lyric font with generous line tracking.
    public static func lyric(size: CGFloat = 22, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Precision technical / duration / bit-depth font.
    public static func mono(size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
