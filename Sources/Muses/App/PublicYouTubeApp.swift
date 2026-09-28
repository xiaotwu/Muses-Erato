import SwiftUI
import SwiftData
import UIKit
import MusesDomain
import MusesQueue
import MusesPersistence
import MusesCatalog
import MusesNetworking
import MusesIOSOAuth

/// The App Store composition root. The inherited services are deliberately not constructed here.
@MainActor
struct PublicYouTubeApp: App {
    var body: some Scene {
        WindowGroup {
            PublicPrivacyGate { PublicConsentedAppView() }
                .preferredColorScheme(.dark)
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
    let searchPages = CatalogPager()
    let subscriptionPages = CatalogPager()
    let accountPlaylistPages = CatalogPager()
    let accountChannelPages = CatalogPager()
    var searchKind: MusesCatalog.CatalogItem.Kind = .video
    private var submittedSearch = ""
    private var submittedKind: MusesCatalog.CatalogItem.Kind = .video
    private var linkGeneration = UUID()
    var catalogRoute: YouTubeCatalogLink?
    var searchItems: [MusesCatalog.CatalogItem] { localSearchItems + searchPages.items.filter { online in !localSearchItems.contains { $0.kind == online.kind && $0.id == online.id } } }
    private var localSearchItems: [MusesCatalog.CatalogItem] = []
    private(set) var playedIDs: [TrackID] = []
    private(set) var playlists: [LocalPlaylist] = []
    private var refreshingPlaylistNames = false
    private var lastPlaylistNameAttempt: Date?
    private(set) var playlistNameRefreshMessage: String?
    var searchError: String? { searchPages.error }
    var searching: Bool { searchPages.loading }
    private(set) var signedIn = false
    var subscriptions: [MusesCatalog.CatalogItem] { subscriptionPages.items }
    var showPlayer = false
    var selectedCategory: LibraryCategory = .videos
    private var adapter: YouTubeIFrameAdapter?
    private var adapterGeneration: UInt64 = 0
    private var catalog: YouTubeDataCatalog?
    private var hasPublicAPIKey = false
    private var oauth: OAuthClient?
    private var oauthConfiguration: OAuthConfiguration?
    private var authorizationSession: IOSAuthorizationSession?
    private var activeSignIn: Task<Void, Error>?
    private var activeNetworkCalls = 0
    private var deletingLocalData = false
    private var cleanupInFlight = false
    private var accountEpoch: UInt64 = 0
    private var recordedEntryID: UUID?
    @ObservationIgnored lazy var notebook = PublicNotebookModel(repository: { [weak self] in self?.repository })
    @ObservationIgnored let bookmarkSeeking = PublicBookmarkSeekController()
    private(set) var hasCurrentPlaybackTime = false
    private(set) var bookmarkCueMilliseconds: Double?

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
         deleteCredentials: @escaping () throws -> Void = PublicCredentialDeletion.deleteAppCredentials,
         deleteWebsiteData: @escaping () async throws -> Void = { try await PublicWebsiteDataDeletion.clear() }) {
        legacyURL = storeURL?.deletingLastPathComponent().appending(path: "muses-youtube-native.sqlite") ?? musesDefaultStoreURL()
        destinationURL = storeURL ?? legacyURL.deletingLastPathComponent().appending(path: "muses-public-v1.sqlite")
        self.defaults = defaults
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
                    privateData: privateData)
                oauth = auth
                let remote = YouTubeDataCatalog(apiKey: apiKey, credential: auth,
                    budget: RequestBudget(searchCallsPerDay: 10, otherUnitsPerDay: 100),
                    clientIdentity: Bundle.main.bundleIdentifier.flatMap { CatalogClientIdentity(iOSBundleID: $0) })
                catalog = remote
                Task { await privateData.setCatalog(remote) }
                let epoch = accountEpoch
                Task { [weak self] in
                    guard let self, !self.deletingLocalData else { return }
                    self.activeNetworkCalls += 1
                    defer { self.activeNetworkCalls -= 1 }
                    if (try? await auth.accessToken()) != nil, self.accountEpoch == epoch {
                        self.signedIn = true
                        await self.refreshPlaylistNames(force: true)
                    }
                }
            } else if let apiKey {
                catalog = YouTubeDataCatalog(apiKey: apiKey,
                    budget: RequestBudget(searchCallsPerDay: 10, otherUnitsPerDay: 100),
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
                generation: queue.snapshot.generation, intent: .pause)
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
    var history: [MusesDomain.Track] {
        var seen = Set<TrackID>()
        return playedIDs.filter { seen.insert($0).inserted }.compactMap { id in tracks.first { $0.id == id } }
    }
    var favorites: [MusesDomain.Track] { tracks.filter(\.liked) }
    var apiConfigured: Bool { catalog != nil && (hasPublicAPIKey || signedIn) }
    var oauthConfigured: Bool { oauth != nil }
    var hasNext: Bool { !queue.snapshot.upcoming.isEmpty }
    var isPlayerVisible: Bool { adapter != nil }

    func search(_ input: String) async {
        guard !deletingLocalData else { return }
        activeNetworkCalls += 1
        defer { activeNetworkCalls -= 1 }
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if query == submittedSearch, submittedKind == searchKind, searchPages.loading { return }
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

    func nextSearchPage() async {
        let query = submittedSearch, kind = submittedKind
        guard !query.isEmpty else { return }
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
        await accountPlaylistPages.load { token in
            guard self.signedIn, let catalog = self.catalog else { throw APIError.unauthorized }
            return try await catalog.myPlaylists(pageToken: token)
        }
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

    private(set) var refreshingMetadata = false
    func refreshSavedMetadata() async {
        guard !deletingLocalData else { return }
        await refreshPlaylistNames(force: true)
        activeNetworkCalls += 1
        defer { activeNetworkCalls -= 1 }
        guard !refreshingMetadata else { return }
        refreshingMetadata = true
        defer { refreshingMetadata = false }
        guard let catalog, apiConfigured else { failureMessage = APIError.unauthorized.localizedDescription; return }
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
                        track.title = item.title; track.artist = "YouTube"
                        track.metadataOrigin = .youtubeDataAPI; track.metadataFetchedAt = page.fetchedAt
                    } else { track.expireYouTubeMetadata(force: true) }
                    try repository?.saveTrack(track); tracks[index] = track
                }
            }
            failureMessage = nil
        } catch { failureMessage = error.localizedDescription }
    }

    func signIn() async {
        guard !deletingLocalData else { return }
        activeNetworkCalls += 1
        defer { activeNetworkCalls -= 1 }
        guard let oauth, let config = oauthConfiguration,
              let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first(where: \.isKeyWindow) else {
            failureMessage = "Google iOS OAuth needs a configured client ID, redirect scheme and active window."
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
            await refreshPlaylistNames(force: true)
            await loadSubscriptions()
        } catch {
            if epoch == accountEpoch { failureMessage = "Sign in failed: \(error.localizedDescription)" }
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

    func signOut() async {
        guard !deletingLocalData else { return }
        activeNetworkCalls += 1
        defer { activeNetworkCalls -= 1 }
        guard let oauth else { return }
        accountEpoch &+= 1
        signedIn = false
        resetAccountCatalog()
        do { try expireCatalogMetadata(force: true) } catch { failureMessage = "Metadata could not be removed: \(error.localizedDescription)" }
        do { try await oauth.revokeAndDelete() }
        catch OAuthFailure.storage {
            failureMessage = "Account cleanup could not finish on this device. Retry when the device is unlocked and review Google account access."
        }
        catch {
            failureMessage = "Local account data was removed. Google revocation may have failed; review access in your Google account settings."
        }
        signedIn = false
        resetAccountCatalog()
        await catalog?.clearPrivateCache()
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
        var title = "YouTube video \(video.rawValue)"
        if let catalog, let result = try? await catalog.videos([video.rawValue]),
           let item = result.items.first(where: { $0.id == video.rawValue }) {
            title = item.title
            fetchedAt = item.fetchedAt
        }
        guard !deletingLocalData, generation == linkGeneration, epoch == accountEpoch, !Task.isCancelled else { return }
        open(video, title: title, metadataFetchedAt: fetchedAt)
    }

    nonisolated static func videoID(from input: String) -> VideoID? {
        guard case .video(let raw) = YouTubeCatalogLink.parse(input) else { return nil }
        return try? VideoID(raw)
    }

    @discardableResult
    func open(_ id: VideoID, title: String, metadataFetchedAt: Date? = nil) -> Bool {
        guard repository != nil else { return false }
        bookmarkSeeking.cancel()
        bookmarkCueMilliseconds = nil
        do {
            let track: MusesDomain.Track
            if let existing = tracks.first(where: { $0.source == .youtubeVideo(id) }) { track = existing }
            else {
                track = try MusesDomain.Track(id: TrackID(UUID().uuidString), title: title,
                    artist: "YouTube", source: .youtubeVideo(id),
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
            if adapter != nil { loadCurrent() }
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
        do {
            try bookmarkSeeking.prepare(entryID: entry.id, videoID: videoID, milliseconds: bookmark.timestampMilliseconds)
            bookmarkCueMilliseconds = bookmark.timestampMilliseconds
            if adapter != nil { bookmarkSeeking.bind(entryID: entry.id, generation: adapterGeneration) }
        } catch { failureMessage = error.localizedDescription }
    }

    func enqueue(_ id: VideoID, title: String, metadataFetchedAt: Date? = nil) {
        guard repository != nil else { return }
        do {
            let track: MusesDomain.Track
            if let existing = tracks.first(where: { $0.source == .youtubeVideo(id) }) { track = existing }
            else {
                track = try MusesDomain.Track(id: TrackID(UUID().uuidString), title: title,
                    artist: "YouTube", source: .youtubeVideo(id),
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
        do { try repository?.saveTrack(updated); tracks[index] = updated; failureMessage = nil }
        catch { failureMessage = error.localizedDescription }
    }

    @discardableResult
    func createPlaylist(_ name: String, trackIDs: [TrackID] = [], nameIsExplicitUserInput: Bool = false) -> Bool {
        do {
            guard let repository else { return false }
            let playlist = try LocalPlaylist(name: name, trackIDs: trackIDs)
            if nameIsExplicitUserInput { try repository.saveUserNamedPlaylist(playlist) }
            else { try repository.savePlaylist(playlist) }
            playlists.append(playlist)
            failureMessage = nil
            return true
        } catch { failureMessage = "Could not create playlist: \(error.localizedDescription)"; return false }
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
            failureMessage = nil
            return true
        } catch { failureMessage = "Could not save playlist: \(error.localizedDescription)"; return false }
    }

    @discardableResult
    func deletePlaylist(_ id: UUID) -> Bool {
        do {
            guard let repository else { return false }
            try repository.delete(kind: .localPlaylist, id: id.uuidString)
            playlists.removeAll { $0.id == id }
            failureMessage = nil
            return true
        } catch { failureMessage = error.localizedDescription; return false }
    }

    func clearHistory() {
        do { try repository?.deleteAll(kind: .history); playedIDs = []; failureMessage = nil }
        catch { failureMessage = error.localizedDescription }
    }

    /// Publish only after the proposed snapshot has been saved successfully.
    @discardableResult
    func editQueue(_ change: (inout PlaybackQueue) throws -> Void) -> Bool {
        guard let repository else { return false }
        do {
            var proposed = queue
            try change(&proposed)
            try repository.saveQueue(proposed.snapshot)
            queue = proposed
            failureMessage = nil
            return true
        } catch { failureMessage = "Could not save queue: \(error.localizedDescription)"; return false }
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
        if adapter != nil { loadCurrent() }
        return true
    }

    func clearUpcoming() {
        guard hasNext else { return }
        editQueue { proposed in
            for entry in proposed.snapshot.upcoming { try proposed.remove(id: entry.id) }
        }
    }

    func attach(_ player: YouTubeIFrameAdapter) {
        adapter?.teardown()
        adapter = player
        player.onEvent = { [weak self, weak player] event in
            guard let self, let player, self.adapter === player else { return }
            self.receive(event)
        }
        loadCurrent()
    }

    func detach() {
        adapter?.teardown()
        adapter = nil
        adapterGeneration = 0
        bookmarkSeeking.cancel()
        bookmarkCueMilliseconds = nil
        hasCurrentPlaybackTime = false
        if state.state == .playing || state.state == .buffering { state.state = .paused }
        queue.setIntent(.pause)
        try? persistQueue()
    }

    private func loadCurrent() {
        guard let adapter, case .youtubeVideo(let id) = queue.snapshot.current?.source,
              let iframeID = IFrameVideoID(id.rawValue) else { return }
        hasCurrentPlaybackTime = false
        state.positionMilliseconds = 0
        adapterGeneration = adapter.load(iframeID)
        if let entry = queue.snapshot.current { bookmarkSeeking.bind(entryID: entry.id, generation: adapterGeneration) }
        state.state = .loading
        state.generation = queue.snapshot.generation
        state.source = .youtubeVideo(id)
        state.capabilities = youtubeCapabilities
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
        guard adapter != nil, event.generation == adapterGeneration,
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
                        try persistQueue()
                    }
                } catch { failureMessage = "Bookmark position could not be prepared: \(error.localizedDescription)" }
            }
        case .cued: state.state = .ready
        case .playing:
            state.state = .playing
            queue.setIntent(.play)
            if let entryID = queue.snapshot.current?.id, recordedEntryID != entryID {
                if let track = currentTrack {
                    let entry = PlaybackHistoryEntry(id: UUID(), trackID: track.id, date: Date())
                    do {
                        try repository?.put(entry, kind: .history, id: entry.id.uuidString)
                        playedIDs.insert(track.id, at: 0)
                        recordedEntryID = entryID
                    } catch {
                        failureMessage = "Playback started, but history could not be saved: \(error.localizedDescription)"
                    }
                }
            }
        case .paused: state.state = .paused; queue.setIntent(.pause)
        case .buffering: state.state = .buffering
        case .ended: state.state = .ended; next()
        case .time(let position, let duration):
            guard position.isFinite, duration.isFinite, position >= 0, duration >= 0,
                  position * 1000 < Double(Int.max), duration * 1000 < Double(Int.max) else { return }
            hasCurrentPlaybackTime = true
            state.positionMilliseconds = max(0, Int(position * 1000))
            state.durationMilliseconds = max(0, Int(duration * 1000))
            queue.checkpoint(positionMilliseconds: state.positionMilliseconds)
        case .failed(let reason):
            bookmarkSeeking.cancel()
            hasCurrentPlaybackTime = false
            state.state = .failed
            state.failure = reason == .embeddingDisabled ? .notEmbeddable : .unavailable
            failureMessage = reason == .embeddingDisabled ? "This video does not allow embedding. Open it in YouTube." : "YouTube playback failed: \(reason)"
        }
    }

    func play() {
        do { try adapter?.play() }
        catch { failureMessage = "Player is still loading. Use its visible controls when ready." }
    }
    func pause() { adapter?.pause(); queue.setIntent(.pause); try? persistQueue() }
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
    private func persistQueue() throws { try repository?.saveQueue(queue.snapshot) }

    func deleteLocalData() async {
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
            failureMessage = "Deletion could not be recorded: \(error.localizedDescription)"
        }
    }

    private func clearVisibleLibrary() {
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
            failureMessage = recoveryMessage
            return
        }
        do {
            try PublicStoreRouter.completeExternalDeletion(destinationURL: destinationURL)
            let fresh = try PublicStoreRouter.resolve(legacyURL: legacyURL, destinationURL: destinationURL,
                defaults: defaults, domainName: defaultsDomain)
            try loadLibrary(at: fresh)
            recoveryMessage = nil
            deletingLocalData = false
            failureMessage = PublicStoreRouter.deletionNeedsRestart(destinationURL: destinationURL)
                ? "Library cleared. Restart Muses to finish removing retained migration files." : nil
            configureRemoteServices()
        } catch {
            repository = nil
            v1Container = nil
            recoveryMessage = "Deletion is recorded. Restart Muses to finish cleanup; the old library will not be imported again. \(error.localizedDescription)"
            failureMessage = recoveryMessage
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
        guard let repository else { failureMessage = "Local library is unavailable."; return false }
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
                bookmarkSeeking.cancel(); bookmarkCueMilliseconds = nil; hasCurrentPlaybackTime = false
                adapter?.teardown(); adapter = nil; adapterGeneration = 0
                recordedEntryID = nil; showPlayer = false; state = PlaybackSnapshot()
            } else { state.generation = queue.snapshot.generation }
            failureMessage = nil
            return true
        } catch { failureMessage = "Could not delete the saved video. Your library was not changed: \(error.localizedDescription)"; return false }
    }

    @discardableResult
    func removeHistoryItem(_ id: TrackID) -> Bool {
        guard let repository else { failureMessage = "Local library is unavailable."; return false }
        do {
            let history = try repository.removeLocalHistory(for: id)
            playedIDs = history.sorted { $0.date > $1.date }.map(\.trackID)
            failureMessage = nil; return true
        } catch { failureMessage = "Could not remove local history: \(error.localizedDescription)"; return false }
    }

    @discardableResult
    func removeFavorite(_ id: TrackID) -> Bool {
        guard let repository, let index = tracks.firstIndex(where: { $0.id == id }) else { return false }
        do {
            _ = try repository.removeLocalFavorite(id)
            tracks[index].liked = false
            failureMessage = nil; return true
        } catch { failureMessage = "Could not remove favorite: \(error.localizedDescription)"; return false }
    }
}


extension PublicYouTubeSession {
    func clearLibraryItems(_ category: LibraryCategory) {
        guard let repository else { failureMessage = "Local library is unavailable."; return }
        do {
            switch category {
            case .videos: _ = deleteSavedTracks(Set(tracks.map(\.id))); return
            case .songs: _ = deleteSavedTracks(Set(playlists.flatMap(\.trackIDs))); return
            case .favorites:
                _ = try repository.clearLocalFavorites()
                for index in tracks.indices { tracks[index].liked = false }
            case .playlists: try repository.deleteAll(kind: .localPlaylist); playlists = []
            case .history: try repository.deleteAll(kind: .history); playedIDs = []
            default: return
            }
            failureMessage = nil
        } catch { failureMessage = "Could not clear local items: \(error.localizedDescription)" }
    }
    func clearSearchResults() {
        searchPages.reset(); localSearchItems = []; submittedSearch = ""
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
            tracks[index].artist = "YouTube"
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
