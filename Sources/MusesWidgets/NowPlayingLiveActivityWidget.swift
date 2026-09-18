import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct NowPlayingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ListeningActivityAttributes.self) { context in
            lockScreen(context)
                .widgetURL(MusesAppGroup.nowPlayingURL)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    SnapshotArtworkView(fileName: context.state.artworkFileName)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(context.state.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Button(intent: TogglePlaybackIntent()) {
                            Label(
                                context.state.isPlaying ? "Pause" : "Play",
                                systemImage: context.state.isPlaying ? "pause.fill" : "play.fill"
                            )
                        }
                        .tint(Color(red: 0.98, green: 0.35, blue: 0.42))
                    }
                }
            } compactLeading: {
                SnapshotArtworkView(fileName: context.state.artworkFileName)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } compactTrailing: {
                Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
            } minimal: {
                Image(systemName: context.state.isPlaying ? "pause.fill" : "music.note")
            }
            .widgetURL(MusesAppGroup.nowPlayingURL)
        }
    }

    private func lockScreen(_ context: ActivityViewContext<ListeningActivityAttributes>) -> some View {
        HStack(spacing: 12) {
            SnapshotArtworkView(fileName: context.state.artworkFileName)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(context.state.artist)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
            Spacer()
            Button(intent: TogglePlaybackIntent()) {
                Image(systemName: context.state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .activityBackgroundTint(Color.black.opacity(0.35))
        .activitySystemActionForegroundColor(.white)
    }
}
