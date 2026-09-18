import Foundation

/// YouTube Music world-catalog URLs and Innertube browse ids for discovery.
enum YouTubeMusicCatalog {
    static let charts = "https://music.youtube.com/charts"
    static let newReleases = "https://music.youtube.com/new_releases"
    static let moods = "https://music.youtube.com/moods"

    /// Innertube `browseId` values (WEB_REMIX) — preferred over scraping Music URLs.
    enum BrowseID {
        static let home = "FEmusic_home"
        static let charts = "FEcharts"
        static let newReleases = "FEmusic_new_releases"
        static let moodsAndGenres = "FEmusic_moods_and_genres"
    }

    static func mix(videoId: String) -> String {
        "https://www.youtube.com/watch?v=\(videoId)&list=RD\(videoId)"
    }
}
