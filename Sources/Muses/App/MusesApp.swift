import SwiftUI
import SwiftData
import AVFoundation

@main
struct MusesApp: App {
    private let container: ModelContainer
    @State private var playback: PlaybackService
    private let libraryService: LibraryService
    private let playlistService: PlaylistService
    private let inboxService: InboxService
    private let focusService: FocusService
    private let sleepTimerService: SleepTimerService
    private let historyService: HistoryService
    private let notesService: NotesService
    private let contextService: ContextService
    private let lyricsService: LyricsService
    private let homeDiscoveryService: HomeDiscoveryService
    private let situationalService: SituationalRecommendationService
    private let youTubeAccountService: YouTubeAccountService
    private let youTubeImportService: YouTubeImportService
    private let youTubeSearchService: YouTubeSearchService
    private let youTubePlaylistSyncService: YouTubePlaylistSyncService
    private let nowPlayingManager: NowPlayingManager
    private let nowPlayingSessionCoordinator: NowPlayingSessionCoordinator
    private let watchSession: PhoneWatchSession
    private let updateService: UpdateService

    init() {
        let storeResult = makeModelContainerWithFallback()
        let composition = AppComposition.make(modelContainer: storeResult.container)

        self.container = composition.modelContainer
        self._playback = State(initialValue: composition.playback)
        self.libraryService = composition.library
        self.playlistService = composition.playlist
        self.inboxService = composition.inbox
        self.focusService = composition.focus
        self.sleepTimerService = composition.sleepTimer
        self.historyService = composition.history
        self.notesService = composition.notes
        self.contextService = composition.context
        self.lyricsService = composition.lyrics
        self.homeDiscoveryService = composition.homeDiscovery
        self.situationalService = composition.situational
        self.youTubeAccountService = composition.youTubeAccount
        self.youTubeImportService = composition.youTubeImport
        self.youTubeSearchService = composition.youTubeSearch
        self.youTubePlaylistSyncService = composition.youTubePlaylistSync
        self.nowPlayingManager = composition.nowPlayingManager
        self.nowPlayingSessionCoordinator = NowPlayingSessionCoordinator(playback: composition.playback)
        self.watchSession = PhoneWatchSession(playback: composition.playback)
        self.updateService = UpdateService()

        MusesRuntime.bind(
            playback: composition.playback,
            library: composition.library,
            playlists: composition.playlist
        )
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(playback: playback)
                .modelContainer(container)
                .environment(playback)
                .environment(libraryService)
                .environment(playlistService)
                .environment(inboxService)
                .environment(focusService)
                .environment(sleepTimerService)
                .environment(historyService)
                .environment(notesService)
                .environment(contextService)
                .environment(lyricsService)
                .environment(homeDiscoveryService)
                .environment(situationalService)
                .environment(youTubeAccountService)
                .environment(youTubeImportService)
                .environment(youTubeSearchService)
                .environment(youTubePlaylistSyncService)
                .environment(updateService)
                .preferredColorScheme(.dark)
                .task {
                    await updateService.checkIfDue()
                    watchSession.publishIfNeeded()
                }
        }
    }
}
