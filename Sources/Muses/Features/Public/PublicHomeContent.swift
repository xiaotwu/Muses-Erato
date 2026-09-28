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
                Text("Your recently played playlist tracks appear here.")
                    .font(.subheadline).foregroundStyle(.secondary)
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
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) { youtubeHeading; websiteLink }
            } else {
                HStack { youtubeHeading; Spacer(); websiteLink }
            }
            if session.signedIn {
                if !session.accountPlaylistPages.items.isEmpty {
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
                if session.accountPlaylistPages.items.isEmpty && !session.accountPlaylistPages.loading && session.accountPlaylistPages.error == nil {
                    Text("No account playlists yet.").font(.subheadline).foregroundStyle(.secondary)
                }
                if session.accountPlaylistPages.loading { ProgressView("Loading account playlists") }
                if let error = session.accountPlaylistPages.error {
                    HStack {
                        Text(error).font(.footnote).foregroundStyle(.secondary)
                        Button("Retry", systemImage: "arrow.clockwise") { Task { await session.loadAccountCollections() } }.frame(minHeight: 44)
                    }
                }
            } else {
                Text("Sign in from Settings to see your YouTube playlists.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
    private var youtubeHeading: some View { PublicHomeHeading(title: "On YouTube") }
    private var websiteLink: some View {
        Link(destination: URL(string: "https://music.youtube.com/")!) {
            Label("YouTube Music", systemImage: "arrow.up.right")
                .font(.subheadline).frame(minHeight: 44)
        }.accessibilityIdentifier("home.youtubeMusic")
    }

}
