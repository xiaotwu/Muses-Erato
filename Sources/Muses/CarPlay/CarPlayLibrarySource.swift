import Foundation

/// Reads the local library for CarPlay. No search, no remote catalogs.
@MainActor
struct CarPlayLibrarySource {
    let library: LibraryService
    let playlists: PlaylistService

    func catalog() -> CarPlayBrowseCatalog {
        let playlistSummaries = playlists.fetchAll().map { playlist in
            let count = (playlist.items ?? [])
                .compactMap(\.track)
                .filter { !$0.youTubeId.isEmpty }
                .count
            return CarPlayPlaylistSummary(id: playlist.id, title: playlist.name, trackCount: count)
        }
        return CarPlayBrowseCatalogBuilder.make(
            recentlyPlayed: library.recentlyPlayedTracks(limit: CarPlayBrowseLimits.tabItems),
            playlists: playlistSummaries,
            favorites: library.likedTracks().map(TrackSnapshot.init(from:))
        )
    }

    func playlistTracks(id: UUID) -> [TrackSnapshot] {
        playlists.snapshots(for: id, limit: CarPlayBrowseLimits.pushedItems)
    }

    func recentlyPlayed() -> [TrackSnapshot] {
        library.recentlyPlayedTracks(limit: CarPlayBrowseLimits.tabItems)
    }

    func favorites() -> [TrackSnapshot] {
        Array(library.likedTracks().prefix(CarPlayBrowseLimits.tabItems)).map(TrackSnapshot.init(from:))
    }
}
