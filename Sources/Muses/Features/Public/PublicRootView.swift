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
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: PublicDestination = .home
    @State private var showSettings = false
    @State private var link = ""
    @FocusState private var linkFocused: Bool
    @FocusState private var searchFocused: Bool
    @State private var query = ""
    @State private var confirmDelete = false
    @State private var confirmClearHistory = false

    var body: some View {
        Group {
            if let recovery = session.recoveryMessage {
                ContentUnavailableView(
                    "Library needs attention",
                    systemImage: "externaldrive.badge.exclamationmark",
                    description: Text(recovery)
                )
                .padding()
            } else if sizeClass == .regular {
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
        .tint(PublicStyle.gold)
        .background(PublicKeyboardDismissal())
        .sheet(isPresented: $showSettings) {
            NavigationStack { settings }
        }
        .fullScreenCover(isPresented: $session.showPlayer) {
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
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("YOUR LISTENING SPACE")
                        .font(.caption.weight(.semibold))
                        .tracking(2.2)
                        .foregroundStyle(PublicStyle.gold)
                    Text("A place for what\nyou love.")
                        .font(.system(.largeTitle, design: .serif, weight: .semibold))
                        .foregroundStyle(PublicStyle.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Your saved YouTube videos, history and favorites, together in Muses.")
                        .font(.subheadline)
                        .foregroundStyle(PublicStyle.muted)
                }
                .padding(.top, 18)

                linkCard

                if let message = session.failureMessage {
                    PublicNotice(message: message, symbol: "exclamationmark.circle")
                }

                if let current = session.currentTrack {
                    sectionHeading("Continue", detail: "Opens the visible YouTube player")
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

                sectionHeading("Recently saved", detail: "On this device")
                if session.tracks.isEmpty {
                    PublicEmptyState(
                        symbol: "square.stack",
                        title: "Your collection starts here",
                        detail: "Open a YouTube video above. It will appear here when saved."
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
        .navigationTitle("Muses")
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { settingsToolbar }
    }

    private var linkCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Open a YouTube video", systemImage: "play.rectangle")
                .font(.headline)
                .foregroundStyle(PublicStyle.ink)
            Text("Paste a video link or ID. Playback stays in the visible official player.")
                .font(.subheadline)
                .foregroundStyle(PublicStyle.muted)
            TextField("Paste YouTube video URL or ID", text: $link)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.URL)
                .submitLabel(.go)
                .focused($linkFocused)
                .onSubmit(openLink)
                .padding(12)
                .background(PublicStyle.background, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("public.link")
            Button(action: openLink) {
                Label("Open video", systemImage: "arrow.up.right")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("public.open")
        }
        .padding(20)
        .background(PublicStyle.surface, in: RoundedRectangle(cornerRadius: 22))
    }

    private func openLink() {
        linkFocused = false
        Task { await session.openLink(link) }
    }

    private var discover: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                PublicPageHeading(
                    eyebrow: "DISCOVER",
                    title: "Follow your curiosity.",
                    subtitle: "Explore YouTube videos through a search you choose. Muses does not have a YouTube Music personalized feed."
                )
                if !session.apiConfigured {
                    PublicNotice(
                        message: "Online discovery needs a YouTube Data API key or a Google sign in. Known links and saved videos still work.",
                        symbol: "wifi.slash"
                    )
                }
                sectionHeading("Explore by search", detail: "Search runs only when selected")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                    discoveryTile("Live sessions", symbol: "music.mic", query: "live music sessions")
                    discoveryTile("New music", symbol: "sparkles.tv", query: "new music videos")
                    discoveryTile("Performances", symbol: "theatermasks", query: "music performances")
                    discoveryTile("Conversations", symbol: "mic", query: "music interviews")
                }
                if !session.history.isEmpty {
                    sectionHeading("From your history", detail: "Recently played here")
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
                PublicPageHeading(
                    eyebrow: "FIND A VIDEO",
                    title: "Search.",
                    subtitle: "Search saved videos and, when configured, YouTube videos."
                )
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(PublicStyle.muted)
                    TextField("Search videos", text: $query)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .focused($searchFocused)
                        .onSubmit(submitSearch)
                        .accessibilityIdentifier("public.search")
                }
                .padding(15)
                .background(PublicStyle.surface, in: RoundedRectangle(cornerRadius: 14))
                Button("Search YouTube", action: submitSearch)
                    .buttonStyle(.borderedProminent)
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.searching)
                if session.searching {
                    ProgressView("Searching YouTube")
                }
                if !session.apiConfigured {
                    PublicNotice(
                        message: "Online search needs a YouTube Data API key or a Google sign in. Saved videos and known links remain available.",
                        symbol: "wifi.slash"
                    )
                }
                if let error = session.searchError {
                    PublicNotice(message: error, symbol: "exclamationmark.circle")
                        .accessibilityIdentifier("public.searchError")
                }
                sectionHeading("Results", detail: session.searchItems.isEmpty ? "" : "\(session.searchItems.count) videos")
                if session.searchItems.isEmpty && !session.searching {
                    PublicEmptyState(
                        symbol: "magnifyingglass",
                        title: "Nothing to show yet",
                        detail: "Enter a title or artist, then submit your search."
                    )
                }
                LazyVStack(spacing: 10) {
                    ForEach(session.searchItems, id: \.id) { item in
                        if let id = try? VideoID(item.id) {
                            HStack(spacing: 12) {
                                Button {
                                    session.open(id, title: item.title)
                                } label: {
                                    PublicVideoArtwork(videoID: id.rawValue)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(PublicStyle.ink)
                                            .lineLimit(2)
                                        Text(item.source == "local" ? "Saved video" : "YouTube video")
                                            .font(.caption)
                                            .foregroundStyle(PublicStyle.muted)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .buttonStyle(.plain)
                                Button {
                                    session.enqueue(id, title: item.title)
                                } label: {
                                    Image(systemName: "text.badge.plus")
                                        .frame(width: 44, height: 44)
                                }
                                .accessibilityLabel("Add \(item.title) to queue")
                            }
                            .padding(8)
                            .background(PublicStyle.surface, in: RoundedRectangle(cornerRadius: 15))
                        }
                    }
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
            VStack(alignment: .leading, spacing: 25) {
                PublicPageHeading(
                    eyebrow: "YOUR COLLECTION",
                    title: "Library.",
                    subtitle: "Saved videos, favorites and listening history live on this device.",
                    identifier: "public.libraryHeader"
                )

                VStack(alignment: .leading, spacing: 12) {
                    NavigationLink { PublicQueueView(session: session) } label: {
                        Label("Queue (\(session.queue.snapshot.upcoming.count) upcoming)", systemImage: "list.bullet")
                    }
                    .accessibilityIdentifier("public.queue")
                    PublicClearUpNextButton(session: session)
                    Text("Clears only upcoming videos. Your current video stays in the player.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PublicStyle.surface, in: RoundedRectangle(cornerRadius: 16))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), spacing: 10)], spacing: 10) {
                    ForEach(LibraryCategory.allCases) { category in
                        Button {
                            if reduceMotion {
                                session.selectedCategory = category
                            } else {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    session.selectedCategory = category
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 14) {
                                Image(systemName: category.symbol)
                                    .font(.title3)
                                    .foregroundStyle(PublicStyle.gold)
                                Text(category.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(PublicStyle.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                            .background(
                                session.selectedCategory == category ? PublicStyle.gold.opacity(0.15) : PublicStyle.surface,
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(session.selectedCategory == category ? PublicStyle.gold : .clear, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(session.selectedCategory == category ? .isSelected : [])
                        .accessibilityIdentifier("library.category.\(category.rawValue)")
                    }
                }
                if let message = session.failureMessage { PublicNotice(message: message, symbol: "exclamationmark.circle") }
                sectionHeading(session.selectedCategory.rawValue, detail: categoryDetail)
                categoryContent
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(.horizontal, PublicStyle.inset)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
        }
        .background(PublicStyle.background)
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { settingsToolbar }
    }

    private var categoryDetail: String {
        switch session.selectedCategory {
        case .videos, .songs: "\(session.tracks.count) saved"
        case .favorites: "\(session.favorites.count) saved"
        case .playlists: "\(session.playlists.count) on this device"
        case .history: "\(session.history.count) played"
        case .subscriptions: session.signedIn ? "\(session.subscriptions.count) loaded" : "Sign in required"
        default: "Unavailable in this version"
        }
    }

    @ViewBuilder
    private var categoryContent: some View {
        switch session.selectedCategory {
        case .videos, .songs:
            if session.tracks.isEmpty {
                PublicEmptyState(symbol: "play.rectangle", title: "No saved videos", detail: "Open a YouTube link on Home to start your collection.")
            } else {
                videoShelf(session.tracks)
            }
        case .favorites:
            if session.favorites.isEmpty {
                PublicEmptyState(symbol: "heart", title: "No favorites yet", detail: "Open a saved video and choose Favorite.")
            } else {
                videoShelf(session.favorites)
            }
        case .playlists:
            PublicPlaylistCollection(session: session)
        case .history:
            if !session.history.isEmpty {
                Button("Clear history", role: .destructive) { confirmClearHistory = true }
                    .confirmationDialog("Clear playback history?", isPresented: $confirmClearHistory, titleVisibility: .visible) {
                        Button("Clear history", role: .destructive) { session.clearHistory() }
                    } message: { Text("Saved videos, favorites and playlists will remain.") }
            }
            if session.history.isEmpty {
                PublicEmptyState(symbol: "clock", title: "No listening history", detail: "Videos appear after the official player confirms playback.")
            } else {
                videoShelf(session.history)
            }
        case .subscriptions:
            if session.signedIn {
                if session.subscriptions.isEmpty {
                    PublicEmptyState(symbol: "person.crop.rectangle.stack", title: "No subscriptions loaded", detail: "Refresh to read subscriptions from your YouTube account.")
                }
                ForEach(session.subscriptions, id: \.id) { item in
                    Text(item.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(PublicStyle.surface, in: RoundedRectangle(cornerRadius: 12))
                }
                Button("Refresh subscriptions") { Task { await session.loadSubscriptions() } }
                    .buttonStyle(.bordered)
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
            Section("Playback") {
                Text("YouTube videos play in the visible official player. Playback pauses when you close it.")
                Text("Background audio, EQ, spectrum, lock screen controls and CarPlay are unavailable.")
                    .foregroundStyle(PublicStyle.muted)
                Text("YouTube Music albums and personalized Home are unavailable through the official Data API.")
                    .foregroundStyle(PublicStyle.muted)
            }
            Section("YouTube account") {
                if session.signedIn {
                    Text("Signed in for read-only YouTube account data")
                    Button("Sign out and revoke access") { Task { await session.signOut() } }
                } else if session.oauthConfigured {
                    Button("Sign in with Google") { Task { await session.signIn() } }
                } else {
                    Text("Google sign in requires the app's iOS OAuth client ID and matching redirect scheme.")
                        .foregroundStyle(PublicStyle.muted)
                }
            }
            Section("Local data") {
                Button("Delete videos, playlists, queue and history", role: .destructive) { confirmDelete = true }
                Text("This removes data stored by Muses on this device. It does not delete YouTube data.")
                    .font(.footnote)
                    .foregroundStyle(PublicStyle.muted)
            }
            if let message = session.failureMessage {
                Section("Notice") { Text(message) }
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            if sizeClass != .regular {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showSettings = false }
                }
            }
        }
        .confirmationDialog("Delete local Muses data?", isPresented: $confirmDelete) {
            Button("Delete local data", role: .destructive) { Task { await session.deleteLocalData() } }
        } message: {
            Text("Your YouTube account and videos are unaffected.")
        }
    }
}

private extension LibraryCategory {
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
                Button { session.pause() } label: { Label("Pause", systemImage: "pause.fill") }
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
            }
            Text("Playback pauses when this screen closes.")
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
    @State private var creating = false
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button("Create local playlist", systemImage: "plus") { name = ""; creating = true }
                .accessibilityIdentifier("public.createPlaylist")
            Text("Stored on this device. These playlists do not change your YouTube account.")
                .font(.footnote).foregroundStyle(.secondary)
            if session.playlists.isEmpty {
                PublicEmptyState(symbol: "music.note.list", title: "No local playlists", detail: "Create a playlist, then add videos from your saved collection.")
            }
            ForEach(session.playlists) { playlist in
                NavigationLink {
                    PublicPlaylistDetail(session: session, playlistID: playlist.id)
                } label: {
                    HStack {
                        Label(playlist.name, systemImage: "music.note.list")
                        Spacer()
                        Text("\(playlist.trackIDs.count) videos").foregroundStyle(.secondary)
                    }.padding(.vertical, 10)
                }
            }
        }
        .alert("Create local playlist", isPresented: $creating) {
            TextField("Playlist name", text: $name)
            Button("Create") { session.createPlaylist(name) }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct PublicPlaylistDetail: View {
    let session: PublicYouTubeSession
    let playlistID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var renaming = false
    @State private var deleting = false
    @State private var adding = false
    @State private var name = ""
    private var playlist: LocalPlaylist? { session.playlists.first { $0.id == playlistID } }

    var body: some View {
        List {
            if let playlist {
                Section {
                    Text("\(playlist.trackIDs.count) videos · On this device")
                    Button("Add videos", systemImage: "plus") { adding = true }
                    Button("Add playlist to queue", systemImage: "text.badge.plus") { session.enqueuePlaylist(playlistID) }
                        .disabled(playlist.trackIDs.isEmpty)
                }
                Section("Videos") {
                    if playlist.trackIDs.isEmpty {
                        Text("This playlist is empty. Add videos from your saved collection.").foregroundStyle(.secondary)
                    }
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
                Section {
                    Button("Rename playlist") { name = playlist.name; renaming = true }
                    Button("Delete playlist", role: .destructive) { deleting = true }
                }
            }
            if let message = session.failureMessage { Text(message).foregroundStyle(.red) }
        }
        .navigationTitle(playlist?.name ?? "Playlist")
        .toolbar { EditButton() }
        .alert("Rename playlist", isPresented: $renaming) {
            TextField("Playlist name", text: $name)
            Button("Save") { session.editPlaylist(playlistID) { try $0.rename(name) } }
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
                .toolbar { Button("Done") { adding = false } }
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
                session.createPlaylist(name, trackIDs: [track.id])
            }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct PublicVideoDetail: View {
    let session: PublicYouTubeSession
    let trackID: TrackID
    private var track: MusesDomain.Track? { session.tracks.first { $0.id == trackID } }
    var body: some View {
        List {
            if let track {
                Section {
                    Text(track.title).font(.title2)
                    Text(track.artist).foregroundStyle(.secondary)
                    if case .youtubeVideo(let id) = track.source {
                        Text(id.rawValue).font(.caption).textSelection(.enabled)
                        Button("Open visible player", systemImage: "play.rectangle") { session.open(id, title: track.title) }
                        Link("View on YouTube", destination: URL(string: "https://www.youtube.com/watch?v=\(id.rawValue)")!)
                    }
                }
                Section("Local library") {
                    Button(track.liked ? "Remove favorite" : "Favorite", systemImage: track.liked ? "heart.fill" : "heart") {
                        session.toggleFavorite(trackID)
                    }
                    PublicAddToPlaylistMenu(session: session, track: track)
                    Button("Play next", systemImage: "text.line.first.and.arrowtriangle.forward") { session.enqueueTrack(track, next: true) }
                    Button("Add to queue", systemImage: "text.badge.plus") { session.enqueueTrack(track) }
                    NavigationLink { PublicQueueView(session: session) } label: { Text("View queue") }
                }
            }
            if let message = session.failureMessage { Text(message).foregroundStyle(.red) }
        }
        .navigationTitle("Video details")
    }
}

private struct PublicQueueView: View {
    let session: PublicYouTubeSession
    var body: some View {
        List {
            if let current = session.currentTrack {
                Section("Current video") {
                    Text(current.title)
                    Button("Open visible player") { session.showPlayer = true }
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
            if !session.queue.snapshot.upcoming.isEmpty {
                Button("Open next video") {
                    session.next()
                    if session.failureMessage == nil { session.showPlayer = true }
                }
            }
            PublicClearUpNextButton(session: session)
            if let message = session.failureMessage { Text(message).foregroundStyle(.red) }
        }
        .navigationTitle("Queue")
        .toolbar { EditButton() }
    }
}

/// Shared action keeps the same scope and confirmation at all queue entry points.
private struct PublicClearUpNextButton: View {
    let session: PublicYouTubeSession
    @State private var confirming = false

    var body: some View {
        Button("Clear Up Next", systemImage: "trash", role: .destructive) { confirming = true }
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
