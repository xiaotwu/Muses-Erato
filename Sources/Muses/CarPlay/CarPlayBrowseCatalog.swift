import Foundation

/// CarPlay list caps. Tab lists stay short for driving; pushed playlist pages may be longer.
enum CarPlayBrowseLimits {
    static let tabItems = 12
    static let pushedItems = 50
}

struct CarPlayTrackItem: Equatable, Sendable, Identifiable {
    let id: UUID
    let title: String
    let artist: String
    let youTubeId: String
}

struct CarPlayPlaylistSummary: Equatable, Sendable, Identifiable {
    let id: UUID
    let title: String
    let trackCount: Int
}

struct CarPlayBrowseCatalog: Equatable, Sendable {
    var recentlyPlayed: [CarPlayTrackItem]
    var playlists: [CarPlayPlaylistSummary]
    var favorites: [CarPlayTrackItem]
}

enum CarPlayBrowseCatalogBuilder {
    static func make(
        recentlyPlayed: [TrackSnapshot],
        playlists: [CarPlayPlaylistSummary],
        favorites: [TrackSnapshot]
    ) -> CarPlayBrowseCatalog {
        CarPlayBrowseCatalog(
            recentlyPlayed: Array(recentlyPlayed.compactMap(Self.item(from:)).prefix(CarPlayBrowseLimits.tabItems)),
            playlists: Array(playlists.prefix(CarPlayBrowseLimits.tabItems)),
            favorites: Array(favorites.compactMap(Self.item(from:)).prefix(CarPlayBrowseLimits.tabItems))
        )
    }

    static func playlistPage(_ tracks: [TrackSnapshot]) -> [CarPlayTrackItem] {
        Array(tracks.compactMap(Self.item(from:)).prefix(CarPlayBrowseLimits.pushedItems))
    }

    static func item(from track: TrackSnapshot) -> CarPlayTrackItem? {
        guard !track.youTubeId.isEmpty else { return nil }
        return CarPlayTrackItem(
            id: track.id,
            title: track.title,
            artist: track.artist,
            youTubeId: track.youTubeId
        )
    }
}

enum CarPlayPlayRequest: Equatable {
    case play(start: TrackSnapshot, context: [TrackSnapshot], source: QueueSource)
}

enum CarPlayPlaybackRouter {
    static func recently(_ track: TrackSnapshot, in list: [TrackSnapshot]) -> CarPlayPlayRequest {
        .play(start: track, context: list, source: .recently)
    }

    static func favorites(_ track: TrackSnapshot, in list: [TrackSnapshot]) -> CarPlayPlayRequest {
        .play(start: track, context: list, source: .songs)
    }

    static func playlist(_ track: TrackSnapshot, in list: [TrackSnapshot]) -> CarPlayPlayRequest {
        .play(start: track, context: list, source: .playlist)
    }
}
