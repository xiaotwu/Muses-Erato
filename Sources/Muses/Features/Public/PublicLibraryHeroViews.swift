import SwiftUI
import MusesDomain

/// Adapted from macOS AlbumObjectView.heroCard: full-bleed artwork, lower
/// scrim, source tag and action pill. These are thumbnails, never players.
struct PublicLibraryCategories: View {
    @Bindable var session: PublicYouTubeSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Namespace private var categoryGlass
    @ViewBuilder private func categoryLabel(_ category: LibraryCategory) -> some View {
        let label = Text(category == .videos ? "All Saved" : category.rawValue)
            .font(.subheadline.weight(session.selectedCategory == category ? .semibold : .regular))
            .foregroundStyle(.primary).padding(.horizontal, 14).frame(minHeight: 44)
        if session.selectedCategory == category {
            if #available(iOS 26, *), !reduceTransparency {
                label.glassEffect(.regular.interactive(), in: .capsule)
                    .glassEffectID("library.category.selection", in: categoryGlass)
            } else { label.background(PublicStyle.surface, in: Capsule()) }
        } else { label }
    }
    @Environment(\.dynamicTypeSize) private var typeSize
    private let categories: [LibraryCategory] = [.videos, .playlists, .favorites, .history]
    private func button(_ category: LibraryCategory) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) { session.selectedCategory = category }
        } label: { categoryLabel(category) }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(category == .videos ? "All Saved" : category.rawValue)
            .accessibilityAddTraits(session.selectedCategory == category ? .isSelected : [])
            .accessibilityIdentifier("library.category.\(category.rawValue)")
    }
    var body: some View {
        ViewThatFits(in: .horizontal) {
            if !typeSize.isAccessibilitySize {
                HStack(spacing: 4) { ForEach(categories) { button($0) } }.fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) { button(.videos); button(.playlists) }
                HStack(spacing: 4) { button(.favorites); button(.history) }
            }.fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 4) { ForEach(categories) { button($0) } }
        }
    }

}

enum PublicLibraryPresentation: String, CaseIterable { case cards = "Cards", list = "List" }

/// Songs are the saved local-playlist union, matching the macOS Songs collection.
/// Unrelated saved videos must never be swept up by the Songs clear action.
enum PublicCollectionScope {
    static func songs(tracks: [MusesDomain.Track], playlists: [LocalPlaylist]) -> [MusesDomain.Track] {
        let byID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        var seen = Set<TrackID>()
        return playlists.flatMap(\.trackIDs).filter { seen.insert($0).inserted }.compactMap { byID[$0] }
    }
}

struct PublicLibraryPresentationControl: View {
    @Binding var presentation: PublicLibraryPresentation
    var body: some View {
        HStack(spacing: 2) {
            ForEach(PublicLibraryPresentation.allCases, id: \.self) { mode in
                Button { presentation = mode } label: {
                    Label(mode.rawValue, systemImage: mode == .cards ? "rectangle.stack" : "list.bullet")
                        .labelStyle(.iconOnly).font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44).contentShape(Capsule())
                        .background(presentation == mode ? Color(uiColor: .tertiarySystemBackground) : .clear, in: Capsule())
                }.buttonStyle(.plain).accessibilityLabel(mode.rawValue)
                    .accessibilityAddTraits(presentation == mode ? .isSelected : [])
                    .accessibilityIdentifier("library.presentation.\(mode.rawValue)")
            }
        }.fixedSize().padding(3)
            .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
    }
}

struct PublicLibraryHeroShelf: View {
    let session: PublicYouTubeSession
    let tracks: [MusesDomain.Track]
    var category: LibraryCategory = .videos
    @Environment(\.dynamicTypeSize) private var typeSize
    @Binding var presentation: PublicLibraryPresentation
    private var displayed: [MusesDomain.Track] {
        category == .songs ? PublicCollectionScope.songs(tracks: tracks, playlists: session.playlists) : tracks
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if displayed.isEmpty {
                ContentUnavailableView("No songs in playlists", systemImage: "music.note.list", description: Text("Add videos to a local playlist to see them here."))
            } else if presentation == .cards && !typeSize.isAccessibilitySize {
                PublicCollectionDeck(session: session, tracks: displayed, category: category)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(displayed) { track in
                        PublicCollectionRow(session: session, track: track, category: category, onPlay: {
                            if let index = displayed.firstIndex(where: { $0.id == track.id }) {
                                session.playTracks(displayed, startingAt: index, context: "collection:" + category.rawValue)
                            }
                        })
                        Divider().padding(.leading, 62)
                    }
                }
            }
        }
    }
}

