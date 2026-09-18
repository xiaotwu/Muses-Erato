import Foundation

/// Which recommendation source powers Home.
enum HomeRecommendationMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case muses
    case youtubeMusic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .muses:
            return tr("Muses", "Muses")
        case .youtubeMusic:
            return tr("YouTube Music", "YouTube Music")
        }
    }

    var subtitle: String {
        switch self {
        case .muses:
            return tr(
                "Recommendations are generated on this iPhone from your library and listening activity.",
                "推荐仅根据本机资料库与收听记录生成。"
            )
        case .youtubeMusic:
            return tr(
                "Recommendations come from YouTube Music via Innertube. When signed in, YouTube may associate requests with your account.",
                "推荐来自 YouTube Music（Innertube）。登录后，YouTube 可能把请求与你的账号关联。"
            )
        }
    }

    static var current: HomeRecommendationMode {
        let raw = UserDefaults.standard.string(forKey: PrefKey.homeRecommendationMode) ?? HomeRecommendationMode.muses.rawValue
        return HomeRecommendationMode(rawValue: raw) ?? .muses
    }

    static func setCurrent(_ mode: HomeRecommendationMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: PrefKey.homeRecommendationMode)
    }
}
