import Foundation
import SwiftData
import AVFoundation

/// Production service graph for Muses (Erato).
///
/// Extracted so unit tests can construct the same wiring as `MusesApp` without
/// seeding demo tracks or depending on macOS WebHome helpers.
@MainActor
struct AppComposition {
    let modelContainer: ModelContainer
    let playback: PlaybackService
    let queue: QueueService
    let library: LibraryService
    let playlist: PlaylistService
    let inbox: InboxService
    let focus: FocusService
    let sleepTimer: SleepTimerService
    let history: HistoryService
    let notes: NotesService
    let context: ContextService
    let lyrics: LyricsService
    let homeDiscovery: HomeDiscoveryService
    let situational: SituationalRecommendationService
    let youTubeAccount: YouTubeAccountService
    let youTubeImport: YouTubeImportService
    let youTubeSearch: YouTubeSearchService
    let youTubePlaylistSync: YouTubePlaylistSyncService
    let nowPlayingManager: NowPlayingManager
    let youTubeMusicSession: YouTubeMusicAccountSession
    let homeProviderHasWebEnhancement: Bool

    /// Registers feature-flag / WebHome defaults (first-run only; never overwrites user choices).
    static func registerPreferenceDefaults() {
        UserDefaults.standard.register(defaults: FeatureFlagDefaults.enabledByDefault as [String: Any])
        UserDefaults.standard.register(defaults: WebHomePreferenceDefaults.values)
        UserDefaults.standard.register(defaults: [
            PrefKey.homeRecommendationMode: HomeRecommendationMode.muses.rawValue
        ])
    }

    /// Builds the iOS production graph. Empty `playback.state.track` is intentional — no sample track.
    static func make(modelContainer: ModelContainer, configureAudioSession: Bool = true) -> AppComposition {
        registerPreferenceDefaults()

        if configureAudioSession {
            #if os(iOS)
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [])
                try session.setActive(true)
            } catch {
                print("Failed to initialize AVAudioSession: \(error)")
            }
            #endif
        }

        let engine = YouTubeStreamEngine()
        let queue = QueueService()
        queue.modelContext = ModelContext(modelContainer)
        queue.restore()

        let library = LibraryService(modelContainer: modelContainer)
        let playback = PlaybackService(engine: engine, queue: queue, library: library)

        let playlist = PlaylistService(modelContainer: modelContainer)
        let inbox = InboxService(modelContainer: modelContainer, eventBus: playback.eventBus)
        let focus = FocusService(
            modelContainer: modelContainer,
            eventBus: playback.eventBus,
            playback: playback
        )
        let sleepTimer = SleepTimerService(playbackService: playback)
        let context = ContextService()
        let history = HistoryService(
            modelContainer: modelContainer,
            eventBus: playback.eventBus,
            contextProvider: { context.capture() }
        )
        let notes = NotesService(modelContainer: modelContainer)
        let lyrics = LyricsService(modelContainer: modelContainer)

        let bridge = YouTubeResolver.shared
        // Dual Home modes: Muses (local library) vs YouTube Music (Innertube browse).
        // No macOS WebHome helper / cookie extraction on the default path.
        let oauthSession = GoogleOAuthSession(keychain: KeychainStore())
        let account = YouTubeAccountService(session: oauthSession)
        let innertube = InnertubeClient()
        let youTubeMusicSession = YouTubeMusicAccountSession(oauth: oauthSession, innertube: innertube)

        let youTubeImport = YouTubeImportService(bridge: bridge, modelContainer: modelContainer)
        let youTubeSearch = YouTubeSearchService(bridge: bridge, modelContainer: modelContainer)
        let youTubePlaylistSync = YouTubePlaylistSyncService(
            modelContainer: modelContainer,
            account: account
        )
        let nowPlayingManager = NowPlayingManager(playback, library: library, queue: queue)

        let musesHome = MusesHomeProvider(library: library)
        let ytmHome = YouTubeMusicHomeProvider(client: innertube, accountSession: youTubeMusicSession)
        let homeProvider = ModeSwitchingHomeProvider(muses: musesHome, youtubeMusic: ytmHome)
        assert(homeProvider.hasWebEnhancement == false)

        let homeDiscovery = HomeDiscoveryService(
            provider: homeProvider,
            library: library,
            historyService: history
        )
        let situational = SituationalRecommendationService(
            library: library,
            historyService: history,
            contextService: context,
            focusService: focus,
            inboxService: inbox,
            modelContainer: modelContainer
        )

        return AppComposition(
            modelContainer: modelContainer,
            playback: playback,
            queue: queue,
            library: library,
            playlist: playlist,
            inbox: inbox,
            focus: focus,
            sleepTimer: sleepTimer,
            history: history,
            notes: notes,
            context: context,
            lyrics: lyrics,
            homeDiscovery: homeDiscovery,
            situational: situational,
            youTubeAccount: account,
            youTubeImport: youTubeImport,
            youTubeSearch: youTubeSearch,
            youTubePlaylistSync: youTubePlaylistSync,
            nowPlayingManager: nowPlayingManager,
            youTubeMusicSession: youTubeMusicSession,
            homeProviderHasWebEnhancement: homeProvider.hasWebEnhancement
        )
    }

    /// In-memory graph for unit tests (skips AVAudioSession).
    static func makeForTesting() throws -> AppComposition {
        let container = try makeModelContainer(inMemory: true)
        return make(modelContainer: container, configureAudioSession: false)
    }
}
