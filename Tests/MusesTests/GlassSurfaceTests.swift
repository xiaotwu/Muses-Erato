import Testing
@testable import Muses

/// Pure-logic tests for Liquid Glass presentation decisions (GlassMode.mode).
@MainActor
struct GlassSurfaceTests {
    @Test("Accessibility off + supportsGlass -> .glass")
    func glassWhenSupported() {
        #expect(GlassMode.mode(reduceTransparency: false, increaseContrast: false, supportsGlass: true) == .glass)
    }

    @Test("Accessibility off + older system -> .material")
    func materialFallback() {
        #expect(GlassMode.mode(reduceTransparency: false, increaseContrast: false, supportsGlass: false) == .material)
    }

    @Test("Reduce transparency -> .opaque regardless of glass support")
    func reduceTransparencyOverrides() {
        #expect(GlassMode.mode(reduceTransparency: true, increaseContrast: false, supportsGlass: true) == .opaque)
        #expect(GlassMode.mode(reduceTransparency: true, increaseContrast: false, supportsGlass: false) == .opaque)
    }

    @Test("Increase contrast -> .opaque regardless of glass support")
    func increaseContrastOverrides() {
        #expect(GlassMode.mode(reduceTransparency: false, increaseContrast: true, supportsGlass: true) == .opaque)
        #expect(GlassMode.mode(reduceTransparency: false, increaseContrast: true, supportsGlass: false) == .opaque)
    }

    @Test("Both accessibility flags -> .opaque")
    func bothAccessibilityFlags() {
        #expect(GlassMode.mode(reduceTransparency: true, increaseContrast: true, supportsGlass: true) == .opaque)
    }

    @Test("Interactive roles match chrome contract")
    func interactiveRoles() {
        #expect(MusesGlassRole.floatingPlayer.isInteractive)
        #expect(MusesGlassRole.compactControl.isInteractive)
        #expect(MusesGlassRole.modalDeck.isInteractive)
        #expect(!MusesGlassRole.navigationBar.isInteractive)
        #expect(!MusesGlassRole.tabBar.isInteractive)
    }

    @Test("Press scale matches liqui.design guidance")
    func pressScale() {
        #expect(MusesMotion.pressScale == 0.97)
        #expect(AppleMusicSpacing.hitTarget >= 44)
    }
}
