import SwiftUI
import SwiftData
import AVFoundation
import os

struct TestApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Running Tests...")
        }
    }
}

@main
struct AppLauncher {
    static func main() {
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
            || ProcessInfo.processInfo.environment["XCInjectBundleInto"] != nil
            || ProcessInfo.processInfo.arguments.contains(where: { $0.contains("XCTest") || $0.contains("xctest") })
            || NSClassFromString("XCTestCase") != nil
        if isRunningTests {
            TestApp.main()
        } else {
            PublicYouTubeApp.main()
        }
    }
}

struct MusesApp: App {
    @Environment(\.scenePhase) private var scenePhase
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
    private let audioSessionCoordinator: AudioSessionCoordinator
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
        self.audioSessionCoordinator = composition.audioSessionCoordinator
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
                .frame(minWidth: 360, minHeight: 520)
                .task {
                    await updateService.checkIfDue()
                    watchSession.publishIfNeeded()
                    Self.purgeDefaultSeedDataIfNeeded(container: container)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        playback.queue.flush()
                    }
                }
        }
    }
}


extension MusesApp {
    /// Clears any preloaded/debug seed playlist and tracks so default state is empty.
    @MainActor
    static func purgeDefaultSeedDataIfNeeded(container: ModelContainer) {
        let defaults = UserDefaults.standard
        let purgeKey = "muses.debug.purgeSeedDataDone.v2"
        guard !defaults.bool(forKey: purgeKey) else { return }

        let context = ModelContext(container)
        let log = AppLog.for("DebugPurge")

        do {
            let importDescriptor = FetchDescriptor<YouTubeImport>()
            let allImports = (try? context.fetch(importDescriptor)) ?? []
            for imp in allImports {
                if imp.playlistId == "PLVRppllwHcDw" || imp.title == "test" || imp.url.contains("PLVRppllwHcDw") {
                    for item in imp.items ?? [] {
                        if let t = item.track {
                            context.delete(t)
                        }
                        context.delete(item)
                    }
                    context.delete(imp)
                    log.info("Purged debug seed import \(imp.title, privacy: .public)")
                }
            }

            try? context.save()
            defaults.set(true, forKey: purgeKey)
            defaults.set(true, forKey: "muses.debug.seedPlaylistDone")
            NotificationCenter.default.post(name: .musesPlaylistsChanged, object: nil)
        }
    }
}
