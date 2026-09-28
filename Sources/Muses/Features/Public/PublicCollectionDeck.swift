import SwiftUI
import MusesDomain

/// Constant-size view window: even 5,000 items create at most five artwork cards.
enum PublicDeckProjection {
    static func visibleIndices(count: Int, focus: Int) -> [Int] {
        guard count > 0 else { return [] }
        let center = min(count - 1, max(0, focus))
        return Array(max(0, center - 2)...min(count - 1, center + 2))
    }
    static func swipeStep(_ translation: CGSize) -> Int {
        guard abs(translation.width) > 32, abs(translation.width) > abs(translation.height) * 1.4 else { return 0 }
        return translation.width < 0 ? 1 : -1
    }
}

struct PublicCollectionDeck: View {
    let session: PublicYouTubeSession
    let tracks: [MusesDomain.Track]
    let category: LibraryCategory
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var focus = 0
    @State private var availableWidth: CGFloat = 320
    private var cardWidth: CGFloat { min(260, max(150, availableWidth * 0.62)) }
    private var footerHeight: CGFloat { typeSize.isAccessibilitySize ? 150 : 76 }
    private var stageHeight: CGFloat {
        let height = cardWidth + footerHeight
        let angle = CGFloat.pi * 16 / 180
        return max(height + 24, (height * cos(angle) + cardWidth * sin(angle)) * 0.87 + 50)
    }
    private var index: Int { min(max(0, focus), max(0, tracks.count - 1)) }
    private func move(_ amount: Int) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            focus = min(max(0, index + amount), max(0, tracks.count - 1))
        }
    }
    private func positionedCard(_ item: Int, width: CGFloat, footer: CGFloat) -> some View {
        let distance = item - index
        let track = tracks[item]
        let selected = distance == 0
        let scale: CGFloat = 1 - CGFloat(abs(distance)) * 0.065
        let offsetX = CGFloat(distance) * width * 0.39
        let offsetY = CGFloat(abs(distance)) * 13 + 12
        let identifier = selected ? "library.play." + track.id.rawValue : "collection.adjacent.\(distance)"
        return Button {
            if selected {
                if let video = track.publicVideoID { session.open(video, title: track.title) }
            } else { move(distance) }
        } label: {
            PublicDeckArtworkCard(track: track, width: width, footer: footer, focused: selected)
        }.buttonStyle(.plain)
            .scaleEffect(scale)
            .rotationEffect(.degrees(Double(distance) * 8))
            .offset(x: offsetX, y: offsetY)
            .zIndex(Double(10 - abs(distance)))
            .accessibilityLabel(track.title + ", " + track.artist)
            .accessibilityValue("\(index + 1) of \(tracks.count)")
            .accessibilityHint("Double tap to open the visible video player. Swipe up or down to choose another card.")
            .accessibilityAdjustableAction { direction in
                switch direction { case .increment: move(1); case .decrement: move(-1); @unknown default: break }
            }
            .accessibilityHidden(!selected)
            .accessibilityIdentifier(identifier)
    }
    var body: some View {
        if !tracks.isEmpty {
            VStack(spacing: 4) {
                GeometryReader { geometry in
                    let width = min(260.0, max(150.0, geometry.size.width * 0.62))
                    let footer = footerHeight
                    ZStack(alignment: .top) {
                        ForEach(PublicDeckProjection.visibleIndices(count: tracks.count, focus: index), id: \.self) { item in
                            positionedCard(item, width: width, footer: footer)
                        }
                    }.frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                        .contentShape(Rectangle())
                        .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { move(PublicDeckProjection.swipeStep($0.translation)) })
                }
                .frame(height: stageHeight)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
                .clipped()
                .accessibilityIdentifier("collection.deck")
                HStack(spacing: 4) {
                    Button { move(-1) } label: { Label("Previous card", systemImage: "chevron.left").labelStyle(.iconOnly).frame(width: 44, height: 44) }
                        .disabled(index == 0).accessibilityIdentifier("collection.previous")
                    Text("\(index + 1) / \(tracks.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        .frame(minWidth: 62).accessibilityIdentifier("collection.position")
                    Button { move(1) } label: { Label("Next card", systemImage: "chevron.right").labelStyle(.iconOnly).frame(width: 44, height: 44) }
                        .disabled(index == tracks.count - 1).accessibilityIdentifier("collection.next")
                    Spacer(minLength: 0)
                    NavigationLink { PublicVideoDetail(session: session, trackID: tracks[index].id) } label: {
                        Label("Video details", systemImage: "info.circle").labelStyle(.iconOnly).frame(width: 44, height: 44)
                    }.accessibilityIdentifier("library.detail.\(tracks[index].id.rawValue)")
                    Button { session.enqueueTrack(tracks[index]) } label: {
                        Label("Add to queue", systemImage: "text.badge.plus").labelStyle(.iconOnly).frame(width: 44, height: 44)
                    }
                    PublicTrackActions(session: session, track: tracks[index], category: category)
                }.buttonStyle(.plain)
            }.onChange(of: tracks.count) { _, _ in focus = index }
        }
    }
}

