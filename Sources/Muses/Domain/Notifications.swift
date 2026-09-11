import Foundation

public extension Notification.Name {
    static let musesSelectPlaylist = Notification.Name("muses.selectPlaylist")
    static let musesPlaylistsChanged = Notification.Name("muses.playlistsChanged")
    static let musesToggleQueue = Notification.Name("muses.toggleQueue")
    static let musesToggleNowPlaying = Notification.Name("muses.toggleNowPlaying")
    static let musesFocusSearch = Notification.Name("muses.focusSearch")
    static let musesNavigateFromSearch = Notification.Name("muses.navigateFromSearch")
    static let musesNavigateToRelease = Notification.Name("muses.navigateToRelease")
    static let musesNavigateToArtist = Notification.Name("muses.navigateToArtist")
    static let musesNavigateYouTubeImport = Notification.Name("muses.navigateYouTubeImport")
    static let musesCloseYouTubeAlbum = Notification.Name("muses.closeYouTubeAlbum")
    static let musesShowPlaylistsOverview = Notification.Name("muses.showPlaylistsOverview")
    static let musesOpenSettings = Notification.Name("muses.openSettings")
    static let musesOpenMiniPlayer = Notification.Name("muses.openMiniPlayer")
    static let musesToggleDesktopLyrics = Notification.Name("muses.toggleDesktopLyrics")
    static let musesDesktopFlagsChanged = Notification.Name("muses.desktopFlagsChanged")
    static let musesToggleFocusMode = Notification.Name("muses.toggleFocusMode")
    static let musesToggleAudioInfo = Notification.Name("muses.toggleAudioInfo")
    static let musesRestorePlayerArtworkFocus = Notification.Name("muses.restorePlayerArtworkFocus")
}
