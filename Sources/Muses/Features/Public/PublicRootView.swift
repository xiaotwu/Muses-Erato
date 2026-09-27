import SwiftUI
import UIKit
import MusesDomain
import MusesCatalog

struct PublicRootView: View {
    @Bindable var session: PublicYouTubeSession
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var link = ""
    @FocusState private var linkFocused: Bool
    @State private var query = ""
    @State private var selection = 0
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if let recovery = session.recoveryMessage {
                ContentUnavailableView("Library needs attention", systemImage: "externaldrive.badge.exclamationmark", description: Text(recovery))
                    .padding()
            } else {
                if sizeClass == .regular {
                    NavigationSplitView {
                        List {
                            Button { selection = 0 } label: { Label("Home", systemImage: "house") }
                            Button { selection = 1 } label: { Label("Search", systemImage: "magnifyingglass") }
                            Button { selection = 2 } label: { Label("Library", systemImage: "square.stack") }
                            Button { selection = 3 } label: { Label("Settings", systemImage: "gearshape") }
                        }
                        .navigationTitle("Muses")
                    } detail: {
                        NavigationStack {
                            switch selection {
                            case 1: search
                            case 2: library
                            case 3: settings
                            default: home
                            }
                        }
                    }
                    .sheet(isPresented: $session.showPlayer) { PlayerSheet(session: session) }
                } else {
                    TabView(selection: $selection) {
                    NavigationStack { home }
                        .tabItem { Label("Home", systemImage: "house") }.tag(0)
                    NavigationStack { search }
                        .tabItem { Label("Search", systemImage: "magnifyingglass") }.tag(1)
                    NavigationStack { library }
                        .tabItem { Label("Library", systemImage: "square.stack") }.tag(2)
                    NavigationStack { settings }
                        .tabItem { Label("Settings", systemImage: "gearshape") }.tag(3)
                }
                    .sheet(isPresented: $session.showPlayer) {
                        PlayerSheet(session: session)
                    }
                }
            }
        }
    }

    private var home: some View {
        List {
            Section {
                Text("Watch YouTube in the visible player. Your queue and saved items stay on this device.")
                    .foregroundStyle(.secondary)
                TextField("Paste YouTube video URL or ID", text: $link)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($linkFocused)
                    .accessibilityIdentifier("public.link")
                Button("Open video") {
                    linkFocused = false
                    Task { await session.openLink(link) }
                }
                    .disabled(link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("public.open")
            } header: { Text("YouTube video") }
            if let message = session.failureMessage {
                Section { Text(message).foregroundStyle(.orange) }
            }
            if let current = session.currentTrack {
                Section("Current video") {
                    Button {
                        session.showPlayer = true
                    } label: {
                        Label(current.title, systemImage: "play.rectangle")
                    }
                    .accessibilityIdentifier("public.resume")
                    Text("Playback pauses when you leave the visible player.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Recently saved") {
                if session.tracks.isEmpty { Text("No videos saved yet").foregroundStyle(.secondary) }
                ForEach(session.tracks.prefix(20), id: \.id) { track in trackRow(track) }
            }
        }
        .navigationTitle("Muses")
    }

    private var search: some View {
        List {
            Section {
                TextField("Search videos", text: $query)
                    .submitLabel(.search)
                    .onSubmit { Task { await session.search(query) } }
                    .accessibilityIdentifier("public.search")
                Button("Search YouTube") { Task { await session.search(query) } }
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.searching)
                if session.searching { ProgressView("Searching") }
                if !session.apiConfigured {
                    Text("Online search requires an app YouTube Data API key. Saved videos still appear; known links work without a key.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let error = session.searchError {
                    Text(error).foregroundStyle(.orange)
                        .accessibilityIdentifier("public.searchError")
                }
            }
            Section("Results") {
                if session.searchItems.isEmpty && !session.searching {
                    Text("Search your saved videos or submit an online query.").foregroundStyle(.secondary)
                }
                ForEach(session.searchItems, id: \.id) { item in
                    if let id = try? VideoID(item.id) {
                        HStack {
                            Button(item.title) { session.open(id, title: item.title) }
                                .buttonStyle(.plain)
                            Spacer()
                            Button { session.enqueue(id, title: item.title) } label: {
                                Image(systemName: "text.badge.plus")
                            }
                            .accessibilityLabel("Add \(item.title) to queue")
                        }
                    }
                }
            }
        }
        .navigationTitle("Search")
    }

    private var library: some View {
        List {
            Text("Your YouTube library")
                .font(.headline)
                .accessibilityIdentifier("public.libraryHeader")
            Section {
                Picker("Category", selection: $session.selectedCategory) {
                    ForEach(LibraryCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(.menu)
            }
            Section(session.selectedCategory.rawValue) {
                switch session.selectedCategory {
                case .videos, .songs:
                    if session.tracks.isEmpty { emptyCategory }
                    ForEach(session.tracks, id: \.id) { track in trackRow(track) }
                case .favorites:
                    if session.favorites.isEmpty { emptyCategory }
                    ForEach(session.favorites, id: \.id) { track in trackRow(track) }
                case .history:
                    if session.history.isEmpty { emptyCategory }
                    ForEach(session.history, id: \.id) { track in trackRow(track) }
                case .subscriptions:
                    if session.signedIn {
                        if session.subscriptions.isEmpty {
                            Text("No subscriptions loaded").foregroundStyle(.secondary)
                        }
                        ForEach(session.subscriptions, id: \.id) { item in Text(item.title) }
                        Button("Refresh subscriptions") { Task { await session.loadSubscriptions() } }
                    } else {
                        Text("Sign in from Settings to read YouTube subscriptions.")
                            .foregroundStyle(.secondary)
                    }
                default:
                    Text("This YouTube category needs account data or a supported official endpoint and is not available here yet.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Library")
    }

    private var emptyCategory: some View {
        Text("Nothing here yet").foregroundStyle(.secondary)
    }

    private func trackRow(_ track: MusesDomain.Track) -> some View {
        Button {
            if case .youtubeVideo(let id) = track.source { session.open(id, title: track.title) }
        } label: {
            Label(track.title, systemImage: track.liked ? "heart.fill" : "play.rectangle")
                .lineLimit(2)
        }
    }

    private var settings: some View {
        List {
            Section("Playback") {
                Text("YouTube videos play in the visible official player. Background audio, EQ, spectrum, lock screen controls and CarPlay are unavailable.")
                Text("YouTube Music albums and personalized Home are unavailable through the official Data API.")
                    .foregroundStyle(.secondary)
            }
            Section("YouTube account") {
                if session.signedIn {
                    Text("Signed in for read-only YouTube account data")
                    Button("Sign out and revoke access") { Task { await session.signOut() } }
                } else if session.oauthConfigured {
                    Button("Sign in with Google") { Task { await session.signIn() } }
                } else {
                    Text("Google sign in requires the app's iOS OAuth client ID and matching redirect scheme.")
                        .foregroundStyle(.secondary)
                }
            }
            Section("Local data") {
                Button("Delete saved videos, queue and history", role: .destructive) { confirmDelete = true }
                Text("This removes data stored by Muses on this device. It does not delete YouTube data.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Delete local Muses data?", isPresented: $confirmDelete) {
            Button("Delete local data", role: .destructive) { Task { await session.deleteLocalData() } }
        } message: {
            Text("Your YouTube account and videos are unaffected.")
        }
    }
}

private struct IFrameSurface: UIViewRepresentable {
    let adapter: YouTubeIFrameAdapter
    func makeUIView(context: Context) -> UIView { adapter.view }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

private struct PlayerSheet: View {
    @Bindable var session: PublicYouTubeSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var adapter: YouTubeIFrameAdapter?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let adapter {
                    IFrameSurface(adapter: adapter)
                        .frame(minWidth: 200, minHeight: 240)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .accessibilityLabel("Visible YouTube player")
                        .accessibilityIdentifier("public.iframe")
                }
                Text(session.currentTrack?.title ?? "YouTube video")
                    .font(.headline).multilineTextAlignment(.center)
                Text(session.state.state.rawValue.capitalized)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("public.playbackState")
                if let message = session.failureMessage {
                    Text(message).foregroundStyle(.orange).multilineTextAlignment(.center)
                }
                HStack(spacing: 24) {
                    Button { session.play() } label: { Label("Play", systemImage: "play.fill") }
                    Button { session.pause() } label: { Label("Pause", systemImage: "pause.fill") }
                    Button { session.next() } label: { Label("Next", systemImage: "forward.end.fill") }
                        .disabled(!session.hasNext)
                }
                .buttonStyle(.bordered)
                Button {
                    session.toggleFavorite()
                } label: {
                    Label(session.currentTrack?.liked == true ? "Remove favorite" : "Favorite",
                          systemImage: session.currentTrack?.liked == true ? "heart.fill" : "heart")
                }
                if case .youtubeVideo(let id) = session.currentTrack?.source,
                   let url = URL(string: "https://www.youtube.com/watch?v=\(id.rawValue)") {
                    Button("Open in YouTube") { openURL(url) }
                }
                if !session.queue.snapshot.upcoming.isEmpty {
                    List {
                        Section("Up next") {
                            ForEach(session.queue.snapshot.upcoming) { entry in
                                Text(session.tracks.first(where: { $0.id == entry.trackID })?.title ?? "YouTube video")
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }
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
}
