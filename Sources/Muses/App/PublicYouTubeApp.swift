import SwiftUI
import SwiftData
import UIKit
import MusesDomain
import MusesQueue
import MusesPersistence
import MusesCatalog
import MusesNetworking
import MusesIOSOAuth

/// Shared composition root: Release uses the visible player; Debug/Native can opt into native audio.
/// The inherited macOS services are not constructed here.
@MainActor
struct PublicYouTubeApp: App {
    var body: some Scene {
        WindowGroup {
            PublicPrivacyGate { PublicConsentedAppView() }
        }
    }
}

private struct PublicConsentedAppView: View {
    @State private var session = PublicYouTubeSession()
    var body: some View {
        PublicRootView(session: session)
            .modifier(PublicMigrationArchivePresentation(session: session))
    }
}

@main
struct PublicAppLauncher {
    static func main() {
        // AsyncImage uses the shared Foundation cache; do not retain Google artwork on disk.
        URLCache.shared.removeAllCachedResponses()
        URLCache.shared = URLCache(memoryCapacity: 16 * 1024 * 1024, diskCapacity: 0, diskPath: nil)
        #if DEBUG
        // Hosted XCTest needs a minimal SwiftUI scene while its bundle starts.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil {
            PublicTestHostApp.main()
            return
        }
        #endif
        PublicYouTubeApp.main()
    }
}

#if DEBUG
private struct PublicTestHostApp: App {
    var body: some Scene { WindowGroup { Text("Running Tests") } }
}
#endif

@MainActor @Observable
final class PublicYouTubeSession {
    private var v1Container: ModelContainer?
    private(set) var repository: SwiftDataSnapshotRepository?
    private(set) var tracks: [MusesDomain.Track] = []
    private(set) var queue: PlaybackQueue = try! PlaybackQueue()
    private(set) var state = PlaybackSnapshot()
    private(set) var failureMessage: String?
    private(set) var recoveryMessage: String?
    private(set) var operationFailures: [PublicSessionOperation: String] = [:]
    var libraryError: String? { operationFailures[.library] }
    var playbackError: String? { operationFailures[.playback] }
    var accountError: String? { operationFailures[.account] }
    var metadataError: String? { operationFailures[.metadata] }
    var deletionError: String? { operationFailures[.deletion] }
    var queueFailureMessage: String? { operationFailures[.queue] }
    // Queue edits are initiated in both library and playback surfaces. Preserve the underlying
    // content/checkpoint/library errors while making the latest failed edit visible there.
    var libraryFailureMessage: String? { queueFailureMessage ?? libraryError }
    var playbackFailureMessage: String? { queueFailureMessage ?? playbackError }
    var accountFailureMessage: String? { accountError }
    var metadataFailureMessage: String? { metadataError }
    var deletionFailureMessage: String? { deletionError }
    var accountOperation: PublicOperationState {
        PublicOperationState(isRunning: activeSignIn != nil || signingOut,
            message: accountCleanupPending ? "Account cleanup is pending. Retry cleanup in Settings." : nil,
            error: accountError)
    }
    var metadataRefreshOperation: PublicOperationState {
        PublicOperationState(isRunning: refreshingMetadata || refreshingPlaylistNames || hydratingMetadata,
            message: playlistNameRefreshMessage, error: metadataError)
    }
    var localDataDeletionOperation: PublicOperationState {
        PublicOperationState(isRunning: cleanupInFlight,
            message: deletingLocalData ? recoveryMessage : nil, error: deletionError,
            pendingRestart: deletingLocalData && !cleanupInFlight || PublicStoreRouter.deletionNeedsRestart(destinationURL: destinationURL))
    }
    let playbackCheckpoint = PublicPlaybackCheckpointController()
    @ObservationIgnored lazy var playbackCommands: PublicPlaybackCommandController = {
        let controller = PublicPlaybackCommandController()
        controller.onFailure = { [weak self] request in
            guard let self, request.generation == self.adapterGeneration else { return }
            if request.action == .pause { self.adapter?.cancelPendingPause() }
        }
        return controller
    }()
    var isPlaybackCommandPending: Bool { playbackCommands.pending != nil }
    var playbackToggleLabel: String {
        if let pending = playbackCommands.pending { return pending.action == .play ? "Play requested" : "Pausing" }
        return state.state == .playing || state.state == .buffering ? "Pause" : "Play"
    }
    var canRetryPlaybackCommand: Bool {
        guard playbackCommands.retryAllowed, let failed = playbackCommands.failedRequest else { return false }
        return adapter != nil && adapterGeneration != 0 && failed.generation == adapterGeneration
    }
    private let checkpointNow: () -> Date
    private let beforeQueueSave: () throws -> Void

    private func report(_ message: String?, for operation: PublicSessionOperation) {
        operationFailures[operation] = message
        failureMessage = message // Compatibility for existing surfaces during UI integration.
    }
    let searchPages = CatalogPager()
    let subscriptionPages = CatalogPager()
    let accountPlaylistPages = CatalogPager()
    let accountChannelPages = CatalogPager()
    var searchKind: MusesCatalog.CatalogItem.Kind = .video
    private var submittedSearch = ""
    var submittedSearchQuery: String { submittedSearch }
    var submittedSearchKind: MusesCatalog.CatalogItem.Kind { submittedKind }
    var hasSubmittedSearch: Bool { !submittedSearch.isEmpty }
    var isSubmittedSearchLocal: Bool { submittedSearchIsLocal }
    private var submittedSearchIsLocal = false
    private var submittedKind: MusesCatalog.CatalogItem.Kind = .video
    private var linkGeneration = UUID()
    var catalogRoute: YouTubeCatalogLink?
    var searchItems: [MusesCatalog.CatalogItem] {
        let localIDs = Set(localSearchItems.map(\.rowID))
        return localSearchItems + searchPages.items.filter { !localIDs.contains($0.rowID) }
    }
    private var localSearchItems: [MusesCatalog.CatalogItem] = []
    private(set) var playedIDs: [TrackID] = []
    private(set) var playlists: [LocalPlaylist] = []
    private var refreshingPlaylistNames = false
    private var lastPlaylistNameAttempt: Date?
    private(set) var playlistNameRefreshMessage: String?
    var searchError: String? { searchPages.error }
    var searching: Bool { searchPages.loading }
    private(set) var signedIn = false
    private(set) var accountCleanupPending = false
    var subscriptions: [MusesCatalog.CatalogItem] { subscriptionPages.items }
    var showPlayer = false
    var nativePlaybackEnabled = false
    @ObservationIgnored lazy var nativePlayback: ExperimentalNativePlayback = {
        #if DEBUG && MUSES_NATIVE_PLAYBACK
        let fixture = ProcessInfo.processInfo.environment["MUSES_UI_TEST_LIBRARY"] != nil && ProcessInfo.processInfo.environment["MUSES_UI_TEST_CATALOG"] == "fixtures"
        let engine = ExperimentalNativePlayback { videoID in
            if fixture { return try PublicFixtureAudio.makeURL() }
            return try await ExperimentalNativePlayback.resolveLocalStream(videoID)
        }
        #else
        let engine = ExperimentalNativePlayback()
        #endif
        engine.onEvent = { [weak self] event in self?.receiveNative(event) }
        engine.onNext = { [weak self] in self?.next() }
        engine.onPrevious = { [weak self] in self?.previous() }
        return engine
    }()
    var selectedCategory: LibraryCategory = .videos
    private var adapter: YouTubeIFrameAdapter?
    private var adapterGeneration: UInt64 = 0
    private var contentCheck: Task<Void, Never>?
    private var contentCheckID = UUID()
    private var catalog: YouTubeDataCatalog?
    private var hasPublicAPIKey = false
    private var oauth: OAuthClient?
    private var oauthConfiguration: OAuthConfiguration?
    private var authorizationSession: IOSAuthorizationSession?
    private var activeSignIn: Task<Void, Error>?
    private var signingOut = false
    private var activeNetworkCalls = 0
    private var deletingLocalData = false
    private var cleanupInFlight = false
    private var accountEpoch: UInt64 = 0
    private var recordedEntryID: UUID?
    @ObservationIgnored lazy var notebook = PublicNotebookModel(repository: { [weak self] in self?.repository })
    @ObservationIgnored let bookmarkSeeking = PublicBookmarkSeekController()
    private(set) var hasCurrentPlaybackTime = false
    private(set) var bookmarkCueMilliseconds: Double?

    private let requestBudgetURL: URL
    private let destinationURL: URL
    private let legacyURL: URL
    private let defaults: UserDefaults
    private let defaultsDomain: String
    private let deleteCredentials: () throws -> Void
    private let deleteWebsiteData: () async throws -> Void
    var showMigrationArchive = false
    private(set) var hasMigrationArchive = false
    private(set) var successorIdentity: SuccessorIdentity?

