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
    var body: some View { PublicRootView(session: session) }
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
    private var accountEpoch: UInt64 = 0
    private var recordedEntryID: UUID?
    @ObservationIgnored lazy var notebook = PublicNotebookModel(repository: { [weak self] in self?.repository })
    @ObservationIgnored let bookmarkSeeking = PublicBookmarkSeekController()
    private(set) var hasCurrentPlaybackTime = false
    private(set) var bookmarkCueMilliseconds: Double?

    init(storeURL: URL? = nil, catalogOverride: YouTubeDataCatalog? = nil) {
        do {
            // The inherited autoschema remains untouched until full parity migration is verified.
            let old = storeURL?.deletingLastPathComponent().appending(path: "muses-youtube-native.sqlite") ?? musesDefaultStoreURL()
            if legacyStoreArtifactsPresent(at: old) {
                recoveryMessage = "An earlier Muses library was found. This version leaves it intact. Library migration needs verification before opening the new library."
                return
            }
            let destination = storeURL ?? old.deletingLastPathComponent().appending(path: "muses-public-v1.sqlite")
            if !FileManager.default.fileExists(atPath: destination.path), legacyStoreArtifactsPresent(at: destination) {
                recoveryMessage = "An incomplete local library was found. Its remaining files are preserved for recovery."
                return
            }
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            let container = try SwiftDataSnapshotRepository.container(url: destination)
            v1Container = container
            let repo = SwiftDataSnapshotRepository(context: container.mainContext)
            repository = repo
            tracks = try repo.list(MusesDomain.Track.self, kind: .track)
            try expireCatalogMetadata()
            playedIDs = try repo.list(PlaybackHistoryEntry.self, kind: .history).sorted { $0.date > $1.date }.map(\.trackID)
            playlists = try repo.localPlaylists()
            queue = try PlaybackQueue(snapshot: repo.queue() ?? .init())
            let savedIDs = Set(tracks.map(\.id))
            guard playlists.allSatisfy({ Set($0.trackIDs).isSubset(of: savedIDs) }),
                  tracks.allSatisfy({ if case .youtubeVideo = $0.source { return true }; return false }),
                  ([queue.snapshot.current].compactMap { $0 } + queue.snapshot.upcoming + queue.snapshot.history)
                    .allSatisfy({ entry in tracks.contains { $0.id == entry.trackID && $0.source == entry.source } }),
                  Set(playedIDs).isSubset(of: savedIDs) else { throw LocalLibraryError.missingTrack }
            if let current = queue.snapshot.current {
                state = PlaybackSnapshot(state: .paused, source: current.source,
                                         generation: queue.snapshot.generation, intent: .pause)
            }
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
                    if (try? await auth.accessToken()) != nil, self?.accountEpoch == epoch {
                        self?.signedIn = true
                    }
                }
            } else if let apiKey {
                catalog = YouTubeDataCatalog(apiKey: apiKey,
                    budget: RequestBudget(searchCallsPerDay: 10, otherUnitsPerDay: 100),
                    clientIdentity: Bundle.main.bundleIdentifier.flatMap { CatalogClientIdentity(iOSBundleID: $0) })
            }
        } catch {
            repository = nil
            recoveryMessage = "Library could not be opened. No replacement library was created. Error: \(error.localizedDescription)"
        }
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
        await accountPlaylistPages.load { token in
            guard self.signedIn, let catalog = self.catalog else { throw APIError.unauthorized }
            return try await catalog.myPlaylists(pageToken: token)
        }
    }
    func loadAccountChannel() async {
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
    }

    func expireCatalogMetadata(at date: Date = Date(), force: Bool = false) throws {
        for index in tracks.indices {
            var track = tracks[index]
            track.expireYouTubeMetadata(at: date, force: force)
            if track != tracks[index] { try repository?.saveTrack(track); tracks[index] = track; localSearchItems = [] }
        }
    }

    private(set) var refreshingMetadata = false
    func refreshSavedMetadata() async {
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
        guard let oauth, let config = oauthConfiguration,
              let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first(where: \.isKeyWindow) else {
            failureMessage = "Google iOS OAuth needs a configured client ID, redirect scheme and active window."
            return
        }
        do {
            let attempt = try OAuthAttempt(configuration: config)
            let browser = IOSAuthorizationSession(anchor: window)
            authorizationSession = browser
            defer { authorizationSession = nil }
            let callback = try await browser.authorize(attempt)
            try await oauth.complete(attempt, callback: callback)
            accountEpoch &+= 1
            resetAccountCatalog()
            signedIn = true
            await loadSubscriptions()
        } catch { failureMessage = "Sign in failed: \(error.localizedDescription)" }
    }

    func loadSubscriptions() async {
        await subscriptionPages.load { token in
            guard self.signedIn, let catalog = self.catalog else { throw APIError.unauthorized }
            return try await catalog.mySubscriptions(pageToken: token)
        }
    }

    func signOut() async {
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
        guard generation == linkGeneration, epoch == accountEpoch, !Task.isCancelled else { return }
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
    func createPlaylist(_ name: String, trackIDs: [TrackID] = []) -> Bool {
        do {
            guard let repository else { return false }
            let playlist = try LocalPlaylist(name: name, trackIDs: trackIDs)
            try repository.savePlaylist(playlist)
            playlists.append(playlist)
            failureMessage = nil
            return true
        } catch { failureMessage = "Could not create playlist: \(error.localizedDescription)"; return false }
    }

    @discardableResult
    func editPlaylist(_ id: UUID, change: (inout LocalPlaylist) throws -> Void) -> Bool {
        guard let index = playlists.firstIndex(where: { $0.id == id }), let repository else { return false }
        do {
            var value = playlists[index]
            try change(&value)
            try repository.savePlaylist(value)
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
            for id in playlist.trackIDs {
                guard let track = tracks.first(where: { $0.id == id }) else { throw LocalLibraryError.missingTrack }
                try proposed.append(QueueEntry(trackID: track.id, source: track.source))
            }
        }
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
        detach()
        accountEpoch &+= 1
        signedIn = false
        resetAccountCatalog()
        do {
            try await oauth?.deleteLocalAccount()
            await catalog?.clearPrivateCache()
            try repository?.deleteAll()
            notebook.reset()
            playlists = []
            recordedEntryID = nil
            showPlayer = false
            tracks = []
            queue = try PlaybackQueue()
            state = PlaybackSnapshot()
            localSearchItems = []; searchPages.reset()
            playedIDs = []
            resetAccountCatalog()
            signedIn = false
            failureMessage = nil
        } catch { failureMessage = "Local data could not be deleted: \(error.localizedDescription)" }
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
