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
}

public enum OverlayChromeMetrics {
    public static let scrollBottomInset: CGFloat = 110
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
    public static let keyColorHex = "FA586A"
    public static let keyColor = Color(red: 250.0 / 255.0, green: 88.0 / 255.0, blue: 106.0 / 255.0)

    // Layout Dimensions for iOS
    public static let tabBarHeight: CGFloat = 58
    public static let tabBarFloatingInset: CGFloat = 16
    public static let miniPlayerHeight: CGFloat = 54
    public static let miniPlayerCornerRadius: CGFloat = 16
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

/// Dynamic semantic brand colors conforming to Apple Human Interface Guidelines.
public enum BrandColors {
    /// Apple Music signature pink / coral key accent `#FA586A`.
    public static let accent = AppleMusicTokens.keyColor
    public static let magenta = accent
    public static let pink = accent
    public static var scrim: Color { Color.black.opacity(0.4) }
    public static var hairline: Color { Color.white.opacity(0.12) }

    /// Dynamic background adapting between Obsidian/Pure Black in Dark Mode and Crisp Off-White in Light Mode.
    public static var background: Color {
        #if os(iOS)
        Color(uiColor: .systemBackground)
        #else
        Color(red: 18 / 255, green: 18 / 255, blue: 20 / 255)
        #endif
    }

    /// Dynamic grouped background for secondary panels and lists.
    public static var surface: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemBackground)
        #else
        Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
        #endif
    }

    /// Elevated surface for cards and floating drawers.
    public static var elevatedSurface: Color {
        #if os(iOS)
        Color(uiColor: .tertiarySystemBackground)
        #else
        Color(red: 40 / 255, green: 40 / 255, blue: 44 / 255)
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
        Color.white.opacity(0.18)
    }

    /// Liquid Glass shadow color.
    public static var glassShadow: Color {
        Color.black.opacity(0.18)
    }
}
