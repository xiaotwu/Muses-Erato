import AppIntents
import SwiftUI
import WidgetKit

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let snapshot: NowPlayingSnapshot
}

struct NowPlayingProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowPlayingEntry {
        NowPlayingEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        completion(NowPlayingEntry(date: Date(), snapshot: NowPlayingSnapshotStore.shared.load() ?? .empty))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        let entry = NowPlayingEntry(date: Date(), snapshot: NowPlayingSnapshotStore.shared.load() ?? .empty)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

struct NowPlayingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.xiaotwu.muses.erato.nowPlaying", provider: NowPlayingProvider()) { entry in
            NowPlayingWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.black
                }
        }
        .configurationDisplayName("Now Playing")
        .description("See what’s playing in Muses, or open the app to start.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

struct NowPlayingWidgetView: View {
    let entry: NowPlayingEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let snapshot = entry.snapshot
        switch family {
        case .accessoryCircular:
            Link(destination: MusesAppGroup.nowPlayingURL) {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: snapshot.isPlaying ? "pause.fill" : "play.fill")
                }
            }
        case .accessoryRectangular:
            Link(destination: MusesAppGroup.nowPlayingURL) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.hasTrack ? snapshot.title : "Muses")
                        .font(.headline)
                        .lineLimit(1)
                    Text(snapshot.hasTrack ? snapshot.artist : "Tap to play")
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        default:
            HStack(spacing: 12) {
                Link(destination: MusesAppGroup.nowPlayingURL) {
                    HStack(spacing: 12) {
                        SnapshotArtworkView(fileName: snapshot.artworkFileName)
                            .frame(width: family == .systemSmall ? 52 : 64, height: family == .systemSmall ? 52 : 64)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot.hasTrack ? snapshot.title : "Nothing playing")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            Text(snapshot.hasTrack ? snapshot.artist : "Open Muses to play")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                            if family == .systemSmall, snapshot.hasTrack {
                                Image(systemName: snapshot.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .foregroundStyle(Color(red: 0.98, green: 0.35, blue: 0.42))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                if family == .systemMedium, snapshot.hasTrack {
                    Button(intent: TogglePlaybackIntent()) {
                        Image(systemName: snapshot.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color(red: 0.98, green: 0.35, blue: 0.42))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }
}