    init(storeURL: URL? = nil, catalogOverride: YouTubeDataCatalog? = nil, defaults: UserDefaults = .standard,
         domainName: String = Bundle.main.bundleIdentifier ?? "com.xiaotwu.muses.erato",
         checkpointNow: @escaping () -> Date = Date.init,
         beforeQueueSave: @escaping () throws -> Void = {},
         deleteCredentials: @escaping () throws -> Void = PublicCredentialDeletion.deleteAppCredentials,
         deleteWebsiteData: @escaping () async throws -> Void = { try await PublicWebsiteDataDeletion.clear() }) {
        legacyURL = storeURL?.deletingLastPathComponent().appending(path: "muses-youtube-native.sqlite") ?? musesDefaultStoreURL()
        destinationURL = storeURL ?? legacyURL.deletingLastPathComponent().appending(path: "muses-public-v1.sqlite")
        let isolatedBudgetURL: URL?
        #if DEBUG
        if ProcessInfo.processInfo.environment["MUSES_UI_TEST_LIBRARY"].flatMap(UUID.init(uuidString:)) != nil {
            isolatedBudgetURL = legacyURL.deletingLastPathComponent().appending(path: "device-request-budget.json")
        } else { isolatedBudgetURL = nil }
        #else
        isolatedBudgetURL = nil
        #endif
        requestBudgetURL = storeURL.map { $0.deletingLastPathComponent().appending(path: "device-request-budget.json") }
            ?? isolatedBudgetURL
            ?? URL.applicationSupportDirectory.appending(path: "MusesDevice/device-request-budget.json")
        self.defaults = defaults
        self.checkpointNow = checkpointNow
        self.beforeQueueSave = beforeQueueSave
        nativePlaybackEnabled = ExperimentalNativePlayback.available && storeURL == nil && defaults.bool(forKey: "experimentalNativePlayback")
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || ProcessInfo.processInfo.environment["MUSES_UI_TEST_LIBRARY"] != nil {
            nativePlaybackEnabled = false
        }
        #endif
        defaultsDomain = domainName
        self.deleteCredentials = deleteCredentials
        self.deleteWebsiteData = deleteWebsiteData
        do {
            let selected = try PublicStoreRouter.resolve(legacyURL: legacyURL, destinationURL: destinationURL,
                defaults: defaults, domainName: domainName)
            try loadLibrary(at: selected)
            if PublicStoreRouter.deletionNeedsRestart(destinationURL: destinationURL) {
                failureMessage = "Library cleared. Restart Muses to finish removing retained migration files."
            }
            configureRemoteServices(catalogOverride: catalogOverride)
        } catch is PublicStoreRouter.ExternalDeletionPending {
            recoveryMessage = "Finishing local data deletion…"
            Task { [weak self] in await self?.finishRecordedDeletion() }

        } catch {
            repository = nil
            if FileManager.default.fileExists(atPath: destinationURL.appendingPathExtension("upgrade").appendingPathComponent("deleted.json").path) {
                recoveryMessage = "Local deletion could not finish. Retained data will not be reimported. Error: \(error.localizedDescription)"
            } else {
                recoveryMessage = "Library could not be opened. No replacement library was created. Error: \(error.localizedDescription)"
            }
        }
    }

    private func configureRemoteServices(catalogOverride: YouTubeDataCatalog? = nil) {
        catalog = nil
        oauth = nil
        oauthConfiguration = nil
        hasPublicAPIKey = false
        if let catalogOverride {
            catalog = catalogOverride; hasPublicAPIKey = true
            return
        }
        #if DEBUG
        if ProcessInfo.processInfo.environment["MUSES_UI_TEST_LIBRARY"] != nil,
           ProcessInfo.processInfo.environment["MUSES_UI_TEST_CATALOG"] == "fixtures" {
            catalog = YouTubeDataCatalog(apiKey: "ui-fixture", credential: PublicFixtureCredential(), transport: PublicCatalogFixtureTransport())
            hasPublicAPIKey = true; signedIn = true
            return
        }
        #endif
            let deviceBudget: RequestBudget
            do { deviceBudget = try PublicDeviceRequestBudgets.budget(at: requestBudgetURL) }
            catch {
                report("Device request usage could not be opened. Online requests are paused to preserve the daily limit. " + error.localizedDescription, for: .metadata)
                return
            }
            let key = Bundle.main.object(forInfoDictionaryKey: "MusesYouTubeAPIKey") as? String
            let apiKey = key.flatMap { !$0.isEmpty && !$0.hasPrefix("$(") ? $0 : nil }
            hasPublicAPIKey = apiKey != nil
            let client = Bundle.main.object(forInfoDictionaryKey: "MusesGoogleIOSClientID") as? String
            let scheme = Bundle.main.object(forInfoDictionaryKey: "MusesGoogleRedirectScheme") as? String
            if let client, let scheme, !scheme.hasPrefix("$("),
               let redirect = URL(string: "\(scheme):/oauth2redirect"),
               let config = try? OAuthConfiguration(clientID: client, redirectURI: redirect) {
                oauthConfiguration = config
                let privateData = PublicPrivateData()
                let auth = OAuthClient(configuration: config,
                    store: KeychainOAuthTokenStore(service: "com.xiaotwu.muses.erato.youtube"),
                    privateData: privateData,
                    cleanupJournal: FileOAuthCleanupJournal(url: destinationURL.appendingPathExtension("oauth-cleanup.json")))
                oauth = auth
                let remote = YouTubeDataCatalog(apiKey: apiKey, credential: auth,
                    budget: deviceBudget,
                    clientIdentity: Bundle.main.bundleIdentifier.flatMap { CatalogClientIdentity(iOSBundleID: $0) })
                catalog = remote
                Task { await privateData.setCatalog(remote) }
                let epoch = accountEpoch
                Task { [weak self] in
                    guard let self, !self.deletingLocalData else { return }
                    self.activeNetworkCalls += 1
                    defer { self.activeNetworkCalls -= 1 }
                    do {
                        if try await auth.resumePendingCleanup() {
                            guard self.accountEpoch == epoch else { return }
                            self.accountCleanupPending = false
                            return
                        }
                        _ = try await auth.accessToken()
                        guard self.accountEpoch == epoch else { return }
                        self.signedIn = true
                    } catch {
                        guard self.accountEpoch == epoch else { return }
                        let pending = (try? await auth.hasPendingCleanup()) ?? true
                        guard self.accountEpoch == epoch else { return }
                        self.accountCleanupPending = pending
                        if pending {
                            self.report("Account cleanup is pending. Unlock this device and retry account cleanup in Settings.", for: .account)
                        }
                    }
                }
            } else if let apiKey {
                catalog = YouTubeDataCatalog(apiKey: apiKey,
                    budget: deviceBudget,
                    clientIdentity: Bundle.main.bundleIdentifier.flatMap { CatalogClientIdentity(iOSBundleID: $0) })
            }
    }

    private func loadLibrary(at url: URL) throws {
        let container = try SwiftDataSnapshotRepository.container(url: url)
        let repo = SwiftDataSnapshotRepository(context: container.mainContext)
        let snapshot = try PublicLibrarySnapshot(repository: repo)
        v1Container = container
        repository = repo
        tracks = snapshot.tracks
        try expireCatalogMetadata()
        playedIDs = snapshot.history.sorted { $0.date > $1.date }.map(\.trackID)
        playlists = snapshot.playlists
        queue = try PlaybackQueue(snapshot: snapshot.queue)
        successorIdentity = try repo.get(SuccessorIdentity.self, kind: .migration, id: "runnable-successor-v1")
        hasMigrationArchive = try repo.get(LegacyMigrationReceipt.self, kind: .migration, id: "legacy-complete-v1") != nil
        if let current = queue.snapshot.current {
            state = PlaybackSnapshot(state: .paused, source: current.source,
                generation: queue.snapshot.generation, intent: .pause, positionMilliseconds: queue.snapshot.positionMilliseconds)
        }
    }

    func restoreOriginalPlaylist(_ id: UUID) {
        do {
            guard let repository else { return }
            _ = try repository.restoreOriginalPlaylist(id)
            playlists = try repository.localPlaylists()
            tracks = try repository.list(MusesDomain.Track.self, kind: .track)
        } catch { failureMessage = "Could not restore playlist: \(error.localizedDescription)" }
    }

    var currentTrack: MusesDomain.Track? {
        guard let entry = queue.snapshot.current else { return nil }
        return tracks.first { $0.id == entry.trackID }
    }
    private var libraryProjection: PublicLibraryProjection { PublicLibraryProjection(savedTracks: tracks, playedIDs: playedIDs) }
    var history: [MusesDomain.Track] { libraryProjection.history }
    var favorites: [MusesDomain.Track] { libraryProjection.favorites }
    var libraryTracks: [MusesDomain.Track] { libraryProjection.tracks }
    var libraryFavorites: [MusesDomain.Track] { libraryProjection.favorites }
    var libraryHistory: [MusesDomain.Track] { libraryProjection.history }

