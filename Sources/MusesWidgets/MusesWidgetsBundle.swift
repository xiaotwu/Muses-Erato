import SwiftUI
import WidgetKit

@main
struct MusesWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NowPlayingWidget()
        NowPlayingLiveActivityWidget()
        PlayPauseControlWidget()
        NextTrackControlWidget()
    }
}
