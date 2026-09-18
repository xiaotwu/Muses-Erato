import AppIntents
import SwiftUI
import WidgetKit

struct PlayPauseControlWidget: ControlWidget {
    static let kind = "com.xiaotwu.muses.erato.control.playpause"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: TogglePlaybackIntent()) {
                Label("Play/Pause", systemImage: "playpause.fill")
            }
        }
        .displayName("Play/Pause")
        .description("Toggle Muses playback from Control Center.")
    }
}

struct NextTrackControlWidget: ControlWidget {
    static let kind = "com.xiaotwu.muses.erato.control.next"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: NextTrackIntent()) {
                Label("Next", systemImage: "forward.fill")
            }
        }
        .displayName("Next Track")
        .description("Skip to the next song in Muses.")
    }
}
