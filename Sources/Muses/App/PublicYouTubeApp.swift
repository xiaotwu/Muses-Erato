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
    @State private var session = PublicYouTubeSession()

    var body: some Scene {
        WindowGroup {
            PublicRootView(session: session)
                .preferredColorScheme(.dark)
        }
    }
}

@main
struct PublicAppLauncher {
    static func main() {
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
    private(set) var searchItems: [MusesCatalog.CatalogItem] = []
    private(set) var playedIDs: [TrackID] = []
    private(set) var playlists: [LocalPlaylist] = []
    private(set) var searchError: String?
    private(set) var searching = false
    private(set) var signedIn = false
    private(set) var subscriptions: [MusesCatalog.CatalogItem] = []
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

    init(storeURL: URL? = nil) {
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
                    budget: RequestBudget(searchCallsPerDay: 10, otherUnitsPerDay: 100))
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
                    budget: RequestBudget(searchCallsPerDay: 10, otherUnitsPerDay: 100))
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
        guard !query.isEmpty else { searchItems = []; searchError = nil; return }
        searchItems = tracks.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.artist.localizedCaseInsensitiveContains(query) }
            .compactMap { track in
                guard case .youtubeVideo(let id) = track.source else { return nil }
                return MusesCatalog.CatalogItem(kind: .video, id: id.rawValue, title: track.title,
                    channelID: nil, thumbnailURL: nil, source: "local")
            }
        guard let catalog, apiConfigured else {
            searchError = "Online search needs a YouTube Data API key or a Google sign in. Paste a YouTube video link to play without one."
            return
        }
        searching = true
        defer { searching = false }
        do {
            let page = try await catalog.search(query)
            let savedIDs = Set(searchItems.map(\.id))
            searchItems += page.items.filter { $0.kind == .video && !savedIDs.contains($0.id) }
            searchError = nil
        } catch {
            searchError = "Online search unavailable: \(error.localizedDescription). Saved results remain available."
        }
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
            signedIn = true
            await loadSubscriptions()
        } catch { failureMessage = "Sign in failed: \(error.localizedDescription)" }
    }

    func loadSubscriptions() async {
        guard signedIn, let catalog else { return }
        do { subscriptions = try await catalog.mySubscriptions().items }
        catch { failureMessage = "Subscriptions unavailable: \(error.localizedDescription)" }
    }

    func signOut() async {
        guard let oauth else { return }
        accountEpoch &+= 1
        do { try await oauth.revokeAndDelete() }
        catch {
            failureMessage = "Local account data was removed. Google revocation may have failed; review access in your Google account settings."
        }
        signedIn = false
        subscriptions = []
        await catalog?.clearPrivateCache()
    }

    func openLink(_ text: String) async {
        guard let video = Self.videoID(from: text) else {
            failureMessage = "Enter a YouTube video link or an 11-character video ID."
            return
        }
        var title = "YouTube video \(video.rawValue)"
        if let catalog, let result = try? await catalog.videos([video.rawValue]),
           let item = result.items.first(where: { $0.id == video.rawValue }) {
            title = item.title
        }
        open(video, title: title)
    }

    nonisolated static func videoID(from input: String) -> VideoID? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let id = try? VideoID(trimmed) { return id }
        guard let url = URLComponents(string: trimmed), url.scheme == "https",
              let host = url.host?.lowercased(), ["youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be"].contains(host) else { return nil }
        let raw: String?
        if host == "youtu.be" { raw = url.path.split(separator: "/").first.map(String.init) }
        else if url.path == "/watch" { raw = url.queryItems?.first(where: { $0.name == "v" })?.value }
        else if url.path.hasPrefix("/shorts/") || url.path.hasPrefix("/embed/") { raw = url.path.split(separator: "/").last.map(String.init) }
        else { raw = nil }
        return raw.flatMap { try? VideoID($0) }
    }

    func open(_ id: VideoID, title: String) {
        guard repository != nil else { return }
        do {
            let track: MusesDomain.Track
            if let existing = tracks.first(where: { $0.source == .youtubeVideo(id) }) { track = existing }
            else {
                track = try MusesDomain.Track(id: TrackID(UUID().uuidString), title: title,
                    artist: "YouTube", source: .youtubeVideo(id),
                    provenance: Provenance(provider: ProviderID("youtube"), originalID: id.rawValue))
                try repository?.saveTrack(track)
                tracks.append(track)
            }
            guard editQueue({ try $0.playNow(QueueEntry(trackID: track.id, source: track.source), context: "public") }) else { return }
            state = PlaybackSnapshot(state: .loading, source: track.source,
                generation: queue.snapshot.generation, intent: .pause, capabilities: youtubeCapabilities)
            failureMessage = nil
            showPlayer = true
            if adapter != nil { loadCurrent() }
        } catch { failureMessage = error.localizedDescription }
    }

    func enqueue(_ id: VideoID, title: String) {
        guard repository != nil else { return }
        do {
            let track: MusesDomain.Track
            if let existing = tracks.first(where: { $0.source == .youtubeVideo(id) }) { track = existing }
            else {
                track = try MusesDomain.Track(id: TrackID(UUID().uuidString), title: title,
                    artist: "YouTube", source: .youtubeVideo(id),
                    provenance: Provenance(provider: ProviderID("youtube"), originalID: id.rawValue))
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
            proposed.setIntent(.pause)
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
        editQueue { proposed in
            for entry in proposed.snapshot.upcoming { try proposed.remove(id: entry.id) }
        }
    }

    func attach(_ player: YouTubeIFrameAdapter) {
        adapter?.teardown()
        adapter = player
        player.onEvent = { [weak self] event in self?.receive(event) }
        loadCurrent()
    }

    func detach() {
        adapter?.teardown()
        adapter = nil
        adapterGeneration = 0
        if state.state == .playing || state.state == .buffering { state.state = .paused }
        queue.setIntent(.pause)
        try? persistQueue()
    }

    private func loadCurrent() {
        guard let adapter, case .youtubeVideo(let id) = queue.snapshot.current?.source,
              let iframeID = IFrameVideoID(id.rawValue) else { return }
        adapterGeneration = adapter.load(iframeID)
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
        case .ready, .cued: state.state = .ready
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
            state.positionMilliseconds = max(0, Int(position * 1000))
            state.durationMilliseconds = max(0, Int(duration * 1000))
            queue.checkpoint(positionMilliseconds: state.positionMilliseconds)
        case .failed(let reason):
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
        guard editQueue({ _ = try $0.next() }) else { return }
        recordedEntryID = nil
        state = PlaybackSnapshot(state: .loading, source: queue.snapshot.current?.source,
            generation: queue.snapshot.generation, intent: .pause, capabilities: youtubeCapabilities)
        loadCurrent()
    }
    private func persistQueue() throws { try repository?.saveQueue(queue.snapshot) }

    func deleteLocalData() async {
        detach()
        accountEpoch &+= 1
        do {
            try await oauth?.deleteLocalAccount()
            await catalog?.clearPrivateCache()
            try repository?.deleteAll()
            playlists = []
            recordedEntryID = nil
            showPlayer = false
            tracks = []
            queue = try PlaybackQueue()
            state = PlaybackSnapshot()
            searchItems = []
            playedIDs = []
            subscriptions = []
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
