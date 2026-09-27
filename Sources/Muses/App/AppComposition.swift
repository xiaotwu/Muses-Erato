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
    let audioSessionCoordinator: AudioSessionCoordinator

    /// Registers feature-flag / WebHome defaults (first-run only; never overwrites user choices).
    static func registerPreferenceDefaults() {
        UserDefaults.standard.register(defaults: FeatureFlagDefaults.enabledByDefault as [String: Any])
        UserDefaults.standard.register(defaults: WebHomePreferenceDefaults.values)
        UserDefaults.standard.register(defaults: [
            PrefKey.homeRecommendationMode: HomeRecommendationMode.youtubeMusic.rawValue,
            PrefKey.lyricsIntelligence: true
        ])
    }

    /// Builds the iOS production graph. Empty `playback.state.track` is intentional — no sample track.
    static func make(
        modelContainer: ModelContainer,
        configureAudioSession: Bool = true,
        engine: (any PlayerEngine)? = nil
    ) -> AppComposition {
        registerPreferenceDefaults()

        let engine = engine ?? YouTubeStreamEngine()
        let queue = QueueService()
        queue.modelContext = modelContainer.mainContext
        queue.restore()

        let library = LibraryService(modelContainer: modelContainer)
        let playback = PlaybackService(engine: engine, queue: queue, library: library)

        let audioSessionCoordinator = AudioSessionCoordinator(
            playbackService: playback,
            engine: engine,
            configureAudioSession: configureAudioSession
        )

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
        let innertube = bridge.sharedInnertube
        let youTubeMusicSession = YouTubeMusicAccountSession(oauth: oauthSession, innertube: innertube)
        Task { await youTubeMusicSession.syncAuthentication() }

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
            homeProviderHasWebEnhancement: homeProvider.hasWebEnhancement,
            audioSessionCoordinator: audioSessionCoordinator
        )
    }

    /// In-memory graph for unit tests (skips AVAudioSession and hardware audio engine).
    static func makeForTesting(engine: (any PlayerEngine)? = nil) throws -> AppComposition {
        let container = try makeModelContainer(inMemory: true)
        return make(modelContainer: container, configureAudioSession: false, engine: engine ?? NullPlayerEngine())
    }
}

/// Lightweight null player engine for test and headless environments.
@MainActor
final class NullPlayerEngine: PlayerEngine {
    let state = PlayerState()
    var onCompletion: (@MainActor () -> Void)?
    func load(_ track: TrackSnapshot) async throws {
        state.buffering = false
        state.isPlaying = true
    }
    func prepare(_ track: TrackSnapshot) async {}
    func playPrepared() -> Bool { false }
    func play() { state.isPlaying = true }
    func pause() { state.isPlaying = false }
    func toggle() { state.isPlaying.toggle() }
    func seek(to time: Double) { state.position = time }
    func setVolume(_ v: Float) {}
    func setEQ(_ bands: [EQBand]) {}
    var isEQAvailable: Bool { true }
    func installSpectrumTap(_ handler: @escaping (SpectrumFrame) -> Void) {}
    func removeSpectrumTap() {}
}
