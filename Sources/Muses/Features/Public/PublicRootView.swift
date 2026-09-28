import SwiftUI
import UIKit
import MusesDomain
import MusesCatalog
import MusesQueue

enum PublicStyle {
    static let gold = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.82, green: 0.68, blue: 0.44, alpha: 1)
            : UIColor(red: 0.47, green: 0.36, blue: 0.17, alpha: 1)
    })
    static let background = Color(uiColor: .systemBackground)
    static let surface = Color(uiColor: .secondarySystemBackground)
    static let ink = Color(uiColor: .label)
    static let muted = Color(uiColor: .secondaryLabel)
    static let inset: CGFloat = 20
}

private enum PublicDestination: Int, CaseIterable, Identifiable {
    case home, search, library

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .home: "Home"
        case .search: "Search"
        case .library: "Library"
        }
    }
    var symbol: String {
        switch self {
        case .home: "house"
        case .search: "magnifyingglass"
        case .library: "square.stack"
        }
    }
}

struct PublicRootView: View {
    @Bindable var session: PublicYouTubeSession
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: PublicDestination = .home
    private enum Tool: String, Identifiable { case link, importPlaylist; var id: String { rawValue } }
    @State private var activeTool: Tool?
    @State private var creatingPlaylist = false
    @State private var playlistName = ""
    @State private var showSettings = false
    @State private var link = ""
    @FocusState private var linkFocused: Bool
    @FocusState private var searchFocused: Bool
    @State private var query = ""
    @State private var musicHome = PublicMusicHomeModel()
    @State private var confirmingSync = false

    var body: some View {
        Group {
            if let recovery = session.recoveryMessage {
                ContentUnavailableView(
                    "Library needs attention",
                    systemImage: "externaldrive.badge.exclamationmark",
                    description: Text(recovery)
                )
                .padding()
            } else if sizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
                NavigationSplitView {
                    List {
                        ForEach(PublicDestination.allCases) { destination in
                            Button {
                                selection = destination
                            } label: {
                                Label(destination.title, systemImage: destination.symbol)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .listRowBackground(
                                selection == destination ? PublicStyle.gold.opacity(0.15) : Color.clear
                            )
                            .accessibilityAddTraits(selection == destination ? .isSelected : [])
                        }
                    }
                    .navigationTitle("Muses")
                    .listStyle(.sidebar)
                    .frame(minWidth: 210)
                } detail: {
                    NavigationStack { destinationContent.safeAreaInset(edge: .bottom, spacing: 0) { miniPlayer } }
                }
            } else {
                TabView(selection: $selection) {
                    NavigationStack { home.safeAreaInset(edge: .bottom, spacing: 0) { miniPlayer } }
                        .tabItem { Label("Home", systemImage: "house") }
                        .tag(PublicDestination.home)
                    NavigationStack { search.safeAreaInset(edge: .bottom, spacing: 0) { miniPlayer } }
                        .tabItem { Label("Search", systemImage: "magnifyingglass") }
                        .tag(PublicDestination.search)
                    NavigationStack { library.safeAreaInset(edge: .bottom, spacing: 0) { miniPlayer } }
                        .tabItem { Label("Library", systemImage: "square.stack") }
                        .tag(PublicDestination.library)
                }
            }
        }
        .task {
            while !Task.isCancelled {
                await session.maintainCatalogData()
                await session.hydrateDisplayMetadata()
                do { try await Task.sleep(for: .seconds(3600)) } catch { break }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await session.maintainCatalogData(); await session.hydrateDisplayMetadata() } }
        }
        .task(id: session.apiConfigured) { await session.hydrateDisplayMetadata() }
        .tint(PublicStyle.gold)
        .background(PublicKeyboardDismissal { linkFocused = false; searchFocused = false })
        .sheet(isPresented: $showSettings) {
            NavigationStack { settings }
                .tint(PublicStyle.gold)
                .fullScreenCover(isPresented: $session.showPlayer) {
                    PublicPlayerView(session: session)
                }
        }
        .sheet(item: $activeTool) { tool in
            switch tool {
            case .link: linkSheet
            case .importPlaylist: PublicPlaylistImportView(session: session)
            }
        }
        .alert("Create local playlist", isPresented: $creatingPlaylist) {
            TextField("Playlist name", text: $playlistName)
            Button("Create") { session.createPlaylist(playlistName, nameIsExplicitUserInput: true) }
                .disabled(playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: Binding(
            get: { session.showPlayer && !showSettings },
            set: { session.showPlayer = $0 }
        )) {
            PublicPlayerView(session: session)
        }
    }

    @ViewBuilder private var miniPlayer: some View {
        if session.currentTrack != nil && !session.showPlayer { PublicMiniPlayer(session: session) }
    }

