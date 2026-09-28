import SwiftUI
import MusesDomain
import MusesCatalog

struct PublicHomeMoodRail: View {
    let browse: (String) -> Void
    private let moods = [("Relax", "calm relaxing music"), ("Focus", "instrumental focus music"),
                         ("Energy", "energetic music"), ("Feel good", "feel good music"), ("Live", "live music sessions")]
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(moods, id: \.0) { title, query in
                    Button(title) { browse(query) }.frame(minHeight: 44)
                        .accessibilityHint("Search YouTube for \(title.lowercased()) music")
                        .accessibilityIdentifier("home.mood." + title)
                }
            }.modifier(PublicGlassActions())
        }.scrollIndicators(.hidden)
    }
}

struct PublicHomeLibraryContent: View {
    let session: PublicYouTubeSession
    let showHistory: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    private var featured: [MusesDomain.Track] {
        var seen = Set<TrackID>()
        return ([session.currentTrack].compactMap { $0 } + Array(session.libraryHistory.prefix(6)))
            .filter { seen.insert($0.id).inserted }.prefix(6).map { $0 }
    }
    private var picks: [MusesDomain.Track] {
        var seen = Set<TrackID>()
        return (Array(session.libraryFavorites.prefix(6)) + Array(session.libraryTracks.prefix(8)))
            .filter { seen.insert($0.id).inserted }.prefix(6).map { $0 }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if !featured.isEmpty {
                PublicHomeHeading(title: "Keep listening")
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 14) {
                        ForEach(featured) { track in
                            Button {
                                if session.currentTrack?.id == track.id { session.play(); session.showPlayer = true }
                                else { play(track, in: featured) }
                            } label: {
                                PublicDeckArtworkCard(track: track, width: 228, footer: typeSize.isAccessibilitySize ? 120 : 66)
                            }.buttonStyle(.plain)
                                .accessibilityLabel(track.displayTitle + ", " + track.displayArtist)
                                .accessibilityIdentifier(session.currentTrack?.id == track.id ? "public.resume" : "home.play." + track.id.rawValue)
                        }
                    }.padding(.vertical, 6)
                }.scrollIndicators(.hidden)
            }
            if !picks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    PublicHomeHeading(title: "Quick picks")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
                        ForEach(picks) { track in
                            Button { play(track, in: picks) } label: {
                                HStack(spacing: 10) {
                                    PublicCompactHeroCover(videoID: track.publicVideoID?.rawValue, width: 42)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(track.displayTitle).font(.subheadline.weight(.semibold)).lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                                        Text(track.displayArtist).font(.caption).foregroundStyle(.secondary).lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }.padding(9).frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                                    .background(PublicStyle.surface, in: RoundedRectangle(cornerRadius: 16))
                                    .contentShape(RoundedRectangle(cornerRadius: 16))
                            }.buttonStyle(.plain).accessibilityIdentifier("home.play." + track.id.rawValue)
                        }
                    }
                }
            }
            if !session.libraryHistory.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        PublicHomeHeading(title: "Recently played")
                        Spacer()
                        Button("See all", action: showHistory).font(.subheadline).frame(minHeight: 44)
                    }
                    PublicHomeTrackRail(session: session, tracks: Array(session.libraryHistory.prefix(12)))
                }
            }
        }
    }
    private func play(_ track: MusesDomain.Track, in tracks: [MusesDomain.Track]) {
        if let index = tracks.firstIndex(where: { $0.id == track.id }) { session.playTracks(tracks, startingAt: index, context: "home") }
    }
}

struct PublicHomeHeading: View {
    let title: String
    var body: some View { Text(title).font(.title2.weight(.bold)).accessibilityAddTraits(.isHeader) }
}

private struct PublicHomeTrackRail: View {
    let session: PublicYouTubeSession
    let tracks: [MusesDomain.Track]
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 14) {
                ForEach(tracks) { track in
                    Button {
                        if let index = tracks.firstIndex(where: { $0.id == track.id }) { session.playTracks(tracks, startingAt: index, context: "home:recent") }
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            PublicPlayerArtwork(videoID: track.publicVideoID?.rawValue)
                                .frame(width: 148, height: 148).clipShape(RoundedRectangle(cornerRadius: 16))
                            Text(track.displayTitle).font(.subheadline.weight(.semibold)).lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                            Text(track.displayArtist).font(.caption).foregroundStyle(.secondary).lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                        }.frame(width: 148, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("home.play." + track.id.rawValue)
                }
            }
        }.scrollIndicators(.hidden)
    }
}

struct PublicHomePlaylistShelves: View {
    let session: PublicYouTubeSession
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if !session.playlists.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    PublicHomeHeading(title: "Your playlists")
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: 14) {
                            ForEach(session.playlists.prefix(12)) { playlist in
                                let cover = playlist.trackIDs.first.flatMap { id in session.tracks.first { $0.id == id } }
                                Button { session.playPlaylist(playlist.id) } label: {
                                    VStack(alignment: .leading, spacing: 7) {
                                        PublicPlayerArtwork(videoID: cover?.publicVideoID?.rawValue)
                                            .frame(width: 148, height: 148).clipShape(RoundedRectangle(cornerRadius: 16))
                                        Text(playlist.name).font(.subheadline.weight(.semibold)).lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                                        Text("\(playlist.entryCount) tracks").font(.caption).foregroundStyle(.secondary)
                                    }.frame(width: 148, alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain).disabled(playlist.trackIDs.isEmpty)
                                    .accessibilityIdentifier("home.playlist." + playlist.id.uuidString)
                            }
                        }
                    }.scrollIndicators(.hidden)
                }
            }
            if session.signedIn {
                if !session.accountPlaylistPages.items.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        PublicHomeHeading(title: "On YouTube")
                        ScrollView(.horizontal) {
                            LazyHStack(alignment: .top, spacing: 14) {
                                ForEach(session.accountPlaylistPages.items.prefix(12), id: \.rowID) { item in
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
                if session.accountPlaylistPages.loading { ProgressView("Loading account playlists") }
                if let error = session.accountPlaylistPages.error {
                    HStack {
                        Text(error).font(.footnote).foregroundStyle(.secondary)
                        Button("Retry", systemImage: "arrow.clockwise") { Task { await session.loadAccountCollections() } }.frame(minHeight: 44)
                    }
                }
            }
        }.task { await session.refreshPlaylistNames() }
    }
}