struct PublicDeckArtworkCard: View {
    let track: MusesDomain.Track?
    let width: CGFloat
    var footer: CGFloat = 66
    var focused = false
    var body: some View {
        let height = width + footer
        ZStack(alignment: .bottomLeading) {
            PublicCollectionArtwork(videoID: track?.publicVideoID?.rawValue)
                .frame(width: width, height: height)
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.45), location: 0.45),
                .init(color: .black.opacity(0.85), location: 0.75),
                .init(color: .black.opacity(0.95), location: 1)
            ], startPoint: .top, endPoint: .bottom)
                .frame(height: height * 0.58)
            VStack(alignment: .leading, spacing: 4) {
                Text(track?.title ?? "Unavailable entry").font(.subheadline.weight(.bold)).lineLimit(1)
                    .shadow(color: .black.opacity(0.7), radius: 3, y: 1)
                Text(track?.artist ?? "Kept in playlist").font(.caption).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                HStack {
                    if track?.liked == true { Image(systemName: "heart.fill").font(.caption).accessibilityLabel("Favorite") }
                    Spacer(minLength: 0)
                    Image(systemName: track == nil ? "exclamationmark" : (focused ? "play.fill" : "viewfinder"))
                        .font(.caption.weight(.semibold)).frame(width: 28, height: 28)
                        .background(.black.opacity(0.6), in: Circle())
                        .overlay { Circle().stroke(.white.opacity(0.35)) }
                }.padding(.top, 2)
            }.padding(.horizontal, 12).padding(.bottom, 10)
        }.foregroundStyle(.white).frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(focused ? 0.5 : 0.15), lineWidth: focused ? 1.5 : 1) }
            .shadow(color: .black.opacity(0.24), radius: focused ? 12 : 5, y: 5)
    }
}

private struct PublicCollectionArtwork: View {
    let videoID: String?
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(uiColor: .secondarySystemFill)
                if let videoID, let url = URL(string: "https://i.ytimg.com/vi/\(videoID)/hqdefault.jpg") {
                    AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: {
                        Image(systemName: "play.rectangle").font(.largeTitle).foregroundStyle(.secondary)
                    }
                } else { Image(systemName: "rectangle.slash").font(.largeTitle).foregroundStyle(.secondary) }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.accessibilityHidden(true).allowsHitTesting(false)
    }
}

