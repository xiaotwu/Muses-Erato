import Foundation

/// Routes Home discovery to Muses (local) or YouTube Music (Innertube) by preference.
@MainActor
final class ModeSwitchingHomeProvider: HomeDiscoveryProvider {
    private let muses: HomeDiscoveryProvider
    private let youtubeMusic: HomeDiscoveryProvider
    private let modeProvider: () -> HomeRecommendationMode

    init(
        muses: HomeDiscoveryProvider,
        youtubeMusic: HomeDiscoveryProvider,
        modeProvider: @escaping () -> HomeRecommendationMode = { .current }
    ) {
        self.muses = muses
        self.youtubeMusic = youtubeMusic
        self.modeProvider = modeProvider
    }

    var hasWebEnhancement: Bool {
        active.hasWebEnhancement
    }

    func fetch(for input: HomeDiscoveryInput) async -> HomeFetchResult {
        await provider(for: input.mode).fetch(for: input)
    }

    func more(page: Int, input: HomeDiscoveryInput) async -> [HomeSection] {
        await provider(for: input.mode).more(page: page, input: input)
    }

    private var active: HomeDiscoveryProvider {
        provider(for: modeProvider())
    }

    private func provider(for mode: HomeRecommendationMode) -> HomeDiscoveryProvider {
        switch mode {
        case .muses:
            return muses
        case .youtubeMusic:
            return youtubeMusic
        }
    }
}
