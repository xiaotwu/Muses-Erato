import MusesCore
import Foundation

/// YouTube Music world-catalog URLs and Innertube browse ids for discovery.
enum YouTubeMusicCatalog {
    static let charts = "https://music.youtube.com/charts"
    static let newReleases = "https://music.youtube.com/new_releases"
    static let moods = "https://music.youtube.com/moods"

    /// Innertube `browseId` values (WEB_REMIX) — preferred over scraping Music URLs.
    enum BrowseID {
        static let home = YouTubeMusicBrowseIDs.home
        static let charts = YouTubeMusicBrowseIDs.charts
        static let newReleases = YouTubeMusicBrowseIDs.newReleases
        static let moodsAndGenres = YouTubeMusicBrowseIDs.moodsAndGenres
    }

    static func mix(videoId: String) -> String {
        "https://www.youtube.com/watch?v=\(videoId)&list=RD\(videoId)"
    }
}
