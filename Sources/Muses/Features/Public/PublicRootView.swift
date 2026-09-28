import SwiftUI
import UIKit
import MusesDomain
import MusesCatalog
import MusesQueue

private enum PublicStyle {
    static let gold = Color(red: 0.82, green: 0.68, blue: 0.44)
    static let background = Color(uiColor: .systemBackground)
    static let surface = Color(uiColor: .secondarySystemBackground)
    static let ink = Color(uiColor: .label)
    static let muted = Color(uiColor: .secondaryLabel)
    static let inset: CGFloat = 22
}

private enum PublicDestination: Int, CaseIterable, Identifiable {
    case home, discover, search, library, settings

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .home: "Home"
        case .discover: "Discover"
        case .search: "Search"
        case .library: "Library"
        case .settings: "Settings"
        }
    }
    var symbol: String {
        switch self {
        case .home: "house"
        case .discover: "square.grid.2x2"
        case .search: "magnifyingglass"
        case .library: "square.stack"
        case .settings: "gearshape"
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
    @State private var showSettings = false
    @State private var link = ""
    @FocusState private var linkFocused: Bool
    @FocusState private var searchFocused: Bool
    @State private var query = ""
    @State private var confirmDelete = false
    @State private var didRefreshLibraryMetadata = false

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
                    NavigationStack { destinationContent }
                }
            } else {
                TabView(selection: $selection) {
                    NavigationStack { home }
                        .tabItem { Label("Home", systemImage: "house") }
                        .tag(PublicDestination.home)
                    NavigationStack { discover }
                        .tabItem { Label("Discover", systemImage: "square.grid.2x2") }
                        .tag(PublicDestination.discover)
                    NavigationStack { search }
                        .tabItem { Label("Search", systemImage: "magnifyingglass") }
                        .tag(PublicDestination.search)
                    NavigationStack { library }
                        .tabItem { Label("Library", systemImage: "square.stack") }
                        .tag(PublicDestination.library)
                }
            }
        }
        .task {
            while !Task.isCancelled {
                await session.maintainCatalogData()
                do { try await Task.sleep(for: .seconds(3600)) } catch { break }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await session.maintainCatalogData() } }
        }
        .tint(PublicStyle.gold)
        .background(PublicKeyboardDismissal { linkFocused = false; searchFocused = false })
        .sheet(isPresented: $showSettings) {
            NavigationStack { settings }
                .fullScreenCover(isPresented: $session.showPlayer) {
                    PublicPlayerView(session: session)
                }
        }
        .fullScreenCover(isPresented: Binding(
            get: { session.showPlayer && !showSettings },
            set: { session.showPlayer = $0 }
        )) {
            PublicPlayerView(session: session)
        }
    }

    @ViewBuilder
    private var destinationContent: some View {
        switch selection {
        case .home: home
        case .discover: discover
        case .search: search
        case .library: library
        case .settings: settings
        }
    }

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                linkCard

                if let message = session.failureMessage {
                    PublicNotice(message: message, symbol: "exclamationmark.circle")
                }

                if let current = session.currentTrack {
                    sectionHeading("Continue", detail: "")
                    Button {
                        session.showPlayer = true
                    } label: {
                        PublicVideoRow(track: current, symbol: "play.rectangle.fill")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("public.resume")
                }

                if !session.favorites.isEmpty {
                    sectionHeading("Favorites", detail: "\(session.favorites.count) saved")
                    videoShelf(session.favorites.prefix(6))
                }

                sectionHeading("Recently saved", detail: "")
                if session.tracks.isEmpty {
                    PublicEmptyState(
                        symbol: "square.stack",
                        title: "No saved videos",
                        detail: "Open a YouTube link to start your library."
                    )
                } else {
                    videoShelf(session.tracks.reversed().prefix(8))
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(.horizontal, PublicStyle.inset)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
        }
        .background(PublicStyle.background)
        .navigationDestination(item: $session.catalogRoute) { route in
            PublicCatalogDetail(session: session, route: route)
        }
        .navigationTitle("Home")
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { settingsToolbar }
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
        Task { await session.openLink(link) }
    }

    private var discover: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if !session.apiConfigured {
                    PublicNotice(
                        message: "Online discovery is unavailable. Saved videos and YouTube links still work.",
                        symbol: "wifi.slash"
                    )
                }
                NavigationLink { PublicYouTubeAccountCatalog(session: session) } label: {
                    PublicTextActionLabel(title: "Account & YouTube collections", symbol: "person.crop.circle")
                }
                sectionHeading("Explore", detail: "")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                    discoveryTile("Live sessions", symbol: "music.mic", query: "live music sessions")
                    discoveryTile("New music", symbol: "sparkles.tv", query: "new music videos")
                    discoveryTile("Performances", symbol: "theatermasks", query: "music performances")
                    discoveryTile("Conversations", symbol: "mic", query: "music interviews")
                }
                if !session.history.isEmpty {
                    sectionHeading("Recently played", detail: "")
                    videoShelf(session.history.prefix(6))
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(.horizontal, PublicStyle.inset)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
        }
        .background(PublicStyle.background)
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { settingsToolbar }
    }

    private func discoveryTile(_ title: String, symbol: String, query term: String) -> some View {
        Button {
            query = term
            selection = .search
            Task { await session.search(term) }
        } label: {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(PublicStyle.gold)
                Text(title)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(PublicStyle.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            .background(PublicStyle.surface, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search YouTube for \(term)")
    }

    private var search: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
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
                PublicActionGroup {
                Picker("Search type", selection: $session.searchKind) {
                    Text("Videos").tag(MusesCatalog.CatalogItem.Kind.video)
                    Text("Playlists").tag(MusesCatalog.CatalogItem.Kind.playlist)
                    Text("Channels").tag(MusesCatalog.CatalogItem.Kind.channel)
                }.pickerStyle(.menu).frame(minHeight: 44)
                    Button {
                        query = ""; session.clearSearchResults()
                    } label: { PublicTextActionLabel(title: "Clear search", symbol: "xmark.circle") }
                    .disabled(query.isEmpty && session.searchItems.isEmpty && !session.searching)
                    .accessibilityIdentifier("public.clearSearch")
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
                sectionHeading("Results", detail: session.searchItems.isEmpty ? "" : "\(session.searchItems.count) items")
                if session.searchItems.isEmpty && !session.searching {
                    PublicEmptyState(
                        symbol: "magnifyingglass",
                        title: "Nothing to show yet",
                        detail: "Enter a title or artist, then submit your search."
                    )
                }
                LazyVStack(spacing: 10) {
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
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
        }
        .background(PublicStyle.background)
        .navigationTitle("Search")
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { settingsToolbar }
    }

    private func submitSearch() {
        searchFocused = false
        Task { await session.search(query) }
    }

    private var library: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) {
                        libraryTools.fixedSize(horizontal: true, vertical: false)
                        PublicLibraryCategories(session: session).frame(minWidth: 260)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        libraryTools
                        PublicLibraryCategories(session: session)
                    }
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
        .task(id: session.apiConfigured) {
            guard session.apiConfigured, !didRefreshLibraryMetadata else { return }
            didRefreshLibraryMetadata = true
            await session.refreshSavedMetadata()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { settingsToolbar }
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
                Label("Queue", systemImage: "list.bullet").frame(minHeight: 44)
            }
            .labelStyle(.titleAndIcon)
            .accessibilityValue("\(session.queue.snapshot.upcoming.count) upcoming")
            .accessibilityIdentifier("public.queue")
            .alert("Clear all upcoming videos?", isPresented: $confirming) {
                Button("Clear Up Next", role: .destructive) { session.clearUpcoming() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Your current video and playback are kept. Only upcoming videos are removed.") }
        }
    }

    private var libraryNavigationTools: some View {
        HStack(spacing: 12) {
            LibraryQueueControl(session: session)
            Button { Task { await session.refreshSavedMetadata() } } label: {
                PublicIconActionLabel(title: "Refresh library details", symbol: "arrow.clockwise")
            }
            .disabled(!session.apiConfigured || session.refreshingMetadata || (session.tracks.isEmpty && session.playlists.isEmpty))
            .accessibilityIdentifier("library.refresh")
        }
    }

    @ViewBuilder private var libraryClearControl: some View {
        if [.videos, .songs, .favorites, .playlists, .history].contains(session.selectedCategory) {
            HStack(spacing: 2) {
                Text("Clear \(session.selectedCategory.rawValue.lowercased())")
                    .font(.caption).foregroundStyle(.secondary).accessibilityHidden(true)
                PublicLibraryClearButton(session: session, category: session.selectedCategory)
                    .accessibilityHint(categoryDetail)
            }
        }
    }

    private var libraryTools: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) { libraryNavigationTools; libraryClearControl }
            } else {
                HStack(spacing: 12) { libraryNavigationTools; libraryClearControl; Spacer(minLength: 0) }
            }
        }
    }

    private var playlistSongs: [MusesDomain.Track] {
        let available = Dictionary(uniqueKeysWithValues: session.tracks.map { ($0.id, $0) })
        var seen = Set<TrackID>()
        return session.playlists.flatMap(\.trackIDs).compactMap { id in
            guard seen.insert(id).inserted else { return nil }
            return available[id]
        }
    }

    private var categoryDetail: String {
        switch session.selectedCategory {
        case .videos: "\(session.tracks.count) saved videos"
        case .songs: "\(playlistSongs.count) videos from playlists"
        case .favorites: "\(session.favorites.count) saved"
        case .playlists: "\(session.playlists.count) local playlists"
        case .history: "\(session.history.count) played"
        case .subscriptions: session.signedIn ? "\(session.subscriptions.count) loaded" : "Sign in required"
        default: "Unavailable in this version"
        }
    }

    @ViewBuilder
    private var categoryContent: some View {
        switch session.selectedCategory {
        case .videos:
            if session.tracks.isEmpty {
                PublicEmptyState(symbol: "play.rectangle", title: "No saved videos", detail: "Open a YouTube link on Home to start your collection.")
            } else {
                PublicLibraryHeroShelf(session: session, tracks: session.tracks, category: session.selectedCategory)
            }
        case .songs:
            let songs = playlistSongs
            if songs.isEmpty {
                PublicEmptyState(symbol: "music.note", title: "No playlist songs", detail: "Import a playlist or add saved videos to a playlist.")
            } else {
                PublicLibraryHeroShelf(session: session, tracks: songs, category: .songs)
            }
        case .favorites:
            if session.favorites.isEmpty {
                PublicEmptyState(symbol: "heart", title: "No favorites yet", detail: "Open a saved video and choose Favorite.")
            } else {
                PublicLibraryHeroShelf(session: session, tracks: session.favorites, category: .favorites)
            }
        case .playlists:
            PublicPlaylistCollection(session: session)
        case .history:
            if session.history.isEmpty {
                PublicEmptyState(symbol: "clock", title: "No listening history", detail: "Videos appear after the official player confirms playback.")
            } else {
                PublicLibraryHeroShelf(session: session, tracks: session.history, category: .history)
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
                .font(.system(.title2, design: .serif, weight: .semibold))
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
        List {
            Section("Support & privacy") {
                VStack(alignment: .leading, spacing: 8) {
                    NavigationLink { PublicPrivacyView() } label: {
                        PublicTextActionLabel(title: "Privacy policy", symbol: "hand.raised.square")
                    }
                    PublicServiceLinks()
                }
            }
            Section("YouTube account") {
                if session.accountCleanupPending {
                    Text("Account cleanup is pending. Google sign-in is blocked until cleanup finishes.")
                        .foregroundStyle(.secondary)
                    Button { Task { await session.retryAccountCleanup() } } label: {
                        PublicTextActionLabel(title: "Retry account cleanup", symbol: "arrow.clockwise")
                    }
                } else if session.signedIn {
                    Text("Signed in · Read-only access").foregroundStyle(.secondary)
                    PublicActionGroup {
                        NavigationLink { PublicYouTubeAccountCatalog(session: session) } label: {
                            PublicTextActionLabel(title: "Collections", symbol: "person.crop.circle")
                        }.accessibilityLabel("Account & YouTube collections")
                        Button { Task { await session.signOut() } } label: {
                            PublicTextActionLabel(title: "Sign out", symbol: "rectangle.portrait.and.arrow.right")
                        }.accessibilityLabel("Sign out and revoke access")
                    }
                } else if session.oauthConfigured {
                    Button { Task { await session.signIn() } } label: {
                        PublicTextActionLabel(title: "Sign in with Google", symbol: "person.crop.circle.badge.plus")
                    }
                } else {
                    Text("Google sign-in is unavailable. Your local library still works.").foregroundStyle(.secondary)
                }
            }
            Section {
                PublicActionGroup {
                    Button { Task { await session.refreshSavedMetadata() } } label: {
                        PublicTextActionLabel(title: "Refresh details", symbol: "arrow.clockwise")
                    }.disabled(session.refreshingMetadata)
                    Button(role: .destructive) { confirmDelete = true } label: {
                        PublicTextActionLabel(title: "Delete local data", symbol: "trash")
                    }
                }
            } header: { Text("Local data") } footer: {
                Text("Deletion includes notes, bookmarks and retained originals. YouTube is unchanged.")
            }
            Section("Playback") {
                Text("Playback pauses when you close the player or leave Muses. Background audio, EQ, spectrum, lock screen controls and CarPlay are unavailable.")
                    .foregroundStyle(.secondary)
            }
            if let message = session.failureMessage {
                Section("Notice") { Text(message) }
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            if sizeClass != .regular || dynamicTypeSize.isAccessibilitySize {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = false } label: { PublicIconActionLabel(title: "Done", symbol: "xmark") }
                }
            }
        }
        .confirmationDialog("Delete local Muses data?", isPresented: $confirmDelete) {
            Button("Delete local data", role: .destructive) { Task { await session.deleteLocalData() } }
        } message: {
            Text("Deletes local videos, playlists, queue, history, notes, bookmarks, account credentials and retained originals. Restart if cleanup is pending. Your YouTube account and videos are unaffected.")
        }
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
                .font(.system(.largeTitle, design: .serif, weight: .semibold))
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
                .font(.system(.headline, design: .serif))
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
                Text(track.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PublicStyle.ink)
                    .lineLimit(2)
                Text(track.artist)
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
    @Bindable var session: PublicYouTubeSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var adapter: YouTubeIFrameAdapter?

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
                    Button("Close") { dismiss() }
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
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text(session.currentTrack?.title ?? "YouTube video")
                    .font(.system(.title2, design: .serif, weight: .semibold))
                    .foregroundStyle(PublicStyle.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(session.state.state.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(PublicStyle.muted)
                    .accessibilityIdentifier("public.playbackState")
            }
            if let message = session.failureMessage {
                PublicNotice(message: message, symbol: "exclamationmark.circle")
            }
            HStack(spacing: 10) {
                Button { session.play() } label: { Label("Play", systemImage: "play.fill") }
                    .disabled(session.state.capabilities.isEmpty)
                Button { session.pause() } label: { Label("Pause", systemImage: "pause.fill") }
                    .disabled(session.state.capabilities.isEmpty)
                Button { session.next() } label: { Label("Next", systemImage: "forward.end.fill") }
                    .disabled(!session.hasNext)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .labelStyle(.iconOnly)
            .accessibilityElement(children: .contain)
            Button {
                session.toggleFavorite()
            } label: {
                Label(
                    session.currentTrack?.liked == true ? "Remove favorite" : "Favorite",
                    systemImage: session.currentTrack?.liked == true ? "heart.fill" : "heart"
                )
            }
            .buttonStyle(.bordered)
            if case .youtubeVideo(let id) = session.currentTrack?.source,
               let url = URL(string: "https://www.youtube.com/watch?v=\(id.rawValue)") {
                Button("Open in YouTube", systemImage: "arrow.up.right.square") {
                    openURL(url)
                }
                .buttonStyle(.bordered)
            }
            if let track = session.currentTrack {
                PublicAddToPlaylistMenu(session: session, track: track)
                PublicCurrentBookmarkButton(session: session, trackID: track.id)
            }
            Text("YouTube playback pauses when this screen closes or Muses enters the background.")
                .font(.footnote)
                .foregroundStyle(PublicStyle.muted)
        }
    }

    private var queueColumn: some View {
        ScrollView {
            queueSection
                .padding(20)
        }
        .background(PublicStyle.surface)
    }

    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Up next")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(PublicStyle.ink)
            PublicClearUpNextButton(session: session)
            if session.queue.snapshot.upcoming.isEmpty {
                Text("The queue is empty. Add a video from Search.")
                    .font(.subheadline)
                    .foregroundStyle(PublicStyle.muted)
            } else {
                ForEach(session.queue.snapshot.upcoming) { entry in
                    HStack {
                        Text(session.tracks.first(where: { $0.id == entry.trackID })?.title ?? "YouTube video")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Menu("Queue actions", systemImage: "ellipsis.circle") {
                            Button("Move to next") { session.editQueue { try $0.reorder(id: entry.id, to: 0) } }
                            Button("Remove from queue", role: .destructive) { session.editQueue { try $0.remove(id: entry.id) } }
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
    @State private var importing = false
    @State private var creating = false
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) { importAction; createAction }
                    .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 8) { importAction; createAction }
            }
            if session.playlists.isEmpty {
                PublicEmptyState(symbol: "music.note.list", title: "No local playlists", detail: "Create a playlist, then add videos from your saved collection.")
            }
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(session.playlists) { playlist in
                    PublicPlaylistBlock(session: session, playlist: playlist)
                }
            }
        }
        .task { await session.refreshPlaylistNames() }
        .sheet(isPresented: $importing) { PublicPlaylistImportView(session: session) }
        .alert("Create local playlist", isPresented: $creating) {
            TextField("Playlist name", text: $name)
            Button("Create") { session.createPlaylist(name, nameIsExplicitUserInput: true) }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var importAction: some View {
        Button { importing = true } label: {
            Label("Import playlists", systemImage: "square.and.arrow.down").frame(minHeight: 44)
        }
        .accessibilityLabel("Import YouTube Music or account playlist")
        .accessibilityIdentifier("library.importPlaylist")
    }
    private var createAction: some View {
        Button { name = ""; creating = true } label: {
            Label("Create playlist", systemImage: "plus").frame(minHeight: 44)
        }
        .accessibilityIdentifier("public.createPlaylist")
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
    private var playlist: LocalPlaylist? { session.playlists.first { $0.id == playlistID } }

    var body: some View {
        List {
            if let playlist {
                Section {
                    PublicActionGroup {
                        Button { adding = true } label: { PublicTextActionLabel(title: "Add videos", symbol: "plus") }
                        Button { session.enqueuePlaylist(playlistID) } label: { PublicIconActionLabel(title: "Add playlist to queue", symbol: "text.badge.plus") }
                            .disabled(playlist.trackIDs.isEmpty)
                        Button { clearing = true } label: { PublicTextActionLabel(title: "Clear videos", symbol: "xmark.circle") }
                            .disabled(playlist.entryCount == 0)
                            .accessibilityIdentifier("playlist.clear")
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
                            let removed = indices.map { occurrences[$0].id }
                            session.editPlaylist(playlistID) { value in removed.forEach { value.removeOccurrence($0) } }
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
                            let removed = indices.map { playlist.trackIDs[$0] }
                            session.editPlaylist(playlistID) { value in removed.forEach { value.remove($0) } }
                        }
                        .onMove { indices, destination in
                            var ids = playlist.trackIDs
                            ids.move(fromOffsets: indices, toOffset: destination)
                            session.editPlaylist(playlistID) { try $0.reorder(ids) }
                        }
                    }
                }
                Section {
                    PublicActionGroup {
                        Button { name = playlist.name; renaming = true } label: { PublicIconActionLabel(title: "Rename playlist", symbol: "pencil") }
                        Button(role: .destructive) { deleting = true } label: { PublicIconActionLabel(title: "Delete playlist", symbol: "trash") }
                    }
                }
            }
            if let message = session.failureMessage { Text(message).foregroundStyle(.red) }
        }
        .navigationTitle(playlist?.name ?? "Playlist")
        .toolbar { EditButton() }
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

private struct PublicAddToPlaylistMenu: View {
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
    private var track: MusesDomain.Track? { session.tracks.first { $0.id == trackID } }
    var body: some View {
        List {
            if let track {
                Section {
                    Text(track.title).font(.title2)
                    Text(track.artist).foregroundStyle(.secondary)
                    PublicActionGroup {
                        if case .youtubeVideo(let id) = track.source {
                            Button { session.open(id, title: track.title) } label: { PublicIconActionLabel(title: "Open visible player", symbol: "play.fill") }
                            Link(destination: URL(string: "https://www.youtube.com/watch?v=\(id.rawValue)")!) {
                                PublicTextActionLabel(title: "YouTube", symbol: "arrow.up.right.square")
                            }
                        }
                        Button { session.toggleFavorite(trackID) } label: {
                            PublicIconActionLabel(title: track.liked ? "Remove favorite" : "Favorite", symbol: track.liked ? "heart.fill" : "heart")
                        }
                    }
                }
                Section {
                    PublicActionGroup {
                        PublicAddToPlaylistMenu(session: session, track: track)
                            .labelStyle(.titleAndIcon).frame(minHeight: 44)
                        Button { session.enqueueTrack(track, next: true) } label: { PublicIconActionLabel(title: "Play next", symbol: "text.line.first.and.arrowtriangle.forward") }
                        Button { session.enqueueTrack(track) } label: { PublicIconActionLabel(title: "Add to queue", symbol: "text.badge.plus") }
                        NavigationLink { PublicQueueView(session: session) } label: { PublicIconActionLabel(title: "View queue", symbol: "list.bullet") }
                    }
                }
                PublicNotebookSections(session: session, trackID: trackID)
            }
            if let message = session.failureMessage { Text(message).foregroundStyle(.red) }
        }
        .navigationTitle("Video details")
    }
}

private struct PublicQueueView: View {
    let session: PublicYouTubeSession
    @State private var clearing = false
    var body: some View {
        List {
            if let current = session.currentTrack {
                Section("Current video") {
                    HStack {
                        Text(current.title).fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button { session.showPlayer = true } label: { PublicIconActionLabel(title: "Open visible player", symbol: "play.fill") }
                    }.buttonStyle(.borderless)
                }
            }
            Section("Up next") {
                if session.queue.snapshot.upcoming.isEmpty {
                    Text("The queue is empty. Add videos from video details or a local playlist.").foregroundStyle(.secondary)
                }
                ForEach(session.queue.snapshot.upcoming) { entry in
                    Text(session.tracks.first(where: { $0.id == entry.trackID })?.title ?? "Unavailable video")
                        .accessibilityIdentifier("queue.entry.\(entry.id)")
                }
                .onDelete { indices in
                    let ids = indices.map { session.queue.snapshot.upcoming[$0].id }
                    session.editQueue { queue in for id in ids { try queue.remove(id: id) } }
                }
                .onMove { indices, destination in
                    var entries = session.queue.snapshot.upcoming
                    entries.move(fromOffsets: indices, toOffset: destination)
                    session.editQueue { queue in
                        for (index, entry) in entries.enumerated() { try queue.reorder(id: entry.id, to: index) }
                    }
                }
            }
            PublicActionGroup {
                Button {
                    session.next()
                    if session.failureMessage == nil { session.showPlayer = true }
                } label: { PublicIconActionLabel(title: "Open next video", symbol: "forward.end.fill") }
                    .disabled(!session.hasNext)
                Button { clearing = true } label: { PublicTextActionLabel(title: "Clear Up Next", symbol: "xmark.circle") }
                    .disabled(!session.hasNext)
                    .accessibilityIdentifier("public.clearUpNext")
            }
            if let message = session.failureMessage { Text(message).foregroundStyle(.red) }
        }
        .navigationTitle("Queue")
        .toolbar { EditButton() }
        .alert("Clear all upcoming videos?", isPresented: $clearing) {
            Button("Clear Up Next", role: .destructive) { session.clearUpcoming() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Your current video and playback are kept. Only upcoming videos are removed.") }
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