struct PublicCollectionRow: View {
    let session: PublicYouTubeSession
    let track: MusesDomain.Track
    let category: LibraryCategory
    @Environment(\.dynamicTypeSize) private var typeSize
    private var navigation: some View {
        Button {
            if let onPlay { onPlay() }
            else if let video = track.publicVideoID { session.open(video, title: track.title, artist: track.artist) }
        } label: {
            HStack(spacing: 10) {
                PublicCompactHeroCover(videoID: track.publicVideoID?.rawValue)
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.displayTitle).font(.body.weight(.medium)).lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                    Text(track.displayArtist).font(.caption).foregroundStyle(.secondary).lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("library.row.play.\(track.id.rawValue)")
    }
    private var actions: some View {
        HStack(spacing: 0) {
            Button { if let onPlay { onPlay() }
                else if let video = track.publicVideoID { session.open(video, title: track.title) } } label: {
                Label("Play \(track.title)", systemImage: "play.fill").labelStyle(.iconOnly).font(.system(size: 18)).frame(width: 44, height: 44).contentShape(Rectangle())
            }.disabled(track.publicVideoID == nil).accessibilityIdentifier("library.play.\(track.id.rawValue)")
            Button { session.enqueueTrack(track) } label: {
                Label("Add \(track.title) to queue", systemImage: "text.badge.plus").labelStyle(.iconOnly).font(.system(size: 18)).frame(width: 44, height: 44).contentShape(Rectangle())
            }
            PublicTrackActions(session: session, track: track, category: category)
        }.buttonStyle(.plain)
    }
    var onPlay: (() -> Void)? = nil
    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) { navigation; actions }
            } else { HStack(spacing: 4) { navigation; actions } }
        }.padding(.vertical, 6)
    }
}

struct PublicTrackActions: View {
    let session: PublicYouTubeSession
    let track: MusesDomain.Track
    let category: LibraryCategory
    @State private var removing = false
    @State private var deleting = false
    var body: some View {
        Menu {
            NavigationLink { PublicVideoDetail(session: session, trackID: track.id) } label: { Label("Video details", systemImage: "info.circle") }
            if category != .favorites { Button(track.liked ? "Remove favorite" : "Favorite", systemImage: track.liked ? "heart.slash" : "heart") { session.toggleFavorite(track.id) } }
            PublicAddToPlaylistMenu(session: session, track: track)
            if category == .favorites {
                Button("Remove favorite", systemImage: "heart.slash", role: .destructive) { removing = true }
            }
            if category == .history {
                Button("Remove history item", systemImage: "clock.badge.xmark", role: .destructive) { removing = true }
            }
            Button("Delete saved video", systemImage: "trash", role: .destructive) { deleting = true }
        } label: {
            Label("Actions for \(track.title)", systemImage: "ellipsis").labelStyle(.iconOnly).font(.system(size: 18)).frame(width: 44, height: 44).contentShape(Rectangle())
        }.accessibilityIdentifier("library.actions.\(track.id.rawValue)")
            .confirmationDialog(category == .favorites ? "Remove this favorite?" : "Remove this video's local history?", isPresented: $removing, titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    if category == .favorites { session.removeFavorite(track.id) }
                    else { session.removeHistoryItem(track.id) }
                }
            }
            .confirmationDialog("Delete saved video?", isPresented: $deleting, titleVisibility: .visible) {
                Button("Delete saved video", role: .destructive) { session.deleteSavedTrack(track.id) }
            } message: { Text("Removes this device’s favorite, history, queue, playlist references, notes and bookmarks. YouTube is unchanged.") }
    }
}

extension MusesDomain.Track {
    var displayTitle: String { metadataOrigin == .placeholder ? "Video details unavailable" : title }
    var displayArtist: String { artist == "YouTube" ? "Unknown artist" : artist }
    var publicVideoID: VideoID? { if case .youtubeVideo(let id) = source { id } else { nil } }
}

struct PublicHeroArtwork: View {
    let videoID: String?
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.18, green: 0.16, blue: 0.12)
                PublicPlayerArtwork(videoID: videoID)
                LinearGradient(colors: [.black.opacity(0.25), .black.opacity(0.45), .black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
            }
        }.accessibilityHidden(true).allowsHitTesting(false)
    }
}