/// Rendering keeps original occurrence positions, including repeated and missing entries.
/// Uses the session’s occurrence-aware visible-player context without emulating playback.
struct PublicPlaylistBlock: View {
    let session: PublicYouTubeSession
    let playlist: LocalPlaylist
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var focusedEntry: Int? = 0
    @State private var clearing = false
    @State private var deleting = false
    private var entries: [TrackID?] { playlist.occurrences?.map(\.trackID) ?? playlist.trackIDs.map(Optional.some) }
    private var firstPlayable: Int? { entries.firstIndex { id in id.map { value in session.tracks.contains { $0.id == value } } ?? false } }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 4) { heading; Spacer(minLength: 0); actions }
                VStack(alignment: .leading, spacing: 0) { heading; actions }
            }
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 10) {
                            ForEach(entries.indices, id: \.self) { index in
                                let track = entries[index].flatMap { id in session.tracks.first { $0.id == id } }
                                Button { session.playPlaylist(playlist.id, startingAtOccurrenceIndex: index) } label: {
                                    PublicDeckArtworkCard(track: track, width: typeSize.isAccessibilitySize ? 210 : 142, footer: typeSize.isAccessibilitySize ? 116 : 62, focused: track != nil)
                                }.buttonStyle(.plain).disabled(track == nil)
                                    .id(index).accessibilityLabel("Entry \(index + 1), \(track?.title ?? "Unavailable")")
                                    .accessibilityIdentifier("playlist.entry.\(playlist.id).\(index)")
                            }
                        }.scrollTargetLayout().padding(.vertical, 6)
                    }.scrollPosition(id: $focusedEntry, anchor: .leading).scrollIndicators(.hidden).accessibilityIdentifier("playlist.entries.\(playlist.id)")
                    HStack(spacing: 0) {
                        Button { browse(-1, proxy: proxy) } label: { Label("Previous entries in \(playlist.name)", systemImage: "chevron.left").labelStyle(.iconOnly).frame(width: 44, height: 44) }
                            .disabled(entries.isEmpty || (focusedEntry ?? 0) == 0)
                        Spacer()
                        Button { browse(1, proxy: proxy) } label: { Label("Next entries in \(playlist.name)", systemImage: "chevron.right").labelStyle(.iconOnly).frame(width: 44, height: 44) }
                            .disabled(entries.isEmpty || (focusedEntry ?? 0) >= entries.count - 1)
                    }.buttonStyle(.plain)
                }
            }
        }
        .confirmationDialog("Clear this local playlist?", isPresented: $clearing, titleVisibility: .visible) {
            Button("Clear playlist", role: .destructive) { session.editPlaylist(playlist.id) { $0.removeAllEntries() } }
        } message: { Text("Saved videos remain. YouTube is unchanged.") }
        .confirmationDialog("Delete this local playlist?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete playlist", role: .destructive) { session.deletePlaylist(playlist.id) }
        } message: { Text("Saved videos remain. YouTube is unchanged.") }
    }
    private var heading: some View {
        VStack(alignment: .leading, spacing: 2) {
            NavigationLink { PublicPlaylistDetail(session: session, playlistID: playlist.id) } label: {
                Text(playlist.name).font(.headline).lineLimit(2)
            }.buttonStyle(.plain).frame(minHeight: 44, alignment: .leading)
                .accessibilityIdentifier("playlist.open.\(playlist.id)")
            Text("\(playlist.entryCount) entries").font(.caption).foregroundStyle(.secondary)
        }
    }
    private var actions: some View {
        HStack(spacing: 0) {
            Button { if let index = firstPlayable { session.playPlaylist(playlist.id, startingAtOccurrenceIndex: index) } } label: {
                Label("Play \(playlist.name)", systemImage: "play.fill").labelStyle(.iconOnly).frame(width: 44, height: 44)
            }.disabled(firstPlayable == nil)
            Button { session.enqueuePlaylist(playlist.id) } label: {
                Label("Add \(playlist.name) to queue", systemImage: "text.badge.plus").labelStyle(.iconOnly).frame(width: 44, height: 44)
            }.disabled(firstPlayable == nil)
            Menu {
                NavigationLink { PublicPlaylistDetail(session: session, playlistID: playlist.id) } label: { Label("Open details or rename", systemImage: "pencil") }
                Button("Clear playlist", systemImage: "rectangle.stack.badge.minus", role: .destructive) { clearing = true }
                    .disabled(playlist.entryCount == 0)
                Button("Delete playlist", systemImage: "trash", role: .destructive) { deleting = true }
            } label: { Label("Actions for \(playlist.name)", systemImage: "ellipsis").labelStyle(.iconOnly).frame(width: 44, height: 44) }
        }.buttonStyle(.plain)
    }
    private func browse(_ step: Int, proxy: ScrollViewProxy) {
        let next = min(max(0, (focusedEntry ?? 0) + step), max(0, entries.count - 1))
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { focusedEntry = next; proxy.scrollTo(next, anchor: .leading) }
    }
}
