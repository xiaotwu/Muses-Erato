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
    static func videoCount(_ count: Int) -> String { "\(count) \(count == 1 ? "video" : "videos")" }
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
    @State private var confirmingSync = false
    @AppStorage("public.library.presentation") private var libraryPresentation: PublicLibraryPresentation = .list
    @State private var libraryQuery = ""
    @State private var searchFocusRequested = false

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
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(destination.title)
                            .accessibilityAddTraits(selection == destination ? .isSelected : [])
                            .accessibilityIdentifier("public.sidebar.\(destination.title)")
                        }
                    }
                    .navigationTitle("Muses")
                    .listStyle(.sidebar)
                    .frame(minWidth: 210)
                } detail: {
                    NavigationStack { destinationContent.safeAreaInset(edge: .bottom, spacing: 0) { miniPlayer } }
                }
            } else {
                if #available(iOS 26.1, *) {
                    compactTabs(systemAccessory: true)
                        .tabViewBottomAccessory(isEnabled: (session.currentTrack != nil || session.hasNext) && !session.showPlayer) {
                            PublicMiniPlayer(session: session, systemAccessory: true)
                        }
                } else {
                    compactTabs(systemAccessory: false)
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
            else { session.suspendVisiblePlayback() }
        }
        .task(id: session.apiConfigured) { await session.hydrateDisplayMetadata() }
        .tint(PublicStyle.gold)
        .background(PublicKeyboardDismissal { linkFocused = false })
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

    private func compactTabs(systemAccessory: Bool) -> some View {
        TabView(selection: $selection) {
            NavigationStack { home.safeAreaInset(edge: .bottom, spacing: 0) { if !systemAccessory { miniPlayer } } }
                .tabItem { Label("Home", systemImage: "house") }.tag(PublicDestination.home)
            NavigationStack { search.safeAreaInset(edge: .bottom, spacing: 0) { if !systemAccessory { miniPlayer } } }
                .tabItem { Label("Search", systemImage: "magnifyingglass") }.tag(PublicDestination.search)
            NavigationStack { library.safeAreaInset(edge: .bottom, spacing: 0) { if !systemAccessory { miniPlayer } } }
                .tabItem { Label("Library", systemImage: "square.stack") }.tag(PublicDestination.library)
        }
    }

    @ViewBuilder private var miniPlayer: some View {
        if (session.currentTrack != nil || session.hasNext) && !session.showPlayer { PublicMiniPlayer(session: session) }
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
            LazyVStack(alignment: .leading, spacing: 28) {
                if let message = session.libraryFailureMessage { PublicNotice(message: message, symbol: "exclamationmark.circle") }
                if session.libraryTracks.isEmpty && session.libraryHistory.isEmpty && session.playlists.isEmpty && session.accountPlaylistPages.items.isEmpty {
                    homeStartActions
                }
                if !session.libraryHistory.isEmpty {
                    PublicHomeLibraryContent(session: session) { session.selectedCategory = .history; selection = .library }
                } else if session.playlists.isEmpty && !session.libraryTracks.isEmpty {
                    PublicHomeSavedVideos(session: session)
                }
                PublicHomeLocalPlaylists(session: session, showAll: { session.selectedCategory = .playlists; selection = .library })
                if session.signedIn { PublicHomePlaylistShelves(session: session, showAccount: { showSettings = true }) }
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(.horizontal, PublicStyle.inset).padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
        .background(PublicStyle.background)
        .task(id: session.musicHomeScope) { if session.signedIn { await session.loadHomeAccountPlaylists() } }
        .refreshable {
            if session.signedIn { await session.loadHomeAccountPlaylists(refresh: true) }
        }
        .navigationDestination(item: $session.catalogRoute) { route in PublicCatalogDetail(session: session, route: route) }
        .navigationTitle("Home").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { activeTool = .link } label: { Label("Open YouTube link", systemImage: "link") }
                        .accessibilityIdentifier("public.add.openLink")
                    Button { activeTool = .importPlaylist } label: { Label("Import playlist", systemImage: "square.and.arrow.down") }
                        .accessibilityIdentifier("public.add.import")
                    Button { playlistName = ""; creatingPlaylist = true } label: { Label("Create local playlist", systemImage: "plus.rectangle.on.folder") }
                        .accessibilityIdentifier("public.add.create")
                } label: {
                    Image(systemName: "plus").frame(minWidth: 44, minHeight: 44)
                }
                    .accessibilityLabel("Add to library")
                    .accessibilityIdentifier("public.add")
            }
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

    private var search: some View {
        PublicSearchScreen(session: session, focusRequested: $searchFocusRequested)
            .toolbar {
                settingsToolbar
            }
    }

    private var homeStartActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start your library").font(.title2.weight(.bold)).accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("home.empty")
            Text("Search for a video, or use + to open a link or import a playlist.").font(.subheadline).foregroundStyle(PublicStyle.ink)
            Button { session.searchKind = .video; searchFocusRequested = true; selection = .search } label: {
                Label("Search videos", systemImage: "magnifyingglass").foregroundStyle(PublicStyle.background)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(.borderedProminent).accessibilityIdentifier("public.start.search")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) { homeSecondaryActions }
                VStack(alignment: .leading, spacing: 4) { homeSecondaryActions }
            }
        }.padding(20).background(PublicStyle.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder private var homeSecondaryActions: some View {
        Button { activeTool = .link } label: { Label("Open link", systemImage: "link").frame(minHeight: 44).contentShape(Rectangle()) }
            .buttonStyle(.plain).accessibilityIdentifier("public.start.link")
        Button { activeTool = .importPlaylist } label: { Label("Import playlist", systemImage: "square.and.arrow.down").frame(minHeight: 44).contentShape(Rectangle()) }
            .buttonStyle(.plain).accessibilityIdentifier("public.start.import")
    }

    private var startActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { discoveryButtons }
            VStack(alignment: .leading, spacing: 8) { discoveryButtons }
        }
    }

    @ViewBuilder private var discoveryButtons: some View {
        Button { session.searchKind = .video; searchFocusRequested = true; selection = .search } label: {
            Label("Search videos", systemImage: "magnifyingglass").frame(minHeight: 44)
        }.buttonStyle(.borderedProminent).accessibilityIdentifier("public.start.search")
        Button { activeTool = .link } label: {
            Label("Open link", systemImage: "link").frame(minHeight: 44)
        }.buttonStyle(.bordered).accessibilityIdentifier("public.start.link")
        Button { activeTool = .importPlaylist } label: {
            Label("Import playlist", systemImage: "square.and.arrow.down").frame(minHeight: 44)
        }.buttonStyle(.bordered).accessibilityIdentifier("public.start.import")
    }

    private var library: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PublicLibraryCategories(session: session)
                TextField("Find in this collection", text: $libraryQuery)
                    .textFieldStyle(.roundedBorder).frame(minHeight: 44)
                    .accessibilityIdentifier("library.filter")
                HStack(spacing: 8) {
                    Text(categoryDetail).font(.subheadline).foregroundStyle(PublicStyle.ink)
                        .accessibilityIdentifier("library.itemCount")
                    Spacer(minLength: 0)
                    if !categoryTracks.isEmpty && session.selectedCategory != .playlists {
                        PublicLibraryPresentationControl(presentation: $libraryPresentation)
                    }
                    libraryClearControl
                }
                if let message = session.libraryFailureMessage { PublicNotice(message: message, symbol: "exclamationmark.circle") }
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
        .onAppear {
            if ![LibraryCategory.videos, .playlists, .favorites, .history].contains(session.selectedCategory) { session.selectedCategory = .videos }
        }
        .onChange(of: session.selectedCategory) { _, _ in libraryQuery = "" }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { confirmingSync = true }
        .alert("Sync details from YouTube?", isPresented: $confirmingSync) {
            Button("Cancel", role: .cancel) {}
            Button("Sync details") { Task { await session.refreshSavedMetadata() } }
        } message: { Text("Updates saved titles and metadata using cloud information. Local playlists and notes remain.") }
        .toolbar {
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

    @ViewBuilder private var libraryClearControl: some View {
        if collectionCount > 0 {
            PublicLibraryClearButton(session: session, category: session.selectedCategory)
        }
    }

    private var categoryTracks: [MusesDomain.Track] {
        switch session.selectedCategory {
        case .favorites: session.libraryFavorites
        case .history: session.libraryHistory
        default: session.libraryTracks
        }
    }
    private var filteredTracks: [MusesDomain.Track] {
        let term = libraryQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return term.isEmpty ? categoryTracks : categoryTracks.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(term) || $0.displayArtist.localizedCaseInsensitiveContains(term)
        }
    }
    private var collectionCount: Int { session.selectedCategory == .playlists ? session.playlists.count : categoryTracks.count }
    private var categoryDetail: String {
        if session.selectedCategory == .playlists { return "\(session.playlists.count) local \(session.playlists.count == 1 ? "playlist" : "playlists")" }
        return libraryQuery.isEmpty ? PublicStyle.videoCount(categoryTracks.count) : "\(filteredTracks.count) of \(PublicStyle.videoCount(categoryTracks.count))"
    }

    @ViewBuilder private var categoryContent: some View {
        if session.selectedCategory == .playlists {
            let lists = session.playlists.filter { libraryQuery.isEmpty || $0.name.localizedCaseInsensitiveContains(libraryQuery) }
            if session.playlists.isEmpty {
                PublicEmptyState(symbol: "music.note.list", title: "No local playlists", detail: "Import a YouTube playlist or create a playlist on this device.")
                Button("Create playlist", systemImage: "plus") { playlistName = ""; creatingPlaylist = true }
                    .frame(minHeight: 44).buttonStyle(.bordered)
                startActions
            } else if lists.isEmpty {
                noFilterMatches
            } else {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(lists) { playlist in PublicPlaylistBlock(session: session, playlist: playlist) }
                }.task { await session.refreshPlaylistNames() }
            }
        } else if categoryTracks.isEmpty {
            PublicEmptyState(symbol: session.selectedCategory.symbol, title: emptyLibraryTitle, detail: emptyLibraryDetail)
            startActions
        } else if filteredTracks.isEmpty {
            noFilterMatches
        } else {
            PublicLibraryHeroShelf(session: session, tracks: filteredTracks, category: session.selectedCategory, presentation: $libraryPresentation)
        }
    }
    private var emptyLibraryTitle: String {
        switch session.selectedCategory {
        case .favorites: "No favorites yet"
        case .history: "No playback history"
        default: "No saved videos"
        }
    }
    private var emptyLibraryDetail: String {
        switch session.selectedCategory {
        case .favorites: "Open a video and choose Favorite. Favorites stay here without a playlist."
        case .history: "Videos appear after the player confirms playback."
        default: "Open a video link or import a playlist to save videos on this device."
        }
    }
    private var noFilterMatches: some View {
        VStack(alignment: .leading, spacing: 12) {
            PublicEmptyState(symbol: "magnifyingglass", title: "No matching saved items", detail: "Try another title or creator in this collection.")
            Button("Clear filter") { libraryQuery = "" }.frame(minHeight: 44)
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

struct PublicNotice: View {
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

struct PublicEmptyState: View {
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
                .foregroundStyle(PublicStyle.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(PublicStyle.surface, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct PublicVideoArtwork: View {
    let videoID: String
    var body: some View { PublicCompactHeroCover(videoID: videoID) }
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
        }.tint(PublicStyle.gold)
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
            if let message = session.queueFailureMessage {
                PublicNotice(message: message, symbol: "exclamationmark.circle")
            }
            if let message = session.playbackError, message != session.playbackCheckpoint.failure {
                PublicNotice(message: message, symbol: "exclamationmark.circle")
                ViewThatFits(in: .horizontal) {
                    HStack { playbackRecoveryActions }
                    VStack(alignment: .leading) { playbackRecoveryActions }
                }
            }
            if let message = session.playbackCheckpoint.failure {
                PublicNotice(message: message, symbol: "externaldrive.badge.exclamationmark")
                Button("Retry saving position", systemImage: "arrow.clockwise") { session.retryPlaybackCheckpoint() }
                    .frame(minHeight: 44).accessibilityIdentifier("public.retryCheckpoint")
            }
            if session.isPlaybackCommandPending {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(session.playbackToggleLabel).font(.subheadline)
                }.accessibilityElement(children: .combine)
                    .accessibilityIdentifier("public.playbackCommandPending")
            }
            if let message = session.playbackCommands.failure {
                PublicNotice(message: message, symbol: "exclamationmark.circle")
                if session.canRetryPlaybackCommand {
                    Button("Retry control action", systemImage: "arrow.clockwise") { session.retryPlaybackCommand() }
                        .frame(minHeight: 44).accessibilityIdentifier("public.retryPlaybackCommand")
                }
            }
            VStack(spacing: 8) {
                let duration = Double(session.state.durationMilliseconds ?? 0) / 1000
                let position = Double(session.state.positionMilliseconds) / 1000
                Slider(value: Binding(get: { scrubbing ? scrubPosition : min(position, max(1, duration)) }, set: { scrubPosition = $0 }), in: 0...max(1, duration), onEditingChanged: { editing in
                    if editing { scrubPosition = position; scrubbing = true }
                    else { scrubbing = false; session.seekPlayback(seconds: scrubPosition) }
                }).disabled(!session.hasCurrentPlaybackTime || duration <= 0).accessibilityLabel("Playback position")
                HStack(spacing: 16) {
                    if let track = session.currentTrack { PublicCurrentBookmarkButton(session: session, trackID: track.id) }
                    Spacer(minLength: 0)
                    Button { session.togglePlayback() } label: {
                        Image(systemName: session.state.state == .playing || session.state.state == .buffering ? "pause.fill" : "play.fill").font(.system(size: 36)).frame(width: 64, height: 64)
                    }.disabled(session.state.capabilities.isEmpty || session.isPlaybackCommandPending)
                        .accessibilityLabel(session.playbackToggleLabel)
                        .accessibilityIdentifier("public.playbackToggle")
                    Button { session.next() } label: { Image(systemName: "forward.end.fill").font(.title2).frame(width: 44, height: 44) }
                        .disabled(!session.hasNext).accessibilityLabel("Next")
                    PublicQueueControl(session: session, identifier: "player.queue")
                    Spacer(minLength: 0)
                }.buttonStyle(.plain)
            }

            .accessibilityElement(children: .contain)
        }
    }

    @ViewBuilder private var playbackRecoveryActions: some View {
        Button("Retry playback", systemImage: "arrow.clockwise") { session.retryPlayback() }
            .buttonStyle(.borderedProminent).frame(minHeight: 44)
            .disabled(!session.canRetryPlayback).accessibilityIdentifier("public.retryPlayback")
        if let video = session.currentTrack?.publicVideoID,
           let url = URL(string: "https://www.youtube.com/watch?v=\(video.rawValue)") {
            Button("Open YouTube", systemImage: "arrow.up.right") { openURL(url) }
                .buttonStyle(.bordered).frame(minHeight: 44).accessibilityIdentifier("public.openYouTube")
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
                                Button { if let video = track.publicVideoID { session.open(video, title: track.title, artist: track.artist) } } label: {
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
                                Button { if let video = track.publicVideoID { session.open(video, title: track.title, artist: track.artist) } } label: {
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
            if let message = session.queueFailureMessage { Text(message).foregroundStyle(.red) }
            if let message = session.failureMessage, message != session.queueFailureMessage { Text(message).foregroundStyle(.red) }
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

/// Local presentation also works from the iOS tab accessory, outside a NavigationStack.
struct PublicQueueControl: View {
    let session: PublicYouTubeSession
    var identifier = "public.queue"
    @State private var showingQueue = false
    @State private var openPlayerAfterDismissal = false

    var body: some View {
        Button { showingQueue = true } label: {
            PublicIconActionLabel(title: "Queue", symbol: "list.bullet")
        }
        .buttonStyle(.plain)
        .accessibilityValue("\(session.queue.snapshot.upcoming.count) upcoming")
        .accessibilityIdentifier(identifier)
        .sheet(isPresented: $showingQueue, onDismiss: {
            if openPlayerAfterDismissal {
                openPlayerAfterDismissal = false
                session.showPlayer = true
            }
        }) {
            NavigationStack {
                PublicQueueView(session: session, onOpenPlayer: {
                    openPlayerAfterDismissal = !session.showPlayer
                    showingQueue = false
                })
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { showingQueue = false }
                                .accessibilityLabel("Close Queue").accessibilityIdentifier("player.queue.close")
                        }
                    }
            }
        }
    }
}

struct PublicQueueView: View {
    let session: PublicYouTubeSession
    var onOpenPlayer: (() -> Void)? = nil
    @State private var removedEntries: [UUID] = []
    @State private var confirmingRemoval = false
    var body: some View {
        List {
            if let current = session.currentTrack {
                Section("Now playing") {
                    HStack {
                        PublicQueueTrackLabel(track: current)
                        Spacer()
                        Button {
                            if let onOpenPlayer { onOpenPlayer() } else { session.showPlayer = true }
                        } label: { PublicIconActionLabel(title: "Open visible player", symbol: "play.fill") }
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
            if let message = session.queueFailureMessage { Text(message).foregroundStyle(.red) }
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
        HStack(spacing: 12) {
            PublicCompactHeroCover(videoID: track?.publicVideoID?.rawValue)
            VStack(alignment: .leading, spacing: 4) {
                Text(track?.displayTitle ?? "Unavailable song").font(.subheadline.weight(.medium)).lineLimit(2).accessibilityIdentifier(identifier)
                Text(track?.displayArtist ?? "Unknown artist").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