struct PublicLibraryClearButton: View {
    let session: PublicYouTubeSession
    let category: LibraryCategory
    @State private var confirming = false
    private var count: Int {
        switch category {
        case .videos: session.libraryTracks.count
        case .songs: PublicCollectionScope.songs(tracks: session.tracks, playlists: session.playlists).count
        case .favorites: session.libraryFavorites.count
        case .playlists: session.playlists.count
        case .history: session.libraryHistory.count
        default: 0
        }
    }
    private var scope: String {
        switch category {
        case .videos: "all saved videos and their favorites, history, queue references, playlist memberships, notes and bookmarks"
        case .songs: "only saved videos in your local playlists, and their favorites, history, queue entries, notes and bookmarks"
        case .favorites: "favorites only"
        case .playlists: "local playlists only"
        case .history: "local listening history only"
        default: ""
        }
    }
    var body: some View {
        Menu {
            Button(role: .destructive) { confirming = true } label: {
                Label(category == .videos ? "Delete all saved videos" : "Clear \(category.rawValue.lowercased())", systemImage: "trash")
            }
            .disabled(count == 0)
            .accessibilityIdentifier("library.clear.\(category.rawValue)")
        } label: { PublicIconActionLabel(title: "Collection actions", symbol: "ellipsis") }
        .accessibilityIdentifier("library.collectionActions")
        .confirmationDialog("Clear \(count) local items?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Clear local items", role: .destructive) {
                if category == .songs {
                    session.deleteSavedTracks(Set(PublicCollectionScope.songs(tracks: session.tracks, playlists: session.playlists).map(\.id)))
                } else { session.clearLibraryItems(category) }
            }
        } message: { Text("Removes \(scope) from this device. YouTube is unchanged.") }
    }
}

struct PublicLocalPlaylistHero: View {
    let session: PublicYouTubeSession
    let playlist: LocalPlaylist
    @State private var deleting = false
    private var firstVideo: String? {
        guard let id = playlist.trackIDs.first, let track = session.tracks.first(where: { $0.id == id }), case .youtubeVideo(let video) = track.source else { return nil }
        return video.rawValue
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Local playlist", systemImage: "music.note.list").font(.caption)
                Spacer()
                Button { deleting = true } label: { Label("Delete \(playlist.name)", systemImage: "trash").labelStyle(.iconOnly).font(.system(size: 18)).frame(minWidth: 44, minHeight: 44) }
            }
            Spacer(minLength: 60)
            NavigationLink { PublicPlaylistDetail(session: session, playlistID: playlist.id) } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(playlist.name).font(.system(.title2, design: .serif, weight: .semibold))
                    Text("\(PublicStyle.videoCount(playlist.entryCount)) · On this device").font(.caption)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
                .accessibilityIdentifier("playlist.open.\(playlist.id)")
            HStack {
                Spacer()
                Button { session.enqueuePlaylist(playlist.id) } label: { Label("Add playlist to queue", systemImage: "text.badge.plus").labelStyle(.iconOnly).font(.system(size: 18)).frame(minWidth: 44, minHeight: 44) }
                    .disabled(playlist.trackIDs.isEmpty)
            }
        }.padding(20).foregroundStyle(.white)
            .background { PublicHeroArtwork(videoID: firstVideo) }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .confirmationDialog("Delete local playlist?", isPresented: $deleting, titleVisibility: .visible) {
                Button("Delete playlist", role: .destructive) { session.deletePlaylist(playlist.id) }
            } message: { Text("Saved videos remain. YouTube is unchanged.") }
    }
}

struct PublicPlaylistClearButton: View {
    let session: PublicYouTubeSession
    let playlist: LocalPlaylist
    @State private var clearing = false
    var body: some View {
        Button("Clear playlist videos", systemImage: "trash") { clearing = true }
            .labelStyle(.iconOnly).font(.system(size: 18)).frame(minWidth: 44, minHeight: 44)
            .disabled(playlist.entryCount == 0)
            .accessibilityIdentifier("playlist.clear")
            .confirmationDialog("Clear this local playlist?", isPresented: $clearing, titleVisibility: .visible) {
                Button("Clear playlist videos", role: .destructive) {
                    session.editPlaylist(playlist.id) { value in
                        value.removeAllEntries()
                    }
                }
            } message: { Text("Saved videos remain. YouTube is unchanged.") }
    }
}