    var apiConfigured: Bool { catalog != nil && (hasPublicAPIKey || signedIn) }
    var oauthConfigured: Bool { oauth != nil }
    var hasNext: Bool { !queue.snapshot.upcoming.isEmpty }
    var isPlayerVisible: Bool { adapter != nil || (nativePlaybackEnabled && showPlayer) }

    func search(_ input: String) async {
        guard !deletingLocalData else { return }
        activeNetworkCalls += 1
        defer { activeNetworkCalls -= 1 }
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if query == submittedSearch, submittedKind == searchKind, searchPages.loading { return }
        submittedSearchIsLocal = false
        submittedSearch = query; submittedKind = searchKind
        searchPages.reset()
        localSearchItems = searchKind == .video ? tracks.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.artist.localizedCaseInsensitiveContains(query) }
            .compactMap { track in
                guard case .youtubeVideo(let id) = track.source else { return nil }
                return MusesCatalog.CatalogItem(kind: .video, id: id.rawValue, title: track.title,
                    channelID: nil, thumbnailURL: nil, source: "local")
            } : []
        guard !query.isEmpty else { localSearchItems = []; return }
        await nextSearchPage()
    }

    /// Searches saved references only; no catalog or account request is made.
    func searchSaved(_ input: String) {
        submittedSearch = input.trimmingCharacters(in: .whitespacesAndNewlines)
        submittedKind = searchKind
        submittedSearchIsLocal = true
        searchPages.reset()
        localSearchItems = submittedSearch.isEmpty || submittedKind != .video ? [] : libraryTracks.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(submittedSearch) || $0.displayArtist.localizedCaseInsensitiveContains(submittedSearch)
        }.compactMap { track in
            guard let video = track.publicVideoID else { return nil }
            return MusesCatalog.CatalogItem(kind: .video, id: video.rawValue, title: track.displayTitle, channelID: nil, thumbnailURL: nil, source: "local")
        }
    }

    func retrySearch() async {
        guard hasSubmittedSearch else { return }
        if submittedSearchIsLocal {
            let editingKind = searchKind
            searchKind = submittedKind
            searchSaved(submittedSearch)
            searchKind = editingKind
            return
        }
        searchPages.reset()
        await nextSearchPage()
    }

    func nextSearchPage() async {
        let query = submittedSearch, kind = submittedKind
        guard !query.isEmpty, !submittedSearchIsLocal else { return }
        await searchPages.load { token in
            guard let catalog = self.catalog, self.apiConfigured else { throw APIError.unauthorized }
            return try await catalog.search(query, pageToken: token, kind: kind)
        }
    }

    func readCatalog(_ route: YouTubeCatalogLink, token: String? = nil, contents: Bool = false, authorized: Bool = false) async throws -> MusesCatalog.CatalogPage {
        guard let catalog, apiConfigured, !authorized || signedIn else { throw APIError.unauthorized }
        switch route {
        case .video(let id): return try await catalog.videos([id])
        case .playlist(let id):
            return try await contents ? catalog.playlist(id: id, pageToken: token, authorized: authorized) : catalog.playlistMetadata(id: id, authorized: authorized)
        case .channel(let id):
            return try await contents ? catalog.channelPlaylists(id: id, pageToken: token) : catalog.channel(id: id)
        case .handle(let handle): return try await catalog.channel(id: handle, isHandle: true)
        }
    }

    func loadAccountPlaylists() async {
        guard !deletingLocalData else { return }
        activeNetworkCalls += 1
        defer { activeNetworkCalls -= 1 }
        let epoch = accountEpoch
        await accountPlaylistPages.load { token in
            guard self.signedIn, let catalog = self.catalog else { throw APIError.unauthorized }
            let page = try await catalog.myPlaylists(pageToken: token)
            try Task.checkCancellation()
            guard self.accountEpoch == epoch, self.signedIn, !self.deletingLocalData else { throw CancellationError() }
            return page
        }
    }

    /// Home fetches one page on first display. Additional pages require an explicit More action.
    func loadHomeAccountPlaylists(refresh: Bool = false) async {
        guard signedIn, !deletingLocalData, !accountPlaylistPages.loading else { return }
        if refresh { accountPlaylistPages.reset() }
        guard !accountPlaylistPages.loaded else { return }
        await loadAccountPlaylists()
    }
    var musicHomeScope: UInt64 { (accountEpoch << 1) | (signedIn ? 1 : 0) }
    #if DEBUG
    func readMusicHome(using service: PublicMusicHomeService, continuation: String? = nil) async throws -> PublicMusicHomeSnapshot {
        guard signedIn, !deletingLocalData, let oauth else { throw APIError.unauthorized }
        let epoch = accountEpoch
        activeNetworkCalls += 1
        defer { activeNetworkCalls -= 1 }
        let token = try await oauth.accessToken()
        try Task.checkCancellation()
        guard epoch == accountEpoch, signedIn, !deletingLocalData else { throw CancellationError() }
        let snapshot = try await service.fetch(accessToken: token, continuation: continuation)
        try Task.checkCancellation()
        guard epoch == accountEpoch, signedIn, !deletingLocalData else { throw CancellationError() }
        return snapshot
    }
    #endif
    func loadAccountCollections() async {
        guard signedIn, !accountPlaylistPages.loading else { return }
        if !accountPlaylistPages.loaded || accountPlaylistPages.nextPageToken != nil {
            repeat {
                await loadAccountPlaylists()
                guard signedIn, !Task.isCancelled, accountPlaylistPages.error == nil else { return }
            } while accountPlaylistPages.nextPageToken != nil
        }
        if signedIn && !subscriptionPages.loaded { await loadSubscriptions() }
    }
    func loadAccountChannel() async {
        guard !deletingLocalData else { return }
        activeNetworkCalls += 1
        defer { activeNetworkCalls -= 1 }
        await accountChannelPages.load { _ in
            guard self.signedIn, let catalog = self.catalog else { throw APIError.unauthorized }
            return try await catalog.myChannel()
        }
    }
    private func resetAccountCatalog() {
        subscriptionPages.reset(); accountPlaylistPages.reset(); accountChannelPages.reset()
        searchPages.reset(); localSearchItems = []; catalogRoute = nil
    }

    func maintainCatalogData() async {
        do { try expireCatalogMetadata() } catch { failureMessage = "Could not expire YouTube metadata: \(error.localizedDescription)" }
        searchPages.expire(); subscriptionPages.expire(); accountPlaylistPages.expire(); accountChannelPages.expire()
        await catalog?.purgeExpiredCache()
        await refreshPlaylistNames()
    }

    func expireCatalogMetadata(at date: Date = Date(), force: Bool = false) throws {
        for index in playlists.indices { playlists[index].expireRemoteName(at: date, force: force) }
        for index in tracks.indices {
            var track = tracks[index]
            track.expireYouTubeMetadata(at: date, force: force)
            if track != tracks[index] { try repository?.saveTrack(track); tracks[index] = track; localSearchItems = [] }
        }
    }

    private var hydratingMetadata = false
    private var lastHydrationAttempt: Date?
    private var lastHydrationEpoch: UInt64?
    func hydrateDisplayMetadata() async {
        guard !deletingLocalData, !hydratingMetadata, let catalog, apiConfigured else { return }
        if lastHydrationEpoch == accountEpoch, let lastHydrationAttempt, Date().timeIntervalSince(lastHydrationAttempt) < 60 { return }
        let ids = tracks.filter { $0.metadataOrigin == .placeholder || $0.artist == "YouTube" }.compactMap { $0.publicVideoID?.rawValue }
        guard !ids.isEmpty else { return }
        hydratingMetadata = true; lastHydrationAttempt = Date(); lastHydrationEpoch = accountEpoch; activeNetworkCalls += 1
        defer { hydratingMetadata = false; activeNetworkCalls -= 1 }
        let epoch = accountEpoch
        do {
            for start in stride(from: 0, to: ids.count, by: 50) {
                let page = try await catalog.videos(Array(ids[start..<min(start + 50, ids.count)]))
                guard epoch == accountEpoch, !deletingLocalData, !Task.isCancelled else { return }
                for index in tracks.indices {
                    guard let video = tracks[index].publicVideoID, let item = page.items.first(where: { $0.id == video.rawValue }) else { continue }
                    if tracks[index].metadataOrigin != .user {
                        tracks[index].title = item.title; tracks[index].metadataOrigin = .youtubeDataAPI; tracks[index].metadataFetchedAt = page.fetchedAt
                    }
                    tracks[index].artist = item.displayCreator
                }
            }
            if nativePlaybackEnabled, let track = currentTrack { nativePlayback.updateDisplayInfo(title: track.displayTitle, artist: track.displayArtist) }
        } catch { report("Song details could not load. Check your connection or use Refresh details in Settings. " + error.localizedDescription, for: .metadata)}
    }

    private(set) var refreshingMetadata = false
    func refreshSavedMetadata() async {
        guard !deletingLocalData, !refreshingMetadata else { return }
        refreshingMetadata = true
        defer { refreshingMetadata = false }
        await refreshPlaylistNames(force: true)
        activeNetworkCalls += 1
        defer { activeNetworkCalls -= 1 }
        guard let catalog, apiConfigured else { report(APIError.unauthorized.localizedDescription, for: .metadata); return }
        let epoch = accountEpoch
        let ids = tracks.filter { $0.metadataOrigin != .user }.compactMap { track -> String? in
            if case .youtubeVideo(let id) = track.source { return id.rawValue }; return nil
        }
        do {
            try expireCatalogMetadata()
            for start in stride(from: 0, to: ids.count, by: 50) {
                let batch = Array(ids[start..<min(start + 50, ids.count)])
                let page = try await catalog.videos(batch)
                guard epoch == accountEpoch else { return }
                for index in tracks.indices {
                    guard case .youtubeVideo(let id) = tracks[index].source, batch.contains(id.rawValue), tracks[index].metadataOrigin != .user else { continue }
                    var track = tracks[index]
                    if let item = page.items.first(where: { $0.id == id.rawValue }) {
                        track.title = item.title; track.artist = item.displayCreator
                        track.metadataOrigin = .youtubeDataAPI; track.metadataFetchedAt = page.fetchedAt
                    } else { track.expireYouTubeMetadata(force: true) }
                    try repository?.saveTrack(track); tracks[index] = track
                }
            }
            if nativePlaybackEnabled, let track = currentTrack { nativePlayback.updateDisplayInfo(title: track.displayTitle, artist: track.displayArtist) }
            report(nil, for: .metadata)
        } catch { report(error.localizedDescription, for: .metadata)}
    }

    func signIn() async {
        guard !deletingLocalData, !signingOut, !accountCleanupPending else { return }
        activeNetworkCalls += 1
        defer { activeNetworkCalls -= 1 }
        guard let oauth, let config = oauthConfiguration,
              let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first(where: \.isKeyWindow) else {
            report("Google iOS OAuth needs a configured client ID, redirect scheme and active window.", for: .account)
            return
        }
        guard activeSignIn == nil else { return }
        let epoch = accountEpoch
        let task = Task<Void, Error> { @MainActor in
            let attempt = try OAuthAttempt(configuration: config)
            let browser = IOSAuthorizationSession(anchor: window)
            self.authorizationSession = browser
            let callback = try await browser.authorize(attempt)
            try Task.checkCancellation()
            try await oauth.complete(attempt, callback: callback)
        }
        activeSignIn = task
        defer { activeSignIn = nil; authorizationSession = nil }
        do {
            try await task.value
            guard epoch == accountEpoch else { return }
            accountEpoch &+= 1
            resetAccountCatalog()
            signedIn = true
            report(nil, for: .account)
            await loadSubscriptions()
        } catch {
            if epoch == accountEpoch { report("Sign in failed: \(error.localizedDescription)", for: .account)}
        }
    }

    func loadSubscriptions() async {
        guard !deletingLocalData else { return }
        activeNetworkCalls += 1
        defer { activeNetworkCalls -= 1 }
        await subscriptionPages.load { token in
            guard self.signedIn, let catalog = self.catalog else { throw APIError.unauthorized }
            return try await catalog.mySubscriptions(pageToken: token)
        }
    }

    func signOut(revokeAccess: Bool = true) async {
        guard !deletingLocalData, !signingOut else { return }
        signingOut = true
        defer { signingOut = false }
        authorizationSession?.cancel()
        activeSignIn?.cancel()
        activeNetworkCalls += 1
        defer { activeNetworkCalls -= 1 }
        guard let oauth else { return }
        accountEpoch &+= 1
        signedIn = false
        resetAccountCatalog()
        do { try expireCatalogMetadata(force: true) } catch { report("Metadata could not be removed: \(error.localizedDescription)", for: .metadata) }
        accountCleanupPending = true
        do {
            if revokeAccess { try await oauth.revokeAndDelete() }
            else { try await oauth.deleteLocalAccount() }
            accountCleanupPending = false
            report(nil, for: .account)
        }
        catch OAuthFailure.storage {
            report("Account cleanup could not finish on this device. Retry when the device is unlocked and review Google account access.", for: .account)
        }
        catch {
            accountCleanupPending = !revokeAccess
            report(revokeAccess
                ? "Local account data was removed. Google revocation may have failed; review access in your Google account settings."
                : "Local account cleanup could not finish. Unlock this device and retry.", for: .account)
        }
        signedIn = false
        resetAccountCatalog()
        await catalog?.clearPrivateCache()
    }

    func retryAccountCleanup() async {
        guard !deletingLocalData, !signingOut, let oauth else { return }
        activeNetworkCalls += 1
        defer { activeNetworkCalls -= 1 }
        signingOut = true
        defer { signingOut = false }
        accountEpoch &+= 1
        signedIn = false
        resetAccountCatalog()
        do {
            try await oauth.deleteLocalAccount()
            accountCleanupPending = false
            report(nil, for: .account)
        } catch {
            accountCleanupPending = true
            report("Account cleanup could not finish. Unlock this device and retry.", for: .account)
        }
    }

    func openLink(_ text: String) async {
        guard !deletingLocalData else { return }
        activeNetworkCalls += 1
        defer { activeNetworkCalls -= 1 }
        let generation = UUID(), epoch = accountEpoch
        linkGeneration = generation
        guard let route = YouTubeCatalogLink.parse(text) else {
            failureMessage = "Enter a YouTube video, playlist or channel URL (including @handle), or an 11-character video ID."
            return
        }
        guard case .video(let rawID) = route, let video = try? VideoID(rawID) else {
            catalogRoute = route
            return
        }
        var fetchedAt: Date?
        var artist: String?
        var title = "YouTube video \(video.rawValue)"
        if let catalog, let result = try? await catalog.videos([video.rawValue]),
           let item = result.items.first(where: { $0.id == video.rawValue }) {
            title = item.title
            artist = item.displayCreator
            fetchedAt = item.fetchedAt
        }
        guard !deletingLocalData, generation == linkGeneration, epoch == accountEpoch, !Task.isCancelled else { return }
        open(video, title: title, metadataFetchedAt: fetchedAt, artist: artist)
    }

    nonisolated static func videoID(from input: String) -> VideoID? {
        guard case .video(let raw) = YouTubeCatalogLink.parse(input) else { return nil }
        return try? VideoID(raw)
    }

    @discardableResult
    func open(_ id: VideoID, title: String, metadataFetchedAt: Date? = nil, artist: String? = nil) -> Bool {
        guard repository != nil else { return false }
        bookmarkSeeking.cancel()
        bookmarkCueMilliseconds = nil
        do {
            let track: MusesDomain.Track
            if let index = tracks.firstIndex(where: { $0.source == .youtubeVideo(id) }) {
                if let metadataFetchedAt, tracks[index].metadataOrigin != .user {
                    tracks[index].title = title; tracks[index].metadataOrigin = .youtubeDataAPI; tracks[index].metadataFetchedAt = metadataFetchedAt
                }
                if let artist { tracks[index].artist = artist }
                track = tracks[index]
            }
            else {
                track = try MusesDomain.Track(id: TrackID(UUID().uuidString), title: title,
                    artist: artist ?? "YouTube", source: .youtubeVideo(id),
                    provenance: Provenance(provider: ProviderID("youtube"), originalID: id.rawValue),
                    metadataOrigin: metadataFetchedAt == nil ? (title == "YouTube video \(id.rawValue)" ? .placeholder : .user) : .youtubeDataAPI, metadataFetchedAt: metadataFetchedAt)
                try repository?.saveTrack(track)
                tracks.append(track)
            }
            guard editQueue({ try $0.playNow(QueueEntry(trackID: track.id, source: track.source), context: "public"); $0.setIntent(.pause) }) else { return false }
            state = PlaybackSnapshot(state: .loading, source: track.source,
                generation: queue.snapshot.generation, intent: .pause, capabilities: youtubeCapabilities)
            failureMessage = nil
            showPlayer = true
            if nativePlaybackEnabled || adapter != nil { loadCurrent() }
            return true
        } catch { failureMessage = error.localizedDescription; return false }
    }

    func openBookmark(_ bookmark: VideoTimeBookmark) {
        guard let track = tracks.first(where: { $0.id == bookmark.trackID }),
              case .youtubeVideo(let videoID) = track.source else {
            failureMessage = VideoNotebookError.missingTrack.localizedDescription
            return
        }
        guard open(videoID, title: track.title), let entry = queue.snapshot.current else { return }
        if nativePlaybackEnabled {
            bookmarkCueMilliseconds = bookmark.timestampMilliseconds
            loadCurrent(); return
        }
        do {
            try bookmarkSeeking.prepare(entryID: entry.id, videoID: videoID, milliseconds: bookmark.timestampMilliseconds)
            bookmarkCueMilliseconds = bookmark.timestampMilliseconds
            if adapter != nil { bookmarkSeeking.bind(entryID: entry.id, generation: adapterGeneration) }
        } catch { failureMessage = error.localizedDescription }
    }

    func enqueue(_ id: VideoID, title: String, metadataFetchedAt: Date? = nil, artist: String? = nil) {
        guard repository != nil else { return }
        do {
            let track: MusesDomain.Track
            if let index = tracks.firstIndex(where: { $0.source == .youtubeVideo(id) }) {
                if let metadataFetchedAt, tracks[index].metadataOrigin != .user {
                    tracks[index].title = title; tracks[index].metadataOrigin = .youtubeDataAPI; tracks[index].metadataFetchedAt = metadataFetchedAt
                }
                if let artist { tracks[index].artist = artist }
                track = tracks[index]
            }
            else {
                track = try MusesDomain.Track(id: TrackID(UUID().uuidString), title: title,
                    artist: artist ?? "YouTube", source: .youtubeVideo(id),
                    provenance: Provenance(provider: ProviderID("youtube"), originalID: id.rawValue),
                    metadataOrigin: metadataFetchedAt == nil ? (title == "YouTube video \(id.rawValue)" ? .placeholder : .user) : .youtubeDataAPI, metadataFetchedAt: metadataFetchedAt)
                try repository?.saveTrack(track)
                tracks.append(track)
            }
            editQueue { try $0.append(QueueEntry(trackID: track.id, source: track.source)) }
        } catch { failureMessage = error.localizedDescription }
    }

    func toggleFavorite(_ id: TrackID? = nil) {
        guard let id = id ?? currentTrack?.id, let index = tracks.firstIndex(where: { $0.id == id }) else { return }
        var updated = tracks[index]
        updated.liked.toggle()
        do { try repository?.saveTrack(updated); tracks[index] = updated; report(nil, for: .library)}
        catch { report(error.localizedDescription, for: .library)}
    }

    @discardableResult
    func createPlaylist(_ name: String, trackIDs: [TrackID] = [], nameIsExplicitUserInput: Bool = false) -> Bool {
        do {
            guard let repository else { return false }
            let playlist = try LocalPlaylist(name: name, trackIDs: trackIDs)
            if nameIsExplicitUserInput { try repository.saveUserNamedPlaylist(playlist) }
            else { try repository.savePlaylist(playlist) }
            playlists.append(playlist)
            report(nil, for: .library)
            return true
        } catch { report("Could not create playlist: \(error.localizedDescription)", for: .library); return false }
    }

    @discardableResult
    func editPlaylist(_ id: UUID, nameIsExplicitUserInput: Bool = false, change: (inout LocalPlaylist) throws -> Void) -> Bool {
        guard let index = playlists.firstIndex(where: { $0.id == id }), let repository else { return false }
        do {
            var value = playlists[index]
            try change(&value)
            if nameIsExplicitUserInput { try repository.saveUserNamedPlaylist(value) }
            else { try repository.savePlaylist(value) }
            playlists[index] = value
            report(nil, for: .library)
            return true
        } catch { report("Could not save playlist: \(error.localizedDescription)", for: .library); return false }
    }

    @discardableResult
    func deletePlaylist(_ id: UUID) -> Bool {
        do {
            guard let repository else { return false }
            try repository.delete(kind: .localPlaylist, id: id.uuidString)
            playlists.removeAll { $0.id == id }
            report(nil, for: .library)
            return true
        } catch { report(error.localizedDescription, for: .library); return false }
    }

    func clearHistory() {
        do { try repository?.deleteAll(kind: .history); playedIDs = []; report(nil, for: .library)}
        catch { report(error.localizedDescription, for: .library)}
    }

    /// Publish only after the proposed snapshot has been saved successfully.
    @discardableResult
    func editQueue(_ change: (inout PlaybackQueue) throws -> Void) -> Bool {
        guard let repository else { report("Local library is unavailable. The queue was not changed.", for: .queue); return false }
        do {
            var proposed = queue
            try change(&proposed)
            try beforeQueueSave()
            try repository.saveQueue(proposed.snapshot)
            queue = proposed
            if nativePlaybackEnabled { nativePlayback.updateQueueAvailability(hasNext: hasNext) }
            report(nil, for: .queue)
            return true
        } catch { report("Could not save queue: \(error.localizedDescription)", for: .queue); return false }
    }

    func enqueueTrack(_ track: MusesDomain.Track, next: Bool = false) {
        editQueue {
            let entry = QueueEntry(trackID: track.id, source: track.source)
            if next { try $0.playNext(entry) } else { try $0.append(entry) }
        }
    }

    func enqueuePlaylist(_ id: UUID) {
        guard let playlist = playlists.first(where: { $0.id == id }) else { return }
        editQueue { proposed in
            for id in playlist.playbackTrackIDs {
                guard let track = tracks.first(where: { $0.id == id }) else { throw LocalLibraryError.missingTrack }
                try proposed.append(QueueEntry(trackID: track.id, source: track.source))
            }
        }
    }

    /// Original occurrence offsets include unavailable slots; duplicate videos remain distinct entries.
    @discardableResult
    func playPlaylist(_ id: UUID, startingAtOccurrenceIndex index: Int = 0) -> Bool {
        guard let playlist = playlists.first(where: { $0.id == id }) else { return false }
        let slots = playlist.occurrences?.map(\.trackID) ?? playlist.trackIDs.map { Optional($0) }
        guard slots.indices.contains(index), let selected = slots[index],
              let selectedTrack = tracks.first(where: { $0.id == selected }),
              case .youtubeVideo = selectedTrack.source else { return false }
        let entries = slots.enumerated().compactMap { offset, trackID -> (Int, QueueEntry)? in
            guard let trackID, let track = tracks.first(where: { $0.id == trackID }),
                  case .youtubeVideo = track.source else { return nil }
            return (offset, QueueEntry(trackID: track.id, source: track.source))
        }
        guard let selectedIndex = entries.firstIndex(where: { $0.0 == index }) else { return false }
        guard editQueue({ try $0.playCollection(entries.map { $0.1 }, startingAt: selectedIndex, context: "playlist:" + id.uuidString); $0.setIntent(.pause) }) else { return false }
        bookmarkSeeking.cancel()
        bookmarkCueMilliseconds = nil
        state = PlaybackSnapshot(state: .loading, source: selectedTrack.source,
            generation: queue.snapshot.generation, intent: .pause, capabilities: youtubeCapabilities)
        showPlayer = true
        if nativePlaybackEnabled || adapter != nil { loadCurrent() }
        return true
    }

    @discardableResult
    func playTracks(_ collection: [MusesDomain.Track], startingAt index: Int, context: String) -> Bool {
        guard collection.indices.contains(index), case .youtubeVideo = collection[index].source else { return false }
        let entries = collection.enumerated().compactMap { offset, track -> (Int, QueueEntry)? in
            guard case .youtubeVideo = track.source else { return nil }
            return (offset, QueueEntry(trackID: track.id, source: track.source))
        }
        guard let selected = entries.firstIndex(where: { $0.0 == index }),
              editQueue({ try $0.playCollection(entries.map { $0.1 }, startingAt: selected, context: context); $0.setIntent(.pause) }) else { return false }
        bookmarkSeeking.cancel(); bookmarkCueMilliseconds = nil
        state = PlaybackSnapshot(state: .loading, source: collection[index].source,
            generation: queue.snapshot.generation, intent: .pause, capabilities: youtubeCapabilities)
        showPlayer = true
        if nativePlaybackEnabled || adapter != nil { loadCurrent() }
        return true
    }

    func clearUpcoming() {
        guard hasNext else { return }
        editQueue { proposed in
            for entry in proposed.snapshot.upcoming { try proposed.remove(id: entry.id) }
        }
    }

    func attach(_ player: YouTubeIFrameAdapter) {
        playbackCommands.reset()
        nativePlayback.stop()
        adapter?.teardown()
        adapter = player
        player.onEvent = { [weak self, weak player] event in
            guard let self, let player, self.adapter === player else { return }
            self.receive(event)
        }
        loadCurrent()
    }

    func detach() {
        playbackCommands.reset()
        contentCheck?.cancel()
        contentCheckID = UUID()
        adapter?.teardown()
        adapter = nil
        adapterGeneration = 0
        bookmarkSeeking.cancel()
        bookmarkCueMilliseconds = nil
        hasCurrentPlaybackTime = false
        if state.state == .playing || state.state == .buffering { state.state = .paused }
        queue.setIntent(.pause)
        checkpointPlayback(force: true)
    }

    private func loadCurrent(nativeAutoplay: Bool? = nil) {
        playbackCommands.reset()
        if nativePlaybackEnabled {
            contentCheck?.cancel(); contentCheckID = UUID()
            adapter?.teardown(); adapter = nil; adapterGeneration = 0
            guard let track = currentTrack, case .youtubeVideo(let id) = track.source else { nativePlayback.stop(); return }
            let autoplay = nativeAutoplay ?? (state.state != .paused && bookmarkCueMilliseconds == nil)
            state = PlaybackSnapshot(state: .loading, source: track.source, generation: queue.snapshot.generation, intent: autoplay ? .play : .pause, capabilities: [.seek, .queueByID, .backgroundAudio, .systemRemote])
            hasCurrentPlaybackTime = false; failureMessage = nil
            nativePlayback.updateQueueAvailability(hasNext: hasNext)
            nativePlayback.load(videoID: id.rawValue, title: track.displayTitle, artist: track.displayArtist, start: (bookmarkCueMilliseconds ?? Double(queue.snapshot.positionMilliseconds)) / 1000, autoplay: autoplay)
            return
        }
        contentCheck?.cancel()
        let checkID = UUID()
        contentCheckID = checkID
        adapterGeneration = 0
        adapter?.clear()
        guard let adapter, case .youtubeVideo(let id) = queue.snapshot.current?.source,
              let iframeID = IFrameVideoID(id.rawValue) else { return }
        let entryID = queue.snapshot.current?.id
        let checkAccountEpoch = accountEpoch
        hasCurrentPlaybackTime = false
        state.positionMilliseconds = queue.snapshot.positionMilliseconds
        state.state = .loading
        state.failure = nil
        state.generation = queue.snapshot.generation
        state.source = .youtubeVideo(id)
        state.capabilities = []
        failureMessage = nil
        contentCheck = Task { @MainActor [weak self, weak adapter] in
            guard let self, let adapter else { return }
            let status: VideoEmbeddingStatus
            var checkFailure: String?
            do {
                guard let catalog = self.catalog else { throw APIError.unauthorized }
                status = try await catalog.videoEmbeddingStatus(id.rawValue)
            } catch { status = .unknown; checkFailure = error.localizedDescription }
            guard !Task.isCancelled, self.contentCheckID == checkID,
                  self.adapter === adapter, !self.deletingLocalData, self.accountEpoch == checkAccountEpoch,
                  self.queue.snapshot.current?.id == entryID else { return }
            guard status == .permitted else {
                self.bookmarkSeeking.cancel()
                self.state.state = .failed
                self.state.failure = status == .notEmbeddable ? .notEmbeddable : .permissionDenied
                switch status {
                case .madeForKids:
                    self.failureMessage = "Made for Kids videos are not supported by this embedded player. Open this video in YouTube."
                case .notEmbeddable:
                    self.failureMessage = "This video does not allow embedding. Open it in YouTube."
                default:
                    self.failureMessage = "YouTube content status could not be verified. Retry the status check, or open this video in YouTube."
                }
                if let checkFailure { self.failureMessage = "YouTube content status check failed: " + checkFailure + " Retry the status check." }
                self.report(self.failureMessage, for: .playback)
                return
            }
            self.report(nil, for: .playback)
            self.state.capabilities = self.youtubeCapabilities
            self.adapterGeneration = adapter.load(iframeID)
            if let entryID {
                if self.bookmarkCueMilliseconds == nil, self.queue.snapshot.positionMilliseconds > 0 {
                    do { try self.bookmarkSeeking.prepare(entryID: entryID, videoID: id, milliseconds: Double(self.queue.snapshot.positionMilliseconds)) }
                    catch { self.report("Saved position could not be prepared: " + error.localizedDescription, for: .playback) }
                }
                self.bookmarkSeeking.bind(entryID: entryID, generation: self.adapterGeneration)
            }
        }
    }

    private var youtubeCapabilities: PlaybackCapabilities {
        guard let source = queue.snapshot.current?.source else { return [] }
        return PlaybackCapabilityPolicy.effective(source: source,
            rights: ContentRights(origin: .youtube),
            distribution: DistributionCapabilities(channel: .appStore),
            adapter: [.videoVisible, .seek, .queueByID],
            runtime: [.videoVisible, .seek, .queueByID])
    }

    private func receive(_ event: IFrameEvent) {
        guard adapter != nil, adapterGeneration != 0, event.generation == adapterGeneration,
              case .youtubeVideo(let id) = queue.snapshot.current?.source,
              id.rawValue == event.videoID.rawValue else { return }
        switch event.kind {
        case .loading: state.state = .loading
        case .ready:
            state.state = .ready
            if let entry = queue.snapshot.current, let adapter {
                do {
                    if let milliseconds = try bookmarkSeeking.ready(entryID: entry.id, videoID: id, generation: event.generation,
                                                                     position: { try adapter.prepareBookmark(at: $0) }) {
                        state.positionMilliseconds = Int(milliseconds)
                        queue.checkpoint(positionMilliseconds: Int(milliseconds))
                        queue.setIntent(.pause)
                        checkpointPlayback(force: true)
                    }
                } catch { report("Bookmark position could not be prepared: \(error.localizedDescription)", for: .playback)}
            }
        case .cued:
            state.state = .ready
            playbackCommands.confirmed(.pause, generation: event.generation)
        case .playBlocked: playbackCommands.blocked(generation: event.generation)
        case .playing:
            playbackCommands.confirmed(.play, generation: event.generation)
            state.state = .playing
            state.intent = .play
            queue.setIntent(.play)
            if let entryID = queue.snapshot.current?.id, recordedEntryID != entryID {
                if let track = currentTrack {
                    let entry = PlaybackHistoryEntry(id: UUID(), trackID: track.id, date: Date())
                    do {
                        try repository?.put(entry, kind: .history, id: entry.id.uuidString)
                        playedIDs.insert(track.id, at: 0)
                        recordedEntryID = entryID
                    } catch {
                        report("Playback started, but history could not be saved: \(error.localizedDescription)", for: .playback)
                    }
                }
            }
        case .paused:
            playbackCommands.confirmed(.pause, generation: event.generation)
            state.state = .paused; state.intent = .pause
            queue.setIntent(.pause); checkpointPlayback(force: true)
        case .buffering: state.state = .buffering
        case .ended: state.state = .ended; next()
        case .time(let position, let duration):
            guard position.isFinite, duration.isFinite, position >= 0, duration >= 0,
                  position * 1000 < Double(Int.max), duration * 1000 < Double(Int.max) else { return }
            hasCurrentPlaybackTime = true
            state.positionMilliseconds = max(0, Int(position * 1000))
            state.durationMilliseconds = max(0, Int(duration * 1000))
            queue.checkpoint(positionMilliseconds: state.positionMilliseconds)
            checkpointPlayback(force: false)
        case .failed(let reason):
            playbackCommands.reset()
            bookmarkSeeking.cancel()
            hasCurrentPlaybackTime = false
            state.state = .failed
            state.failure = reason == .embeddingDisabled ? .notEmbeddable : .unavailable
            report(reason == .embeddingDisabled ? "This video does not allow embedding. Open it in YouTube." : "YouTube playback failed: \(reason)", for: .playback)
        }
    }

    func togglePlayback() {
        guard !isPlaybackCommandPending else { return }
        if state.state == .playing || state.state == .buffering { pause() } else { play() }
    }

    func retryPlaybackCommand() {
        guard canRetryPlaybackCommand, let request = playbackCommands.failedRequest else { return }
        requestPlaybackCommand(request.action)
    }

    private func requestPlaybackCommand(_ action: PublicPlaybackCommandController.Action) {
        guard let request = playbackCommands.begin(action, generation: adapterGeneration) else { return }
        guard let adapter, adapterGeneration != 0 else {
            playbackCommands.dispatched(request, failure: "The visible YouTube player is not ready. Use its controls when ready.")
            return
        }
        let complete: (Result<Void, YouTubeIFrameAdapter.CommandError>) -> Void = { [weak self] result in
            guard let self else { return }
            if case .failure = result {
                self.playbackCommands.dispatched(request, failure: "The command could not reach the YouTube player. Retry or use its visible controls.")
            } else { self.playbackCommands.dispatched(request, failure: nil) }
        }
        if action == .play {
            do { try adapter.play(completion: complete) }
            catch { playbackCommands.dispatched(request, failure: "The visible YouTube player is not ready. Use its controls when ready.") }
        } else { adapter.pause(completion: complete) }
    }

    func play() {
        if nativePlaybackEnabled {
            if nativePlayback.loaded || state.state == .loading || state.state == .buffering { nativePlayback.play() }
            else { loadCurrent(nativeAutoplay: true) }
            return
        }
        requestPlaybackCommand(.play)
    }
    func pause() {
        if nativePlaybackEnabled { nativePlayback.pause() }
        else {
            // Explicit lifecycle/host pause may supersede a pending Play; UI toggle itself
            // is disabled while pending, so repeated taps never issue contradictory commands.
            if playbackCommands.pending?.action == .play { playbackCommands.reset() }
            requestPlaybackCommand(.pause)
        }
        queue.setIntent(.pause)
        state.intent = .pause
        checkpointPlayback(force: true)
    }

    func suspendVisiblePlayback() {
        playbackCommands.reset()
        if !nativePlaybackEnabled {
            adapter?.pause()
            queue.setIntent(.pause)
            state.intent = .pause
        }
        checkpointPlayback(force: true)
    }
    func next() {
        guard hasNext else { pause(); return }
        guard editQueue({ _ = try $0.next(); $0.setIntent(.pause) }) else { return }
        recordedEntryID = nil
        bookmarkSeeking.cancel()
        bookmarkCueMilliseconds = nil
        state = PlaybackSnapshot(state: .loading, source: queue.snapshot.current?.source,
            generation: queue.snapshot.generation, intent: .pause, capabilities: youtubeCapabilities)
        loadCurrent()
    }

    var nativePlaybackAvailable: Bool { ExperimentalNativePlayback.available }
    func setNativePlayback(_ enabled: Bool) {
        guard !enabled || nativePlaybackAvailable else { return }
        nativePlayback.stop(); detach()
        nativePlaybackEnabled = enabled
        defaults.set(enabled, forKey: "experimentalNativePlayback")
        if enabled, currentTrack != nil { loadCurrent() }
    }
    func closePlayerPresentation() { if !nativePlaybackEnabled { detach() } }
    func seekPlayback(seconds: Double) {
        if nativePlaybackEnabled { nativePlayback.seek(seconds) }
        else { do { try adapter?.seek(to: seconds) } catch { report("Player is not ready to seek.", for: .playback)} }
    }
    func previous() {
        guard nativePlaybackEnabled else { return }
        if state.positionMilliseconds > 3000 || queue.snapshot.history.isEmpty { nativePlayback.seek(0); return }
        guard editQueue({ _ = try $0.previous() }) else { return }
        recordedEntryID = nil; bookmarkCueMilliseconds = nil; loadCurrent()
    }
    private func receiveNative(_ event: ExperimentalNativePlayback.Event) {
        guard nativePlaybackEnabled else { return }
        switch event {
        case .playing:
            state.state = .playing; state.intent = .play; queue.setIntent(.play)
            if let current = queue.snapshot.current, recordedEntryID != current.id {
                let entry = PlaybackHistoryEntry(id: UUID(), trackID: current.trackID, date: Date())
                do { try repository?.put(entry, kind: .history, id: entry.id.uuidString); playedIDs.insert(current.trackID, at: 0); recordedEntryID = current.id }
                catch { report("Playback started, but history could not be saved.", for: .playback)}
            }
        case .paused: state.state = .paused; queue.setIntent(.pause); checkpointPlayback(force: true)
        case .buffering: state.state = .buffering
        case .time(let position, let duration):
            guard position.isFinite, duration.isFinite, position >= 0, duration >= 0,
                  position * 1000 < Double(Int.max), duration * 1000 < Double(Int.max) else { return }
            hasCurrentPlaybackTime = true
            state.positionMilliseconds = Int(position * 1000); state.durationMilliseconds = Int(duration * 1000)
            queue.checkpoint(positionMilliseconds: state.positionMilliseconds)
            checkpointPlayback(force: false)
        case .ended: state.state = .ended; next()
        case .failed(let message): state.state = .failed; state.failure = .unavailable; hasCurrentPlaybackTime = false; report(message, for: .playback)
        }
    }

    private func persistQueue() throws {
        guard let repository else { throw LocalLibraryError.missingTrack }
        try beforeQueueSave()
        try repository.saveQueue(queue.snapshot)
    }

    /// UI lifecycle hooks may call this when leaving the foreground. Restore is always paused.
    func checkpointPlayback(force: Bool = true) {
        let previousFailure = playbackCheckpoint.failure
        _ = playbackCheckpoint.save(queue.snapshot, at: checkpointNow(), force: force) { _ in try persistQueue() }
        if let failure = playbackCheckpoint.failure { report(failure, for: .playback) }
        else if previousFailure != nil && playbackError == previousFailure { report(nil, for: .playback) }
        if let failure = playbackCheckpoint.failure {
            defaults.set(failure, forKey: "playbackCheckpointFailure")
            defaults.set(checkpointNow(), forKey: "playbackCheckpointFailureDate")
        } else { defaults.removeObject(forKey: "playbackCheckpointFailure"); defaults.removeObject(forKey: "playbackCheckpointFailureDate") }
    }

    func retryPlaybackCheckpoint() { checkpointPlayback(force: true) }

    var canRetryPlayback: Bool { currentTrack != nil && state.state == .failed && (nativePlaybackEnabled || adapter != nil) }
    /// Always rechecks status; this never grants an exception to embedding/content restrictions.
    func retryPlayback() { guard canRetryPlayback else { return }; loadCurrent() }


    func deleteLocalData() async {
        nativePlayback.stop()
        if deletingLocalData { await finishRecordedDeletion(); return }
        detach()
        accountEpoch &+= 1
        authorizationSession?.cancel()
        activeSignIn?.cancel()
        do {
            // Record intent before any async cleanup. Restart cannot revive the old library.
            _ = try PublicStoreRouter.requestDeletion(legacyURL: legacyURL, destinationURL: destinationURL,
                defaults: defaults, domainName: defaultsDomain, externalCleanupRequired: true)
            deletingLocalData = true
            // Best effort immediate erase; old files are unlinked on restart even if this save fails.
            try? repository?.deleteAll()
            repository = nil
            v1Container = nil
            clearVisibleLibrary()
            recoveryMessage = "Removing local account and website data…"
            await finishRecordedDeletion()
        } catch {
            report("Deletion could not be recorded: \(error.localizedDescription)", for: .deletion)
        }
    }

    private func clearVisibleLibrary() {
        nativePlayback.stop()
        playbackCommands.reset()
        playbackCheckpoint.reset()
        operationFailures = [:]
        notebook.reset()
        bookmarkSeeking.cancel()
        bookmarkCueMilliseconds = nil
        resetAccountCatalog()
        hasMigrationArchive = false
        successorIdentity = nil
        showMigrationArchive = false
        playlists = []
        recordedEntryID = nil
        showPlayer = false
        tracks = []
        queue = try! PlaybackQueue()
        state = PlaybackSnapshot()
        localSearchItems = []
        searchPages.reset()
        playedIDs = []
        subscriptionPages.reset()
        signedIn = false
    }

    private func finishRecordedDeletion() async {
        guard !cleanupInFlight else { return }
        cleanupInFlight = true
        defer { cleanupInFlight = false }
        deletingLocalData = true
        detach()
        clearVisibleLibrary()
        var failures: [String] = []
        if let task = activeSignIn {
            task.cancel()
            _ = try? await task.value
        }
        do { try await oauth?.deleteLocalAccount() }
        catch { failures.append("Account storage: \(error.localizedDescription)") }
        await catalog?.clearAllCache()
        do { try await deleteWebsiteData() }
        catch { failures.append("Website data: \(error.localizedDescription)") }
        for _ in 0..<100 where activeNetworkCalls > 0 {
            try? await Task.sleep(for: .milliseconds(20))
        }
        if activeNetworkCalls > 0 { failures.append("Earlier network requests have not finished; cleanup will retry after restart") }
        // Credentials are deleted last, after cancelled requests can no longer save a refresh token.
        do { try deleteCredentials() }
        catch { failures.append("Keychain: \(error.localizedDescription)") }
        // No old in-flight request can populate the new generation or UI.
        catalog = nil
        oauth = nil
        guard failures.isEmpty else {
            recoveryMessage = "Deletion is pending. Restart Muses to retry cleanup. " + failures.joined(separator: " · ")
            report(recoveryMessage, for: .deletion)
            return
        }
        do {
            try PublicStoreRouter.completeExternalDeletion(destinationURL: destinationURL)
            let fresh = try PublicStoreRouter.resolve(legacyURL: legacyURL, destinationURL: destinationURL,
                defaults: defaults, domainName: defaultsDomain)
            try loadLibrary(at: fresh)
            recoveryMessage = nil
            deletingLocalData = false
            report(PublicStoreRouter.deletionNeedsRestart(destinationURL: destinationURL)
                ? "Library cleared. Restart Muses to finish removing retained migration files." : nil, for: .deletion)
            configureRemoteServices()
        } catch {
            repository = nil
            v1Container = nil
            recoveryMessage = "Deletion is recorded. Restart Muses to finish cleanup; the old library will not be imported again. \(error.localizedDescription)"
            report(recoveryMessage, for: .deletion)
        }
    }

}

