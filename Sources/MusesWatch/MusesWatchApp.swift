import SwiftUI

@main
struct MusesWatchApp: App {
    @State private var session = WatchRemoteSession()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchHeroView(session: session)
            }
            .preferredColorScheme(.dark)
            .fontDesign(.default)
        }
    }
}
