import SwiftUI
import MusesCatalog
import MusesDomain
import MusesNetworking

struct PublicCatalogRow: View {
    let session: PublicYouTubeSession
    let item: MusesCatalog.CatalogItem
    var authorized = false
    var body: some View {
        Group {
            if item.kind == .video, let id = try? VideoID(item.id) {
                VStack(alignment: .leading, spacing: 8) {
                    Button { session.open(id, title: item.title, metadataFetchedAt: item.fetchedAt) } label: { label }
                        .buttonStyle(.plain)
                    HStack {
                        Button { session.enqueue(id, title: item.title, metadataFetchedAt: item.fetchedAt) } label: { PublicIconActionLabel(title: "Add to queue", symbol: "text.badge.plus") }
                        if let channel = item.channelID {
                            NavigationLink { PublicCatalogDetail(session: session, route: .channel(channel)) } label: {
                                Label("Channel", systemImage: "person.crop.rectangle").labelStyle(.iconOnly).frame(width: 44, height: 44)
                            }
                        }
                    }.font(.caption)
                }
            } else {
                NavigationLink {
                    PublicCatalogDetail(session: session, route: item.kind == .playlist ? .playlist(item.id) : .channel(item.id), authorized: authorized)
                } label: { label }
            }
        }.padding(.vertical, 8)
    }
    private var label: some View {
        HStack {
            if let url = item.thumbnailURL {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.secondary.opacity(0.15) }
                    .frame(width: 72, height: 48).clipped().accessibilityHidden(true)
            }
            VStack(alignment: .leading) {
                Text(item.title).lineLimit(3)
                Text(item.source == "local" ? "On this device" : "YouTube · \(item.kind.rawValue)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PublicCatalogPaging: View {
    let page: CatalogPager
    var initialTitle = "Load from YouTube"
    let load: () async -> Void
    @State private var clearing = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = page.error { Text(error).foregroundStyle(.secondary).accessibilityIdentifier("catalog.error") }
            if page.loading { ProgressView("Loading YouTube") }
            else if page.error != nil || !page.loaded || page.nextPageToken != nil {
                Button { Task { await load() } } label: {
                    PublicIconActionLabel(title: page.error != nil ? "Retry" : page.loaded ? "Load next page" : initialTitle, symbol: page.error != nil ? "arrow.clockwise" : "arrow.down.circle")
                }
                    .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("catalog.load")
            } else if page.items.isEmpty {
                Text("No available items.").font(.footnote).foregroundStyle(.secondary)
            }
            Button { clearing = true } label: { PublicIconActionLabel(title: "Clear loaded items", symbol: "xmark.circle") }
                .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                .disabled(page.items.isEmpty && !page.loading)
                .confirmationDialog("Clear local display?", isPresented: $clearing, titleVisibility: .visible) {
                    Button("Clear display", role: .destructive) { page.reset() }
                } message: { Text("Clears only the items shown here. Your YouTube playlists and subscriptions are unchanged.") }
            if let date = page.fetchedAt {
                Text("YouTube · Updated \(date.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

struct PublicCatalogDetail: View {
    let session: PublicYouTubeSession
    let route: YouTubeCatalogLink
    var authorized = false
    @State private var metadata = CatalogPager()
    @State private var videos = CatalogPager()
    @State private var playlists = CatalogPager()
    private var item: MusesCatalog.CatalogItem? { metadata.items.first }
    var body: some View {
        List {
            Section("YouTube details") {
                if let item {
                    Text(item.title).font(.title2)
                    if let description = item.description, !description.isEmpty { Text(description).font(.subheadline) }
                    if item.kind == .playlist, let channel = item.channelID {
                        NavigationLink("View channel") { PublicCatalogDetail(session: session, route: .channel(channel)) }
                    }
                } else if metadata.loaded {
                    Text("This content is private, deleted or unavailable.")
                    Button { metadata.reset(); Task { await loadDetails() } } label: { PublicIconActionLabel(title: "Retry details", symbol: "arrow.clockwise") }
                }
                PublicCatalogPaging(page: metadata, initialTitle: "Load details") { await loadDetails() }
            }
            if let item, item.kind == .playlist {
                Section("Videos") {
                    rows(videos)
                    PublicCatalogPaging(page: videos, initialTitle: "Load playlist videos") {
                        await videos.load { try await session.readCatalog(.playlist(item.id), token: $0, contents: true, authorized: authorized) }
                    }
                }
            }
            if let item, item.kind == .channel {
                Section("Uploads") {
                    if let uploads = item.uploadsPlaylistID {
                        rows(videos)
                        PublicCatalogPaging(page: videos, initialTitle: "Load uploads") {
                            await videos.load { try await session.readCatalog(.playlist(uploads), token: $0, contents: true) }
                        }
                    } else { Text("No uploads playlist is available.") }
                }
                Section("Public playlists") {
                    rows(playlists)
                    PublicCatalogPaging(page: playlists, initialTitle: "Load channel playlists") {
                        await playlists.load { try await session.readCatalog(.channel(item.id), token: $0, contents: true) }
                    }
                }
            }
        }
        .navigationTitle(item?.kind == .channel ? "Channel" : "YouTube")
        .task {
            if !metadata.loaded { await loadDetails() }
            while !Task.isCancelled {
                metadata.expire(); videos.expire(); playlists.expire()
                do { try await Task.sleep(for: .seconds(3600)) } catch { break }
            }
        }
        .onChange(of: session.signedIn) { _, _ in metadata.reset(); videos.reset(); playlists.reset() }
    }
    private func loadDetails() async {
        await metadata.load { _ in try await session.readCatalog(route, authorized: authorized) }
    }
    private func rows(_ page: CatalogPager) -> some View {
        ForEach(page.items, id: \.rowID) { PublicCatalogRow(session: session, item: $0, authorized: authorized) }
    }
}

struct PublicYouTubeAccountCatalog: View {
    let session: PublicYouTubeSession
    @State private var clearing = false
    var body: some View {
        List {
            Section("Local Muses profile") {
                Text("\(session.tracks.count) saved videos · \(session.playlists.count) local playlists")
                Text("Favorites, history, queue and local playlists stay on this device. They are separate from your YouTube account.").font(.footnote)
            }
            if session.signedIn {
                Section("YouTube channel profile · Read only") {
                    ForEach(session.accountChannelPages.items, id: \.rowID) { PublicCatalogRow(session: session, item: $0) }
                    PublicCatalogPaging(page: session.accountChannelPages, initialTitle: "Load my YouTube profile") { await session.loadAccountChannel() }
                }
                Section("My YouTube playlists") {
                    ForEach(session.accountPlaylistPages.items, id: \.rowID) { PublicCatalogRow(session: session, item: $0, authorized: true) }
                    PublicCatalogPaging(page: session.accountPlaylistPages, initialTitle: "Load my YouTube playlists") { await session.loadAccountPlaylists() }
                }
                Section("My YouTube subscriptions") {
                    ForEach(session.subscriptions, id: \.rowID) { PublicCatalogRow(session: session, item: $0) }
                    PublicCatalogPaging(page: session.subscriptionPages, initialTitle: "Load subscriptions") { await session.loadSubscriptions() }
                }
            } else {
                Section("YouTube account") { Text("Sign in from Settings to browse your YouTube profile, playlists and subscriptions.") }
            }
        }.navigationTitle("Account & collections")
        .toolbar {
            Button { clearing = true } label: { PublicIconActionLabel(title: "Clear local YouTube display", symbol: "xmark.circle") }
                .labelStyle(.iconOnly)
                .disabled(session.subscriptions.isEmpty && session.accountPlaylistPages.items.isEmpty && session.accountChannelPages.items.isEmpty)
        }
        .confirmationDialog("Clear local YouTube display and cache?", isPresented: $clearing, titleVisibility: .visible) {
            Button("Clear display and cache", role: .destructive) { Task { await session.clearCatalogDisplay() } }
        } message: { Text("Your YouTube playlists and subscriptions stay unchanged.") }
    }
}
