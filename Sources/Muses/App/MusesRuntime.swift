import Foundation

/// Shared composition root so the CarPlay scene can reach the same playback facade as the iPhone UI.
@MainActor
enum MusesRuntime {
    static var playback: PlaybackService?
    static var library: LibraryService?
    static var playlists: PlaylistService?

    static func bind(
        playback: PlaybackService,
        library: LibraryService,
        playlists: PlaylistService
    ) {
        self.playback = playback
        self.library = library
        self.playlists = playlists
    }
}