private actor PublicPrivateData: PrivateAccountData {
    private var catalog: YouTubeDataCatalog?
    func setCatalog(_ catalog: YouTubeDataCatalog) { self.catalog = catalog }
    func deletePrivateData() async throws { await catalog?.clearPrivateCache() }
}

enum LibraryCategory: String, CaseIterable, Identifiable {
    case artists = "Artists", albums = "Albums", songs = "Songs", favorites = "Favorites"
    case videos = "Videos", podcasts = "Podcasts", subscriptions = "Subscriptions"
    case playlists = "Playlists", history = "History"
    var id: String { rawValue }
}

#if DEBUG
private struct PublicFixtureCredential: CatalogCredential {
    func accessToken() async throws -> String { "ui-fixture-token" }
}
#endif

// Library deletion publishes only after the complete public graph has committed.
extension PublicYouTubeSession {
    @discardableResult
    func deleteSavedTrack(_ id: TrackID) -> Bool { deleteSavedTracks([id]) }

    @discardableResult
    func deleteSavedTracks(_ ids: Set<TrackID>) -> Bool {
        guard let repository else { report("Local library is unavailable.", for: .library); return false }
        do {
            let wasCurrent = queue.snapshot.current.map { ids.contains($0.trackID) } == true
            let saved = try repository.deleteSavedTracks(ids)
            let restored = try PlaybackQueue(snapshot: saved.queue)
            // Retain fresh in-memory metadata for survivors; disk may contain placeholders.
            tracks.removeAll { ids.contains($0.id) }
            playlists = saved.playlists.map { saved in
                var value = saved
                if let old = playlists.first(where: { $0.id == saved.id }), let fetchedAt = old.remoteNameFetchedAt {
                    try? value.updateRemoteName(old.name, fetchedAt: fetchedAt)
                }
                return value
            }
            queue = restored
            for id in ids { notebook.forget(id) }
            playedIDs = saved.history.sorted { $0.date > $1.date }.map(\.trackID)
            localSearchItems.removeAll { item in !tracks.contains { track in
                if case .youtubeVideo(let video) = track.source { return video.rawValue == item.id }; return false
            } }
            if wasCurrent {
                nativePlayback.stop()
                bookmarkSeeking.cancel(); bookmarkCueMilliseconds = nil; hasCurrentPlaybackTime = false
                contentCheck?.cancel(); contentCheckID = UUID()
                adapter?.teardown(); adapter = nil; adapterGeneration = 0
                playbackCommands.reset()
                playbackCheckpoint.reset()
                operationFailures[.playback] = nil
                recordedEntryID = nil; showPlayer = false; state = PlaybackSnapshot()
            } else { state.generation = queue.snapshot.generation }
            report(nil, for: .library)
            return true
        } catch { report("Could not delete the saved video. Your library was not changed: \(error.localizedDescription)", for: .library); return false }
    }

