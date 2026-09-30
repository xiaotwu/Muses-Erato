import SwiftUI
import MusesDomain
import MusesCatalog

struct PublicHomeLibraryContent: View {
    let session: PublicYouTubeSession
    let showHistory: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    private var recent: [MusesDomain.Track] { Array(session.libraryHistory.prefix(12)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) { historyHeading; historyAction }
            } else {
                HStack { historyHeading; Spacer(); historyAction }
            }
            if recent.isEmpty {
                Text("Your recently played videos appear here.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else if typeSize.isAccessibilitySize {
                ForEach(recent) { track in
                    PublicCollectionRow(session: session, track: track, category: .history, onPlay: {
                        if let index = recent.firstIndex(where: { $0.id == track.id }) { session.playTracks(recent, startingAt: index, context: "home:recent") }
                    })
                }
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 14) {
                        ForEach(recent) { track in
                            Button {
                                if let index = recent.firstIndex(where: { $0.id == track.id }) {
                                    session.playTracks(recent, startingAt: index, context: "home:recent")
                                }
                            } label: {
                                PublicDeckArtworkCard(track: track, width: 228, footer: typeSize.isAccessibilitySize ? 120 : 66)
                            }.buttonStyle(.plain)
                                .accessibilityLabel(track.displayTitle + ", " + track.displayArtist)
                                .accessibilityIdentifier("home.play." + track.id.rawValue)
                        }
                    }.padding(.vertical, 6)
                }.scrollIndicators(.hidden)
            }
        }
    }
    private var historyHeading: some View { PublicHomeHeading(title: "Recently Played") }
    @ViewBuilder private var historyAction: some View {
        if !recent.isEmpty { Button("See all", action: showHistory).font(.subheadline).frame(minHeight: 44) }
    }
}

struct PublicHomeHeading: View {
    let title: String
    var body: some View { Text(title).font(.title2.weight(.bold)).accessibilityAddTraits(.isHeader) }
}

struct PublicHomePlaylistShelves: View {
    let session: PublicYouTubeSession
    var showAccount: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            youtubeHeading
            if session.signedIn {
                if !session.accountPlaylistPages.items.isEmpty {
                    if typeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(session.accountPlaylistPages.items, id: \.rowID) { PublicCatalogRow(session: session, item: $0, authorized: true) }
                        }
                    } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ScrollView(.horizontal) {
                            LazyHStack(alignment: .top, spacing: 14) {
                                ForEach(session.accountPlaylistPages.items, id: \.rowID) { item in
                                    NavigationLink { PublicCatalogDetail(session: session, route: .playlist(item.id), authorized: true) } label: {
                                        VStack(alignment: .leading, spacing: 7) {
                                            AsyncImage(url: item.thumbnailURL) { image in image.resizable().scaledToFill() } placeholder: {
                                                Rectangle().fill(PublicStyle.surface).overlay { Image(systemName: "music.note.list").foregroundStyle(.secondary) }
                                            }.frame(width: 148, height: 148).clipShape(RoundedRectangle(cornerRadius: 16))
                                            Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                                        }.frame(width: 148, alignment: .leading).contentShape(Rectangle())
                                    }.buttonStyle(.plain)
                                }
                            }
                        }.scrollIndicators(.hidden)
                    }
                    }
                }
                if session.accountPlaylistPages.items.isEmpty && !session.accountPlaylistPages.loading && session.accountPlaylistPages.error == nil {
                    Text("No account playlists yet.").font(.subheadline).foregroundStyle(.secondary)
                }
                if session.accountPlaylistPages.loading { ProgressView("Loading account playlists") }
                if session.accountPlaylistPages.nextPageToken != nil && !session.accountPlaylistPages.loading && session.accountPlaylistPages.error == nil {
                    Button("More playlists", systemImage: "arrow.down.circle") { Task { await session.loadAccountPlaylists() } }
                        .frame(minHeight: 44).accessibilityIdentifier("home.morePlaylists")
                }
                if let error = session.accountPlaylistPages.error {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error).font(.footnote).foregroundStyle(.secondary)
                        Button("Retry", systemImage: "arrow.clockwise") { Task { await session.loadAccountPlaylists() } }
                            .frame(minHeight: 44).disabled(session.accountPlaylistPages.loading)
                    }
                }
            } else {
                Text("Sign in to see your YouTube playlists.").font(.subheadline).foregroundStyle(.secondary)
                Button("Account settings", action: showAccount).frame(minHeight: 44).buttonStyle(.bordered)
            }
        }
    }
    private var youtubeHeading: some View { PublicHomeHeading(title: "YouTube Playlists") }

}

struct PublicHomeLocalPlaylists: View {
    let session: PublicYouTubeSession
    var showAll: () -> Void = {}
    var body: some View {
        if !session.playlists.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                PublicHomeHeading(title: "Your Playlists")
                Button("See all", action: showAll).font(.subheadline).frame(minHeight: 44)
                ForEach(session.playlists.prefix(6)) { playlist in
                    NavigationLink { PublicPlaylistDetail(session: session, playlistID: playlist.id) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "music.note.list").foregroundStyle(PublicStyle.gold)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(playlist.name).font(.headline)
                                Text("\(PublicStyle.videoCount(playlist.entryCount)) · On this device").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }.padding(16).frame(minHeight: 44)
                            .background(PublicStyle.surface, in: RoundedRectangle(cornerRadius: 16))
                    }.buttonStyle(.plain).accessibilityIdentifier("home.playlist.\(playlist.id)")
                }
            }
        }
    }
}

struct PublicHomeSavedVideos: View {
    let session: PublicYouTubeSession
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PublicHomeHeading(title: "Saved Videos")
            ForEach(session.libraryTracks.prefix(6)) { track in
                PublicCollectionRow(session: session, track: track, category: .videos)
            }
        }
    }
}
