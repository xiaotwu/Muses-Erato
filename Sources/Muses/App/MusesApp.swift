import SwiftUI
import SwiftData
import AVFoundation
import os

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
                    #if DEBUG
                    await Self.runDebugPlaylistSeedIfNeeded(
                        importService: youTubeImportService,
                        playback: playback,
                        container: container
                    )
                    #endif
                }
        }
    }
}


#if DEBUG
extension MusesApp {
    /// DEBUG-only: UserDefaults `muses.debug.seedPlaylistURL` (String) + `muses.debug.seedPlaylistDone` (Bool).
    /// Optional `muses.debug.autoPlaySeed` (Bool, default false) plays the first imported track once.
    @MainActor
    static func runDebugPlaylistSeedIfNeeded(
        importService: YouTubeImportService,
        playback: PlaybackService,
        container: ModelContainer
    ) async {
        let defaults = UserDefaults.standard
        let urlKey = "muses.debug.seedPlaylistURL"
        let doneKey = "muses.debug.seedPlaylistDone"
        let autoPlayKey = "muses.debug.autoPlaySeed"
        let log = AppLog.for("DebugPlaylistSeed")

        guard let url = defaults.string(forKey: urlKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !url.isEmpty else { return }
        if defaults.bool(forKey: doneKey) {
            log.info("Seed already done; skip \(url, privacy: .public)")
            if defaults.bool(forKey: autoPlayKey) {
                await playFirstLibraryTrackIfPossible(playback: playback, container: container, log: log)
            }
            return
        }

        do {
            let importID: UUID
            if let preloaded = Self.loadDebugSeedPlaylistJSON() {
                let entries = preloaded.entries.map {
                    YTDlpBridge.YTDlpPlaylistEntry(
                        id: $0.id,
                        title: $0.title,
                        uploader: $0.uploader,
                        duration: $0.duration,
                        playlistTitle: preloaded.title
                    )
                }
                importID = try await importService.importPreloadedPlaylist(
                    playlistId: preloaded.playlistId,
                    url: preloaded.url,
                    title: preloaded.title,
                    channel: preloaded.channel,
                    entries: entries
                )
                log.info("Seeded from JSON \(preloaded.playlistId, privacy: .public) → \(importID.uuidString, privacy: .public)")
            } else {
                importID = try await importService.importPlaylist(url: url)
                log.info("Seeded playlist \(url, privacy: .public) → \(importID.uuidString, privacy: .public)")
            }
            defaults.set(true, forKey: doneKey)

            guard defaults.bool(forKey: autoPlayKey) else { return }
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<YouTubeImport>(
                predicate: #Predicate { $0.id == importID }
            )
            guard let imported = try context.fetch(descriptor).first else {
                log.error("Seed import row missing after success")
                return
            }
            let snaps = (imported.items ?? [])
                .sorted { $0.order < $1.order }
                .compactMap(\.track)
                .filter { !$0.youTubeId.isEmpty }
                .map(TrackSnapshot.init(from:))
            let preferred = snaps.first(where: { $0.title.contains("威風") || $0.title.contains("威风") })
            guard let first = preferred ?? snaps.first else {
                log.error("Seed import has no playable tracks")
                return
            }
            playback.playTrack(first, context: snaps, from: .import)
            log.info("Auto-played seed track \(first.title, privacy: .public)")
        } catch {
            log.error("Seed import failed: \(error.localizedDescription, privacy: .public)")
            // Fallback: play first already-imported library track when re-import fails.
            if defaults.bool(forKey: autoPlayKey) {
                await playFirstLibraryTrackIfPossible(playback: playback, container: container, log: log)
            }
        }
    }


    private struct DebugSeedPlaylistFile: Decodable {
        let playlistId: String
        let url: String
        let title: String
        let channel: String
        let entries: [DebugSeedEntry]
    }

    private struct DebugSeedEntry: Decodable {
        let id: String
        let title: String
        let uploader: String?
        let duration: Double?
    }

    @MainActor
    private static func loadDebugSeedPlaylistJSON() -> DebugSeedPlaylistFile? {
        let urls = [
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
                .appendingPathComponent("muses-debug-seed.json"),
            Bundle.main.url(forResource: "muses-debug-seed", withExtension: "json")
        ].compactMap { $0 }
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode(DebugSeedPlaylistFile.self, from: data),
                  !decoded.entries.isEmpty else { continue }
            return decoded
        }
        return nil
    }

    @MainActor
    static func playFirstLibraryTrackIfPossible(
        playback: PlaybackService,
        container: ModelContainer,
        log: Logger
    ) async {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Track>(sortBy: [SortDescriptor(\Track.addedAt, order: .reverse)])
        descriptor.fetchLimit = 600
        guard let tracks = try? context.fetch(descriptor), !tracks.isEmpty else {
            log.error("No library tracks available to auto-play")
            return
        }
        let snaps = tracks
            .filter { !$0.youTubeId.isEmpty }
            .map(TrackSnapshot.init(from:))
        let preferred = snaps.first(where: { $0.title.contains("威風") || $0.title.contains("威风") })
        guard let first = preferred ?? snaps.first else {
            log.error("Library tracks lack YouTube ids")
            return
        }
        playback.playTrack(first, context: snaps, from: .songs)
        log.info("Auto-played library track \(first.title, privacy: .public) id=\(first.youTubeId, privacy: .public)")
    }
}
#endif