    @discardableResult
    func removeHistoryItem(_ id: TrackID) -> Bool {
        guard let repository else { report("Local library is unavailable.", for: .library); return false }
        do {
            let history = try repository.removeLocalHistory(for: id)
            playedIDs = history.sorted { $0.date > $1.date }.map(\.trackID)
            report(nil, for: .library); return true
        } catch { report("Could not remove local history: \(error.localizedDescription)", for: .library); return false }
    }

    @discardableResult
    func removeFavorite(_ id: TrackID) -> Bool {
        guard let repository, let index = tracks.firstIndex(where: { $0.id == id }) else { return false }
        do {
            _ = try repository.removeLocalFavorite(id)
            tracks[index].liked = false
            report(nil, for: .library); return true
        } catch { report("Could not remove favorite: \(error.localizedDescription)", for: .library); return false }
    }
}


extension PublicYouTubeSession {
    func clearLibraryItems(_ category: LibraryCategory) {
        guard let repository else { report("Local library is unavailable.", for: .library); return }
        do {
            switch category {
            case .videos: _ = deleteSavedTracks(Set(libraryTracks.map(\.id))); return
            case .songs: _ = deleteSavedTracks(Set(playlists.flatMap(\.trackIDs))); return
            case .favorites:
                _ = try repository.clearLocalFavorites()
                for index in tracks.indices { tracks[index].liked = false }
            case .playlists: try repository.deleteAll(kind: .localPlaylist); playlists = []
            case .history: try repository.deleteAll(kind: .history); playedIDs = []
            default: return
            }
            report(nil, for: .library)
        } catch { report("Could not clear local items: \(error.localizedDescription)", for: .library)}
    }
    func clearSearchResults() {
        searchPages.reset(); localSearchItems = []; submittedSearch = ""; submittedSearchIsLocal = false
    }
    func clearCatalogDisplay() async {
        resetAccountCatalog()
        await catalog?.clearAllCache()
    }
}

