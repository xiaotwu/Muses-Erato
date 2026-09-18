import SwiftUI
import SwiftData

/// Compact-width track list: 44pt rows, swipe like / play next, collection-context play.
struct LibraryTrackListView: View {
    @Environment(PlaybackService.self) private var playback

    let title: String
    let emptyIcon: String
    let emptyTitle: String
    let emptySubtitle: String
    let tracks: [Track]

    var body: some View {
        let rows = CollectionTrackRow.songs(from: tracks)
        let snapshots = rows.map(\.snapshot)
        CollectionPage(
            title: title,
            subtitle: tr("\(tracks.count) songs", "\(tracks.count) 首歌曲", zhHant: "\(tracks.count) 首歌曲"),
            rows: rows,
            defaultSort: .titleAZ,
            currentTrack: playback.state.track,
            emptyIcon: emptyIcon,
            emptyTitle: emptyTitle,
            emptySubtitle: emptySubtitle,
            onPlay: { row in
                playback.playTrack(row.snapshot, context: snapshots, from: .songs)
            }
        ) {
            HStack(spacing: 8) {
                ChromeIconButton(
                    systemName: "play.fill",
                    help: tr("Play All", "播放全部"),
                    accessibility: tr("Play All", "播放全部")
                ) {
                    guard let first = snapshots.first else { return }
                    playback.playTrack(first, context: snapshots, from: .songs)
                }
                ChromeIconButton(
                    systemName: "shuffle",
                    help: tr("Shuffle", "随机播放"),
                    accessibility: tr("Shuffle", "随机播放")
                ) {
                    let shuffled = snapshots.shuffled()
                    guard let first = shuffled.first else { return }
                    playback.playTrack(first, context: shuffled, from: .songs)
                }
            }
        }
    }

}

struct FavoritesListIOSView: View {
    @Environment(LibraryService.self) private var library
    @Query(filter: #Predicate<Track> { $0.liked }, sort: \Track.title) private var tracks: [Track]

    var body: some View {
        let _ = library.likedRevision
        LibraryTrackListView(
            title: tr("Loved", "喜欢的音乐"),
            emptyIcon: "heart",
            emptyTitle: tr("No loved songs yet", "还没有喜欢的歌曲"),
            emptySubtitle: tr(
                "Swipe a song in your library to love it.",
                "在资料库里向左滑动歌曲即可喜欢。"
            ),
            tracks: tracks.filter { !$0.youTubeId.isEmpty }
        )
    }
}
