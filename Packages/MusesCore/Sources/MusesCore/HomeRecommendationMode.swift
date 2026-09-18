import Foundation

/// Which recommendation source powers Home. Shared across Apple platforms.
public enum HomeRecommendationMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case muses
    case youtubeMusic

    public var id: String { rawValue }

    public var titleEnglish: String {
        switch self {
        case .muses: return "Muses"
        case .youtubeMusic: return "YouTube Music"
        }
    }
}
