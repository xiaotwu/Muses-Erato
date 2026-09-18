import SwiftUI

public enum MusesMotion {
    /// liqui.design-inspired press scale for chrome / transport controls.
    public static let pressScale: CGFloat = 0.97

    public static let hover: TimeInterval = 0.15
    public static let overlay: TimeInterval = 0.20
    public static let drawer: TimeInterval = 0.25
    public static let nowPlayingMorph: TimeInterval = 0.32
    public static let collectionDeckSnap: TimeInterval = 0.22
    public static let collectionListTransition: TimeInterval = 0.29
    public static let collectionCardActivation: TimeInterval = 0.30

    public static func hoverAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: hover)
    }

    public static func morphAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: nowPlayingMorph)
    }

    public static func drawerAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: drawer)
    }

    public static func overlayAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: overlay)
    }

    public static func collectionDeckAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: collectionDeckSnap)
    }

    public static func collectionListAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: collectionListTransition)
    }

    public static func collectionCardAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: collectionCardActivation)
    }

    public static func pressAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.72)
    }
}