    @ViewBuilder
    private var destinationContent: some View {
        switch selection {
        case .home: home
        case .search: search
        case .library: library
        }
    }

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let message = session.failureMessage { PublicNotice(message: message, symbol: "exclamationmark.circle") }
                if let current = session.currentTrack {
                    sectionHeading("Continue", detail: "")
                    Button { session.showPlayer = true } label: {
                        PublicVideoRow(track: current, symbol: "play.fill")
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("public.resume")
                }
                if !session.libraryHistory.isEmpty {
                    HStack {
                        sectionHeading("Recently played", detail: "")
                        Button("See all") { session.selectedCategory = .history; selection = .library }
                            .font(.subheadline).frame(minHeight: 44)
                    }
                    videoShelf(session.libraryHistory.prefix(6))
                } else if session.libraryTracks.isEmpty {
                    PublicEmptyState(symbol: "square.stack", title: "Your Muses Home", detail: "Open a YouTube link or import a playlist to get started.")
                }
                if !session.libraryFavorites.isEmpty {
                    sectionHeading("Favorites", detail: "")
                    videoShelf(session.libraryFavorites.prefix(6))
                }
                if !session.libraryTracks.isEmpty {
                    sectionHeading("From your playlists", detail: "")
                    videoShelf(session.libraryTracks.prefix(6))
                }
                if session.signedIn {
                    if !session.accountPlaylistPages.items.isEmpty {
                        sectionHeading("Your YouTube playlists", detail: "")
                        ForEach(session.accountPlaylistPages.items.prefix(6), id: \.rowID) {
                            PublicCatalogRow(session: session, item: $0, authorized: true)
                        }
                    }
                    if session.accountPlaylistPages.loading { ProgressView("Loading account playlists") }
                    if let error = session.accountPlaylistPages.error {
                        PublicNotice(message: error, symbol: "exclamationmark.circle")
                        Button("Retry account playlists") { Task { await session.loadAccountCollections() } }
                    }
                }
                PublicMusicHomeShelves(session: session, model: musicHome)
                sectionHeading("Browse", detail: "")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                    discoveryTile("Live sessions", symbol: "music.mic", query: "live music sessions")
                    discoveryTile("New music", symbol: "sparkles.tv", query: "new music videos")
                    discoveryTile("Performances", symbol: "theatermasks", query: "music performances")
                    discoveryTile("Conversations", symbol: "mic", query: "music interviews")
                }
                if !session.apiConfigured {
                    PublicNotice(message: "Online discovery is unavailable. Saved videos and YouTube links still work.", symbol: "wifi.slash")
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(.horizontal, PublicStyle.inset).padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
        .background(PublicStyle.background)
        .task(id: session.musicHomeScope) { await musicHome.load(session: session) }
        .task(id: session.signedIn) { if session.signedIn { await session.loadAccountCollections() } }
        .refreshable {
            await musicHome.load(session: session, refresh: true)
            if session.signedIn { await session.loadAccountCollections() }
        }
        .navigationDestination(item: $session.catalogRoute) { route in PublicCatalogDetail(session: session, route: route) }
        .navigationTitle("Home").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { activeTool = .link } label: { PublicIconActionLabel(title: "Open YouTube link", symbol: "link") }
                    .accessibilityIdentifier("public.openLinkEntry")
            }
            queueToolbar
            settingsToolbar
        }
    }

    private var linkSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    linkCard
                    Text("Paste a YouTube video link or video ID.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .accessibilityIdentifier("public.linkHelp")
                }.padding(20)
            }
            .navigationTitle("Open link").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { activeTool = nil } label: { PublicIconActionLabel(title: "Done", symbol: "xmark") }
                }
            }
            .background(PublicKeyboardDismissal { linkFocused = false })
        }.presentationDetents([.medium, .large])
    }

    private var linkCard: some View {
        HStack(spacing: 12) {
            TextField("YouTube link or video ID", text: $link)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.URL)
                .submitLabel(.go)
                .focused($linkFocused)
                .onSubmit(openLink)
                .frame(minHeight: 44)
                .accessibilityIdentifier("public.link")
            Button(action: openLink) {
                PublicIconActionLabel(title: "Open link", symbol: "arrow.up.right")
            }
            .buttonStyle(.borderedProminent)
            .disabled(link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("public.open")
        }
        .padding(12)
        .background(PublicStyle.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func openLink() {
        linkFocused = false
        activeTool = nil
        Task { await session.openLink(link) }
    }

    private func discoveryTile(_ title: String, symbol: String, query term: String) -> some View {
        Button {
            query = term
            selection = .search
            Task { await session.search(term) }
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 12)
                .background(PublicStyle.surface, in: RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search YouTube for \(term)")
    }

    private var search: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(PublicStyle.muted)
                    TextField("Search YouTube", text: $query)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .focused($searchFocused)
                        .onSubmit(submitSearch)
                        .accessibilityIdentifier("public.search")
                    Button(action: submitSearch) { PublicIconActionLabel(title: "Search YouTube", symbol: "magnifyingglass") }
                    .buttonStyle(.borderedProminent)
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.searching)
                }
                .padding(15)
                .background(PublicStyle.surface, in: RoundedRectangle(cornerRadius: 14))
                Picker("Search type", selection: $session.searchKind) {
                    Text("Videos").tag(MusesCatalog.CatalogItem.Kind.video)
                    Text("Playlists").tag(MusesCatalog.CatalogItem.Kind.playlist)
                    Text("Channels").tag(MusesCatalog.CatalogItem.Kind.channel)
                }
                .pickerStyle(.segmented).accessibilityIdentifier("public.searchKind")
                .onChange(of: session.searchKind) { _, _ in
                    if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { submitSearch() }
                }
                if session.searching {
                    ProgressView("Searching YouTube")
                }
                if !session.apiConfigured {
                    PublicNotice(
                        message: "Online search is unavailable. Saved videos and YouTube links still work.",
                        symbol: "wifi.slash"
                    )
                }
                if let error = session.searchError {
                    PublicNotice(message: error, symbol: "exclamationmark.circle")
                        .accessibilityIdentifier("public.searchError")
                }
                Text(session.searchItems.isEmpty ? "Results" : "\(session.searchItems.count) results")
                    .font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("public.searchResultsHeading")
                if session.searchItems.isEmpty && !session.searching {
                    PublicEmptyState(
                        symbol: "magnifyingglass",
                        title: "Nothing to show yet",
                        detail: "Enter a title or artist, then submit your search."
                    )
                }
                LazyVStack(spacing: 0) {
                    ForEach(session.searchItems, id: \.rowID) { item in
                        PublicCatalogRow(session: session, item: item)
                    }
                }
                if session.searchPages.loaded || session.searchPages.error != nil {
                    PublicCatalogPaging(page: session.searchPages) { await session.nextSearchPage() }
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(.horizontal, PublicStyle.inset)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
        .background(PublicStyle.background)
        .navigationTitle("Search")
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            queueToolbar
            ToolbarItem(placement: .topBarTrailing) {
                Button { query = ""; session.clearSearchResults() } label: { PublicIconActionLabel(title: "Clear search", symbol: "trash") }
                    .disabled(query.isEmpty && session.searchItems.isEmpty && !session.searching)
                    .accessibilityIdentifier("public.clearSearch")
            }
            settingsToolbar
        }
    }

    private func submitSearch() {
        searchFocused = false
        Task { await session.search(query) }
    }

    private var library: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PublicLibraryCategories(session: session)
                HStack(spacing: 8) {
                    Text(categoryDetail).font(.subheadline).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    libraryClearControl
                }
                if let message = session.failureMessage { PublicNotice(message: message, symbol: "exclamationmark.circle") }
                if session.selectedCategory == .playlists, let message = session.playlistNameRefreshMessage {
                    PublicNotice(message: message, symbol: "exclamationmark.circle")
                }
                categoryContent
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(.horizontal, PublicStyle.inset)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
        .background(PublicStyle.background)
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { confirmingSync = true }
        .alert("Sync details from YouTube?", isPresented: $confirmingSync) {
            Button("Cancel", role: .cancel) {}
            Button("Sync details") { Task { await session.refreshSavedMetadata() } }
        } message: { Text("Updates saved titles and metadata using cloud information. Local playlists and notes remain.") }
        .toolbar {
            queueToolbar
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { activeTool = .importPlaylist } label: { Label("Import playlists", systemImage: "square.and.arrow.down") }
                        .accessibilityIdentifier("library.importPlaylist")
                    Button { playlistName = ""; creatingPlaylist = true } label: { Label("Create playlist", systemImage: "plus") }
                        .accessibilityIdentifier("public.createPlaylist")
                } label: { PublicIconActionLabel(title: "Add playlist", symbol: "plus") }
                    .accessibilityIdentifier("library.add")
            }
            settingsToolbar
        }
    }

    private struct LibraryQueueControl: View {
        let session: PublicYouTubeSession
        @State private var confirming = false
        var body: some View {
            Menu {
                NavigationLink { PublicQueueView(session: session) } label: {
                    Label("Open Queue", systemImage: "list.bullet")
                }
                Button("Clear Up Next", systemImage: "text.badge.minus", role: .destructive) { confirming = true }
                    .disabled(!session.hasNext)
            } label: {
                PublicIconActionLabel(title: "Queue", symbol: "list.bullet")
            }
            .accessibilityValue("\(session.queue.snapshot.upcoming.count) upcoming")
            .accessibilityIdentifier("public.queue")
            .alert("Clear all upcoming videos?", isPresented: $confirming) {
                Button("Clear Up Next", role: .destructive) { session.clearUpcoming() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Your current video and playback are kept. Only upcoming videos are removed.") }
        }
    }

    @ToolbarContentBuilder private var queueToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) { LibraryQueueControl(session: session) }
    }

    @ViewBuilder private var libraryClearControl: some View {
        if [.videos, .songs, .favorites, .playlists, .history].contains(session.selectedCategory) {
            PublicLibraryClearButton(session: session, category: session.selectedCategory)
                .accessibilityHint(categoryDetail)
        }
    }

    private var playlistSongs: [MusesDomain.Track] { session.libraryTracks }

    private var categoryDetail: String {
        switch session.selectedCategory {
        case .videos: "\(session.libraryTracks.count) videos"
        case .songs: "\(playlistSongs.count) songs"
        case .favorites: "\(session.libraryFavorites.count) favorites"
        case .playlists: "\(session.playlists.count) local playlists"
        case .history: "\(session.libraryHistory.count) played"
        case .subscriptions: session.signedIn ? "\(session.subscriptions.count) loaded" : "Sign in required"
        default: "Unavailable in this version"
        }
    }

    @ViewBuilder
    private var categoryContent: some View {
        switch session.selectedCategory {
        case .videos:
            if session.libraryTracks.isEmpty {
                PublicEmptyState(symbol: "play.rectangle", title: "No playlist videos", detail: "Import a playlist or add a video to a playlist.")
            } else {
                PublicLibraryHeroShelf(session: session, tracks: session.libraryTracks, category: session.selectedCategory)
            }
        case .songs:
            let songs = playlistSongs
            if songs.isEmpty {
                PublicEmptyState(symbol: "music.note", title: "No playlist songs", detail: "Import a playlist or add saved videos to a playlist.")
            } else {
                PublicLibraryHeroShelf(session: session, tracks: songs, category: .songs)
            }
        case .favorites:
            if session.libraryFavorites.isEmpty {
                PublicEmptyState(symbol: "heart", title: "No favorites yet", detail: "Open a saved video and choose Favorite.")
            } else {
                PublicLibraryHeroShelf(session: session, tracks: session.libraryFavorites, category: .favorites)
            }
        case .playlists:
            PublicPlaylistCollection(session: session)
        case .history:
            if session.libraryHistory.isEmpty {
                PublicEmptyState(symbol: "clock", title: "No listening history", detail: "Videos appear after the official player confirms playback.")
            } else {
                PublicLibraryHeroShelf(session: session, tracks: session.libraryHistory, category: .history)
            }
        case .subscriptions:
            if session.signedIn {
                if session.subscriptions.isEmpty {
                    PublicEmptyState(symbol: "person.crop.rectangle.stack", title: "No subscriptions loaded", detail: "Refresh to read subscriptions from your YouTube account.")
                }
                ForEach(session.subscriptions, id: \.rowID) { item in
                    PublicCatalogRow(session: session, item: item)
                }
                PublicCatalogPaging(page: session.subscriptionPages, initialTitle: "Load subscriptions") { await session.loadSubscriptions() }
            } else {
                PublicEmptyState(symbol: "person.crop.rectangle.stack", title: "Sign in to see subscriptions", detail: "A configured Google account grants read-only access to your YouTube subscriptions.")
                Button("Account settings") { showSettings = true }
                    .buttonStyle(.bordered)
            }
        default:
            PublicEmptyState(
                symbol: session.selectedCategory.symbol,
                title: "\(session.selectedCategory.rawValue) are not available",
                detail: "This category needs account data or an official YouTube endpoint that this public version does not support."
            )
        }
    }

    private func videoShelf<S: Sequence>(_ tracks: S) -> some View where S.Element == MusesDomain.Track {
        LazyVStack(spacing: 10) {
            ForEach(Array(tracks), id: \.id) { track in
                NavigationLink {
                    PublicVideoDetail(session: session, trackID: track.id)
                } label: {
                    PublicVideoRow(track: track, symbol: track.liked ? "heart.fill" : "play.rectangle")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sectionHeading(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(PublicStyle.ink)
            Spacer()
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(PublicStyle.muted)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    @ToolbarContentBuilder
    private var settingsToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Settings")
        }
    }

    private var settings: some View {
        PublicSettingsView(session: session)
    }

}

extension LibraryCategory {
    var symbol: String {
        switch self {
        case .artists: "person.2"
        case .albums: "square.stack"
        case .songs: "music.note"
        case .favorites: "heart"
        case .videos: "play.rectangle"
        case .podcasts: "mic"
        case .subscriptions: "person.crop.rectangle.stack"
        case .playlists: "music.note.list"
        case .history: "clock.arrow.circlepath"
        }
    }
}

private struct PublicPageHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var identifier: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(PublicStyle.gold)
            Text(title)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(PublicStyle.ink)
                .accessibilityIdentifier(identifier ?? "public.pageHeading")
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(PublicStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PublicNotice: View {
    let message: String
    let symbol: String

    var body: some View {
        Label(message, systemImage: symbol)
            .font(.subheadline)
            .foregroundStyle(PublicStyle.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .background(PublicStyle.gold.opacity(0.13), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct PublicEmptyState: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(PublicStyle.gold)
            Text(title)
                .font(.headline)
                .foregroundStyle(PublicStyle.ink)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(PublicStyle.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(PublicStyle.surface, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct PublicVideoArtwork: View {
    let videoID: String

    var body: some View {
        AsyncImage(url: URL(string: "https://i.ytimg.com/vi/\(videoID)/mqdefault.jpg")) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Rectangle()
                    .fill(PublicStyle.gold.opacity(0.15))
                    .overlay {
                        Image(systemName: "play.rectangle")
                            .foregroundStyle(PublicStyle.gold)
                    }
            }
        }
        .frame(width: 88, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .accessibilityHidden(true)
    }
}

private struct PublicVideoRow: View {
    let track: MusesDomain.Track
    let symbol: String

    var body: some View {
        HStack(spacing: 13) {
            if case .youtubeVideo(let id) = track.source {
                PublicVideoArtwork(videoID: id.rawValue)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(track.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PublicStyle.ink)
                    .lineLimit(2)
                Text(track.displayArtist)
                    .font(.caption)
                    .foregroundStyle(PublicStyle.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: symbol)
                .foregroundStyle(PublicStyle.gold)
                .accessibilityHidden(true)
        }
        .padding(10)
        .background(PublicStyle.surface, in: RoundedRectangle(cornerRadius: 15))
        .accessibilityElement(children: .combine)
    }
}

private struct PublicIFrameSurface: UIViewRepresentable {
    let adapter: YouTubeIFrameAdapter
    func makeUIView(context: Context) -> UIView { adapter.view }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

private struct PublicPlayerView: View {
    let session: PublicYouTubeSession
    var body: some View {
        if session.nativePlaybackEnabled { PublicNativePlayerView(session: session) }
        else { PublicWebPlayerView(session: session) }
    }
}

private struct PublicWebPlayerView: View {
    @Bindable var session: PublicYouTubeSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var scrubPosition = 0.0
    @State private var scrubbing = false
    @State private var adapter: YouTubeIFrameAdapter?
    @State private var confirmingFavoriteRemoval = false
    @State private var removedEntries: [UUID] = []
    @State private var confirmingRemoval = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let wide = sizeClass == .regular && geometry.size.width > 800
                Group {
                    if wide {
                        HStack(alignment: .top, spacing: 0) {
                            playerColumn
                                .frame(maxWidth: .infinity)
                            Rectangle()
                                .fill(PublicStyle.muted.opacity(0.2))
                                .frame(width: 1)
                            queueColumn
                                .frame(width: min(360, geometry.size.width * 0.35))
                        }
                    } else {
                        VStack(spacing: 0) {
                            videoSurface
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                            ScrollView {
                                VStack(alignment: .leading, spacing: 22) {
                                    playerDetails
                                    queueSection
                                    if let track = session.currentTrack {
                                        PublicNotebookContent(session: session, trackID: track.id)
                                    }
                                }
                                .padding(20)
                            }
                        }
                    }
                }
                .background(PublicStyle.background)
            }
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { PublicIconActionLabel(title: "Close player", symbol: "chevron.down") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if let track = session.currentTrack {
                            PublicAddToPlaylistMenu(session: session, track: track)
                            if case .youtubeVideo(let id) = track.source,
                               let url = URL(string: "https://www.youtube.com/watch?v=\(id.rawValue)") {
                                Button("Website playback", systemImage: "safari") { openURL(url) }
                            }
                        }
                    } label: { PublicIconActionLabel(title: "Playback actions", symbol: "ellipsis") }
                }
            }
            .alert("Remove this favorite?", isPresented: $confirmingFavoriteRemoval) {
            Button("Cancel", role: .cancel) {}
                Button("Remove favorite", role: .destructive) { if session.currentTrack?.liked == true { session.toggleFavorite() } }
            }
            .alert("Remove this queue entry?", isPresented: $confirmingRemoval) {
            Button("Cancel", role: .cancel) {}
                Button("Remove entry", role: .destructive) {
                    let existing = Set(session.queue.snapshot.upcoming.map(\.id))
                    session.editQueue { queue in for id in removedEntries where existing.contains(id) { try queue.remove(id: id) } }
                }
            }
            .onAppear {
                let created = YouTubeIFrameFactory.make()
                adapter = created
                session.attach(created)
            }
            .onDisappear {
                session.detach()
                adapter = nil
            }
        }
    }

    private var playerColumn: some View {
        VStack(spacing: 0) {
            videoSurface
                .frame(maxWidth: 800)
                .padding(24)
            ScrollView {
                playerDetails
                    .frame(maxWidth: 750, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
    }

    private var videoSurface: some View {
        Group {
            if let adapter {
                PublicIFrameSurface(adapter: adapter)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .frame(minHeight: 200)
                    .background(.black)
                    .accessibilityLabel("Visible YouTube player")
                    .accessibilityIdentifier("public.iframe")
            } else {
                ProgressView("Preparing YouTube player")
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
            }
        }
    }

    private var playerDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                Text(session.currentTrack?.displayTitle ?? "Now Playing")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(PublicStyle.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(session.state.state.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(PublicStyle.muted)
                    .accessibilityIdentifier("public.playbackState")
                }
                Spacer(minLength: 0)
                Button {
                    if session.currentTrack?.liked == true { confirmingFavoriteRemoval = true } else { session.toggleFavorite() }
                } label: {
                    PublicIconActionLabel(title: session.currentTrack?.liked == true ? "Remove favorite" : "Favorite",
                        symbol: session.currentTrack?.liked == true ? "heart.fill" : "heart")
                }
            }
            if let message = session.failureMessage {
                PublicNotice(message: message, symbol: "exclamationmark.circle")
            }
            VStack(spacing: 8) {
                let duration = Double(session.state.durationMilliseconds ?? 0) / 1000
                let position = Double(session.state.positionMilliseconds) / 1000
                Slider(value: Binding(get: { scrubbing ? scrubPosition : min(position, max(1, duration)) }, set: { scrubPosition = $0 }), in: 0...max(1, duration), onEditingChanged: { editing in
                    if editing { scrubPosition = position; scrubbing = true }
                    else { scrubbing = false; session.seekPlayback(seconds: scrubPosition) }
                }).disabled(!session.hasCurrentPlaybackTime || duration <= 0).accessibilityLabel("Playback position")
                HStack(spacing: 24) {
                    if let track = session.currentTrack { PublicCurrentBookmarkButton(session: session, trackID: track.id) }
                    Spacer(minLength: 0)
                    Button { session.state.state == .playing ? session.pause() : session.play() } label: {
                        Image(systemName: session.state.state == .playing ? "pause.fill" : "play.fill").font(.system(size: 36)).frame(width: 64, height: 64)
                    }.disabled(session.state.capabilities.isEmpty)
                        .accessibilityLabel(session.state.state == .playing ? "Pause" : "Play")
                    Button { session.next() } label: { Image(systemName: "forward.end.fill").font(.title2).frame(width: 44, height: 44) }
                        .disabled(!session.hasNext).accessibilityLabel("Next")
                    Spacer(minLength: 0)
                }.buttonStyle(.plain)
            }

            .accessibilityElement(children: .contain)
        }
    }

    private var queueColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                queueSection
                if let track = session.currentTrack {
                    PublicNotebookContent(session: session, trackID: track.id)
                }
            }.padding(20)
        }
        .background(PublicStyle.surface)
    }

    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Up next · \(session.queue.snapshot.upcoming.count)")
                    .font(.headline)
                    .foregroundStyle(PublicStyle.ink)
                Spacer()
                PublicClearUpNextButton(session: session)
            }
            if session.queue.snapshot.upcoming.isEmpty {
                Text("The queue is empty. Add a video from Search.")
                    .font(.subheadline)
                    .foregroundStyle(PublicStyle.muted)
            } else {
                ForEach(session.queue.snapshot.upcoming) { entry in
                    HStack {
                        PublicQueueTrackLabel(track: session.tracks.first { $0.id == entry.trackID })
                        Menu("Queue actions", systemImage: "ellipsis.circle") {
                            Button("Move to next") { session.editQueue { try $0.reorder(id: entry.id, to: 0) } }
                            Button("Remove from queue", role: .destructive) { removedEntries = [entry.id]; confirmingRemoval = true }
                        }
                    }
                    .padding(12)
                    .background(PublicStyle.background, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

private struct PublicPlaylistCollection: View {
    let session: PublicYouTubeSession
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if session.playlists.isEmpty {
                PublicEmptyState(symbol: "music.note.list", title: "No local playlists", detail: "Use + to import or create a playlist.")
            }
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(session.playlists) { playlist in
                    PublicPlaylistBlock(session: session, playlist: playlist)
                        .tint(Color(red: 0.82, green: 0.68, blue: 0.44))
                }
            }
        }.task { await session.refreshPlaylistNames() }
    }
}

struct PublicPlaylistDetail: View {
    let session: PublicYouTubeSession
    let playlistID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var renaming = false
    @State private var deleting = false
    @State private var clearing = false
    @State private var adding = false
    @State private var name = ""
    @State private var removedOccurrences: [UUID] = []
    @State private var removedTracks: [TrackID] = []
    @State private var confirmingRemoval = false
    private var playlist: LocalPlaylist? { session.playlists.first { $0.id == playlistID } }

    var body: some View {
        List {
            if let playlist {
                Section {
                    PublicActionGroup {
                        Button {
                            if session.playPlaylist(playlistID) { session.showPlayer = true }
                        } label: { PublicTextActionLabel(title: "Play", symbol: "play.fill") }
                            .disabled(playlist.trackIDs.isEmpty)
                        Button { adding = true } label: { PublicTextActionLabel(title: "Add videos", symbol: "plus") }
                        Button { session.enqueuePlaylist(playlistID) } label: { PublicIconActionLabel(title: "Add playlist to queue", symbol: "text.badge.plus") }
                            .disabled(playlist.trackIDs.isEmpty)
                    }
                }
                Section("Videos · \(playlist.entryCount)") {
                    if playlist.entryCount == 0 {
                        Text("This playlist is empty. Add videos from your saved collection.").foregroundStyle(.secondary)
                    }
                    if let occurrences = playlist.occurrences {
                        ForEach(occurrences) { occurrence in
                            if let id = occurrence.trackID, let track = session.tracks.first(where: { $0.id == id }) {
                                NavigationLink { PublicVideoDetail(session: session, trackID: id) } label: {
                                    PublicVideoRow(track: track, symbol: "play.rectangle")
                                }.accessibilityIdentifier("playlist.occurrence.\(occurrence.id)")
                            } else {
                                Label("Unavailable playlist entry", systemImage: "exclamationmark.circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { indices in
                            removedOccurrences = indices.map { occurrences[$0].id }; removedTracks = []; confirmingRemoval = true
                        }
                        .onMove { indices, destination in
                            var ids = occurrences.map(\.id)
                            ids.move(fromOffsets: indices, toOffset: destination)
                            session.editPlaylist(playlistID) { try $0.reorderOccurrences(ids) }
                        }
                    } else {
                        ForEach(playlist.trackIDs, id: \.self) { id in
                            if let track = session.tracks.first(where: { $0.id == id }) {
                                NavigationLink { PublicVideoDetail(session: session, trackID: id) } label: {
                                    PublicVideoRow(track: track, symbol: "play.rectangle")
                                }
                            }
                        }
                        .onDelete { indices in
                            removedTracks = indices.map { playlist.trackIDs[$0] }; removedOccurrences = []; confirmingRemoval = true
                        }
                        .onMove { indices, destination in
                            var ids = playlist.trackIDs
                            ids.move(fromOffsets: indices, toOffset: destination)
                            session.editPlaylist(playlistID) { try $0.reorder(ids) }
                        }
                    }
                }
            }
            if let message = session.failureMessage { Text(message).foregroundStyle(.red) }
        }
        .navigationTitle(playlist?.name ?? "Playlist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
                Menu {
                    Button("Rename playlist", systemImage: "pencil") {
                        name = playlist?.name ?? ""; renaming = true
                    }
                    Button("Add videos", systemImage: "plus") { adding = true }
                    Button("Clear videos", systemImage: "list.bullet.rectangle", role: .destructive) { clearing = true }
                        .disabled(playlist?.entryCount == 0)
                        .accessibilityIdentifier("playlist.clear")
                    Button("Delete playlist", systemImage: "trash", role: .destructive) { deleting = true }
                } label: { PublicIconActionLabel(title: "Playlist actions", symbol: "ellipsis") }
                .accessibilityIdentifier("playlist.actions")
            }
        }
        .alert("Remove selected playlist entries?", isPresented: $confirmingRemoval) {
            Button("Cancel", role: .cancel) {}
            Button("Remove entries", role: .destructive) {
                session.editPlaylist(playlistID) { value in
                    removedOccurrences.forEach { value.removeOccurrence($0) }; removedTracks.forEach { value.remove($0) }
                }
            }
        } message: { Text("Only these local playlist entries are removed. YouTube is unchanged.") }
        .confirmationDialog("Clear this local playlist?", isPresented: $clearing, titleVisibility: .visible) {
            Button("Clear playlist videos", role: .destructive) {
                session.editPlaylist(playlistID) { $0.removeAllEntries() }
            }
        } message: { Text("Saved videos remain. YouTube is unchanged.") }
        .alert("Rename playlist", isPresented: $renaming) {
            TextField("Playlist name", text: $name)
            Button("Save") { session.editPlaylist(playlistID, nameIsExplicitUserInput: name.trimmingCharacters(in: .whitespacesAndNewlines) != playlist?.name) { try $0.rename(name) } }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this local playlist?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete playlist", role: .destructive) { if session.deletePlaylist(playlistID) { dismiss() } }
        } message: { Text("Saved videos and favorites will remain.") }
        .sheet(isPresented: $adding) {
            NavigationStack {
                List {
                    if session.tracks.isEmpty { Text("No saved videos. Open a YouTube link on Home first.") }
                    ForEach(session.tracks) { track in
                        Button {
                            session.editPlaylist(playlistID) { $0.add(track.id) }
                        } label: {
                            Label(track.title, systemImage: playlist?.trackIDs.contains(track.id) == true ? "checkmark.circle.fill" : "plus.circle")
                        }
                        .disabled(playlist?.trackIDs.contains(track.id) == true)
                    }
                    if let message = session.failureMessage { Text(message) }
                }
                .navigationTitle("Add saved videos")
                .toolbar { Button { adding = false } label: { PublicIconActionLabel(title: "Done", symbol: "xmark") } }
            }
        }
    }
}

struct PublicAddToPlaylistMenu: View {
    let session: PublicYouTubeSession
    let track: MusesDomain.Track
    @State private var creating = false
    @State private var name = ""
    var body: some View {
        Menu("Add to playlist", systemImage: "text.badge.plus") {
            ForEach(session.playlists) { playlist in
                Button(playlist.trackIDs.contains(track.id) ? "✓ \(playlist.name)" : playlist.name) {
                    session.editPlaylist(playlist.id) { $0.add(track.id) }
                }.disabled(playlist.trackIDs.contains(track.id))
            }
            Button("Create local playlist") { name = ""; creating = true }
        }
        .alert("Create local playlist", isPresented: $creating) {
            TextField("Playlist name", text: $name)
            Button("Create") {
                session.createPlaylist(name, trackIDs: [track.id], nameIsExplicitUserInput: true)
            }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct PublicVideoDetail: View {
    let session: PublicYouTubeSession
    let trackID: TrackID
    @Environment(\.dismiss) private var dismiss
    @State private var deleting = false
    @State private var removingFavorite = false
    private var track: MusesDomain.Track? { session.tracks.first { $0.id == trackID } }
    var body: some View {
        List {
            if let track {
                Section {
                    HStack(spacing: 12) {
                        if case .youtubeVideo(let id) = track.source { PublicVideoArtwork(videoID: id.rawValue) }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(track.displayTitle).font(.headline)
                            Text(track.displayArtist).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    PublicActionGroup {
                        if case .youtubeVideo(let id) = track.source {
                            Button { session.open(id, title: track.title) } label: { PublicIconActionLabel(title: "Open visible player", symbol: "play.fill") }
                        }
                        Button { if track.liked { removingFavorite = true } else { session.toggleFavorite(trackID) } } label: {
                            PublicIconActionLabel(title: track.liked ? "Remove favorite" : "Favorite", symbol: track.liked ? "heart.fill" : "heart")
                        }
                        PublicAddToPlaylistMenu(session: session, track: track)
                            .labelStyle(.titleAndIcon).frame(minHeight: 44)
                    }
                }
                PublicNotebookSections(session: session, trackID: trackID)
            }
            if let message = session.failureMessage { Text(message).foregroundStyle(.red) }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let track {
                    Menu {
                        Button("Play next", systemImage: "text.line.first.and.arrowtriangle.forward") { session.enqueueTrack(track, next: true) }
                        Button("Add to queue", systemImage: "text.badge.plus") { session.enqueueTrack(track) }
                        NavigationLink { PublicQueueView(session: session) } label: { Label("View queue", systemImage: "list.bullet") }
                        if case .youtubeVideo(let id) = track.source {
                            Link(destination: URL(string: "https://www.youtube.com/watch?v=\(id.rawValue)")!) {
                                Label("Website playback", systemImage: "safari")
                            }
                        }
                        Button("Delete saved video", systemImage: "trash", role: .destructive) { deleting = true }
                    } label: { PublicIconActionLabel(title: "Video actions", symbol: "ellipsis") }
                    .accessibilityIdentifier("video.actions")
                }
            }
        }
        .alert("Remove this favorite?", isPresented: $removingFavorite) {
            Button("Cancel", role: .cancel) {}
            Button("Remove favorite", role: .destructive) { session.removeFavorite(trackID) }
        }
        .confirmationDialog("Delete this saved video?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete saved video", role: .destructive) {
                if session.deleteSavedTrack(trackID) { dismiss() }
            }
        } message: {
            Text("Removes this video and its local playlist, queue, history, note and bookmark entries. Retained originals are removed by deleting all local data.")
        }
    }
}

struct PublicQueueView: View {
    let session: PublicYouTubeSession
    @State private var removedEntries: [UUID] = []
    @State private var confirmingRemoval = false
    var body: some View {
        List {
            if let current = session.currentTrack {
                Section("Now playing") {
                    HStack {
                        PublicQueueTrackLabel(track: current)
                        Spacer()
                        Button { session.showPlayer = true } label: { PublicIconActionLabel(title: "Open visible player", symbol: "play.fill") }
                    }.buttonStyle(.borderless)
                }
            }
            Section {
                if session.queue.snapshot.upcoming.isEmpty {
                    Text("The queue is empty. Add videos from video details or a local playlist.").foregroundStyle(.secondary)
                }
                ForEach(session.queue.snapshot.upcoming) { entry in
                    HStack {
                        PublicQueueTrackLabel(track: session.tracks.first { $0.id == entry.trackID }, identifier: "queue.entry.\(entry.id)")
                        Menu {
                            Button("Move to next", systemImage: "text.line.first.and.arrowtriangle.forward") {
                                session.editQueue { try $0.reorder(id: entry.id, to: 0) }
                            }
                            Button("Remove from queue", systemImage: "minus.circle", role: .destructive) {
                                removedEntries = [entry.id]; confirmingRemoval = true
                            }
                        } label: { PublicIconActionLabel(title: "Queue actions", symbol: "ellipsis") }
                    }
                }
                .onDelete { indices in
                    removedEntries = indices.map { session.queue.snapshot.upcoming[$0].id }; confirmingRemoval = true
                }
                .onMove { indices, destination in
                    var entries = session.queue.snapshot.upcoming
                    entries.move(fromOffsets: indices, toOffset: destination)
                    session.editQueue { queue in
                        for (index, entry) in entries.enumerated() { try queue.reorder(id: entry.id, to: index) }
                    }
                }
            } header: {
                HStack {
                    Text("Up next · \(session.queue.snapshot.upcoming.count)")
                    Spacer()
                    PublicClearUpNextButton(session: session)
                }
            }
            if let message = session.failureMessage { Text(message).foregroundStyle(.red) }
        }
        .alert("Remove selected queue entries?", isPresented: $confirmingRemoval) {
            Button("Cancel", role: .cancel) {}
            Button("Remove entries", role: .destructive) {
                let existing = Set(session.queue.snapshot.upcoming.map(\.id))
                session.editQueue { queue in for id in removedEntries where existing.contains(id) { try queue.remove(id: id) } }
            }
        } message: { Text("The current item keeps playing.") }
        .navigationTitle("Queue")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
    }
}

/// Shared action keeps the same scope and confirmation at all queue entry points.
private struct PublicClearUpNextButton: View {
    let session: PublicYouTubeSession
    @State private var confirming = false

    var body: some View {
        Button("Clear Up Next", systemImage: "trash", role: .destructive) { confirming = true }
            .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
            .disabled(!session.hasNext)
            .accessibilityIdentifier("public.clearUpNext")
            .alert("Clear all upcoming videos?", isPresented: $confirming) {
                Button("Clear Up Next", role: .destructive) { session.clearUpcoming() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your current video and playback are kept. Only upcoming videos are removed.")
            }
    }
}

private struct PublicQueueTrackLabel: View {
    let track: MusesDomain.Track?
    var identifier = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(track?.displayTitle ?? "Unavailable song").font(.subheadline.weight(.medium)).lineLimit(2).accessibilityIdentifier(identifier)
            Text(track?.displayArtist ?? "Unknown artist").font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