extension PublicYouTubeSession {
    func saveImportedPlaylist(name: String, draft: PlaylistImportDraft, remoteSource: RemotePlaylistSource? = nil, originalName: String? = nil, nameFetchedAt: Date? = nil) throws {
        guard draft.complete, let repository, !deletingLocalData else { throw PlaylistImportError.incomplete }
        let ids = try draft.items.map { try VideoID($0.id) }
        let userNamed = remoteSource != nil && name.trimmingCharacters(in: .whitespacesAndNewlines) != originalName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let (playlist, added) = try repository.importPlaylist(name: name, videoIDs: ids, remoteSource: remoteSource, userNamed: userNamed, nameFetchedAt: nameFetchedAt ?? Date())
        tracks += added
        for index in tracks.indices {
            guard tracks[index].metadataOrigin != .user,
                  case .youtubeVideo(let video) = tracks[index].source,
                  let item = draft.items.first(where: { $0.id == video.rawValue }) else { continue }
            tracks[index].title = item.title
            tracks[index].artist = item.displayCreator
            tracks[index].metadataOrigin = .youtubeDataAPI
            tracks[index].metadataFetchedAt = item.fetchedAt ?? Date()
        }
        playlists.append(playlist)
    }
}

extension PublicYouTubeSession {
    /// Restores only display names. Playlist membership remains the user's local snapshot.
    func refreshPlaylistNames(force: Bool = false) async {
        guard !deletingLocalData, !refreshingPlaylistNames, let catalog, apiConfigured else { return }
        let now = Date()
        if !force, let lastPlaylistNameAttempt, now.timeIntervalSince(lastPlaylistNameAttempt) < 60 { return }
        let candidates = playlists.filter { playlist in
            playlist.usesRemoteName && (force || playlist.remoteNameFetchedAt.map { now.timeIntervalSince($0) >= 86400 } ?? true)
        }
        let sources = candidates.compactMap(\.remoteSource).filter { !$0.requiresAuthorization || signedIn }
        guard !sources.isEmpty else { return }
        lastPlaylistNameAttempt = now; refreshingPlaylistNames = true; activeNetworkCalls += 1
        defer { refreshingPlaylistNames = false; activeNetworkCalls -= 1 }
        let epoch = accountEpoch
        playlistNameRefreshMessage = nil
        var visited = Set<String>()
        for source in sources {
            guard visited.insert(source.playlistID + String(source.requiresAuthorization)).inserted else { continue }
            do {
                try Task.checkCancellation()
                let page = try await catalog.playlistMetadata(id: source.playlistID, authorized: source.requiresAuthorization)
                try Task.checkCancellation()
                guard epoch == accountEpoch, !deletingLocalData else { return }
                for index in playlists.indices where playlists[index].remoteSource == source && playlists[index].usesRemoteName {
                    if let item = page.items.first(where: { $0.kind == .playlist && $0.id == source.playlistID }) {
                        try playlists[index].updateRemoteName(item.title, fetchedAt: page.fetchedAt)
                    } else { playlists[index].expireRemoteName(force: true) }
                }
            } catch is CancellationError { return }
            catch {
                guard epoch == accountEpoch else { return }
                playlistNameRefreshMessage = "Some playlist names could not refresh. Sign in or retry when online; your local entries are still available."
                switch error {
                case APIError.unauthorized, APIError.forbidden, APIError.unavailable:
                    for index in playlists.indices where playlists[index].remoteSource == source {
                        playlists[index].expireRemoteName(force: true)
                    }
                default: break
                }
                if case APIError.quotaExceeded = error { break }
            }
        }
    }
}

extension PublicYouTubeSession {
    func readOwnedPlaylistPage(token: String?) async throws -> MusesCatalog.CatalogPage {
        guard signedIn, !deletingLocalData, let catalog else { throw APIError.unauthorized }
        let epoch = accountEpoch
        activeNetworkCalls += 1
        defer { activeNetworkCalls -= 1 }
        let page = try await catalog.myPlaylists(pageToken: token)
        try Task.checkCancellation()
        guard epoch == accountEpoch, signedIn, !deletingLocalData else { throw CancellationError() }
        return page
    }
}
