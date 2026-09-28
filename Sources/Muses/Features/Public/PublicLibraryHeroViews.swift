import SwiftUI
import MusesDomain

/// Adapted from macOS AlbumObjectView.heroCard: full-bleed artwork, lower
/// scrim, source tag and action pill. These are thumbnails, never players.
struct PublicLibraryCategories: View {
    @Bindable var session: PublicYouTubeSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(LibraryCategory.allCases) { category in
                        Button {
                            session.selectedCategory = category
                        } label: {
                            Label(category.rawValue, systemImage: category.symbol)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 16).frame(minHeight: 44)
                                .background(session.selectedCategory == category ? Color.accentColor.opacity(0.22) : Color(uiColor: .secondarySystemBackground), in: Capsule())
                                .overlay { Capsule().stroke(session.selectedCategory == category ? Color.accentColor : .clear) }
                        }
                        .buttonStyle(.plain).id(category)
                        .accessibilityAddTraits(session.selectedCategory == category ? .isSelected : [])
                        .accessibilityIdentifier("library.category.\(category.rawValue)")
                    }
                }.padding(.vertical, 3)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("library.categories")
            .onAppear { proxy.scrollTo(session.selectedCategory, anchor: .center) }
            .onChange(of: session.selectedCategory) { _, category in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { proxy.scrollTo(category, anchor: .center) }
            }
        }
    }
}

enum PublicLibraryPresentation: String, CaseIterable { case artwork = "Artwork", details = "Details" }

struct PublicLibraryHeroShelf: View {
    let session: PublicYouTubeSession
    let tracks: [MusesDomain.Track]
    var category: LibraryCategory = .videos
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var presentation: PublicLibraryPresentation = .artwork
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if category == .songs {
                    Text("Saved YouTube videos · song classification unavailable").font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Picker("Card presentation", selection: $presentation) {
                        Label("Artwork", systemImage: "rectangle.fill.on.rectangle.fill").tag(PublicLibraryPresentation.artwork)
                        Label("Details", systemImage: "list.bullet.rectangle").tag(PublicLibraryPresentation.details)
                    }
                } label: {
                    Label("Card presentation", systemImage: presentation == .artwork ? "rectangle.fill.on.rectangle.fill" : "list.bullet.rectangle")
                        .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                }.accessibilityIdentifier("library.presentation")
            }
            LazyVGrid(columns: typeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
                ForEach(tracks) { track in
                    PublicLibraryHeroCard(session: session, track: track, category: category, presentation: presentation)
                }
            }
        }
    }
}

private struct PublicLibraryHeroCard: View {
    let session: PublicYouTubeSession
    let track: MusesDomain.Track
    let category: LibraryCategory
    let presentation: PublicLibraryPresentation
    @State private var removing = false
    @State private var deleting = false
    private var videoID: VideoID? { if case .youtubeVideo(let id) = track.source { id } else { nil } }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("YouTube video", systemImage: "play.rectangle").font(.caption.weight(.semibold))
                Spacer()
                Menu {
                    if category == .favorites {
                        Button("Remove favorite", systemImage: "heart.slash", role: .destructive) { removing = true }
                    }
                    if category == .history {
                        Button("Remove history item", systemImage: "clock.badge.xmark", role: .destructive) { removing = true }
                    }
                    Button("Delete saved video", systemImage: "trash", role: .destructive) { deleting = true }
                } label: {
                    Label("Actions for \(track.title)", systemImage: "ellipsis").labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                }.accessibilityIdentifier("library.actions.\(track.id.rawValue)")
            }
            if presentation == .artwork { Spacer(minLength: 90) }
            NavigationLink { PublicVideoDetail(session: session, trackID: track.id) } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(track.title).font(.system(.title2, design: .serif, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                    Text(track.artist).font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
                .accessibilityIdentifier("library.detail.\(track.id.rawValue)")
            if presentation == .details {
                Text("Official embedded video").font(.caption)
                if let duration = track.durationMilliseconds { Text(Duration.milliseconds(duration).formatted(.time(pattern: .minuteSecond))).font(.caption).monospacedDigit() }
                Text("Codec and resolution are selected by YouTube.").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                if track.liked { Image(systemName: "heart.fill").accessibilityLabel("Favorite") }
                Spacer()
                Button { session.enqueueTrack(track) } label: { Label("Add to queue", systemImage: "text.badge.plus").labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44) }
                if let id = videoID {
                    Button { session.open(id, title: track.title) } label: {
                        Label("Open visible player", systemImage: "play.fill").labelStyle(.iconOnly)
                            .frame(minWidth: 58, minHeight: 44).background(.white.opacity(0.16), in: Capsule())
                    }.accessibilityIdentifier("library.play.\(track.id.rawValue)")
                }
            }
        }
        .padding(20)
        .foregroundStyle(presentation == .artwork ? Color.white : Color.primary)
        .background {
            if presentation == .artwork { PublicHeroArtwork(videoID: videoID?.rawValue) }
            else { Color(uiColor: .secondarySystemBackground) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.12)) }
        .confirmationDialog(category == .favorites ? "Remove this favorite?" : "Remove this video's local history?", isPresented: $removing, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if category == .favorites { session.removeFavorite(track.id) }
                else { session.removeHistoryItem(track.id) }
            }
        } message: { Text("The saved video and YouTube account stay unchanged.") }
        .confirmationDialog("Delete saved video?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete saved video", role: .destructive) { session.deleteSavedTrack(track.id) }
        } message: { Text("Removes this device's favorite, history, queue, playlist references, notes and bookmarks. YouTube is unchanged.") }
    }
}

private struct PublicHeroArtwork: View {
    let videoID: String?
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.18, green: 0.16, blue: 0.12)
                if let videoID, let url = URL(string: "https://i.ytimg.com/vi/\(videoID)/hqdefault.jpg") {
                    AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: {
                        Image(systemName: "play.rectangle").font(.largeTitle).foregroundStyle(.white.opacity(0.2))
                    }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
                }
                LinearGradient(colors: [.black.opacity(0.25), .black.opacity(0.45), .black.opacity(0.96)], startPoint: .top, endPoint: .bottom)
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
        case .videos, .songs: session.tracks.count
        case .favorites: session.favorites.count
        case .playlists: session.playlists.count
        case .history: session.history.count
        default: 0
        }
    }
    private var scope: String {
        switch category {
        case .videos, .songs: "saved videos, favorites, history, queue, playlist references, notes and bookmarks"
        case .favorites: "favorites only"
        case .playlists: "local playlists only"
        case .history: "local listening history only"
        default: ""
        }
    }
    var body: some View {
        Button { confirming = true } label: {
            Label("Clear \(category == .songs ? "saved videos" : category.rawValue.lowercased())", systemImage: "trash")
                .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
        }
        .disabled(count == 0)
        .accessibilityIdentifier("library.clear.\(category.rawValue)")
        .confirmationDialog("Clear \(count) local items?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Clear local items", role: .destructive) { session.clearLibraryItems(category) }
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
                Button { deleting = true } label: { Label("Delete \(playlist.name)", systemImage: "trash").labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44) }
            }
            Spacer(minLength: 60)
            NavigationLink { PublicPlaylistDetail(session: session, playlistID: playlist.id) } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(playlist.name).font(.system(.title2, design: .serif, weight: .semibold))
                    Text("\(playlist.entryCount) videos · On this device").font(.caption)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
                .accessibilityIdentifier("playlist.open.\(playlist.id)")
            HStack {
                Spacer()
                Button { session.enqueuePlaylist(playlist.id) } label: { Label("Add playlist to queue", systemImage: "text.badge.plus").labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44) }
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
            .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
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
