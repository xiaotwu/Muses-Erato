import AppIntents
import Foundation

public struct TogglePlaybackIntent: AudioPlaybackIntent {
    public static let title: LocalizedStringResource = "Play or Pause"
    public static let description = IntentDescription("Toggle playback in Muses.")

    public init() {}

    public func perform() async throws -> some IntentResult {
        NowPlayingSnapshotStore.shared.enqueue(.toggle)
        NowPlayingSnapshotStore.postDarwin()
        return .result()
    }
}

public struct NextTrackIntent: AudioPlaybackIntent {
    public static let title: LocalizedStringResource = "Next Track"
    public static let description = IntentDescription("Skip to the next song in Muses.")

    public init() {}

    public func perform() async throws -> some IntentResult {
        NowPlayingSnapshotStore.shared.enqueue(.next)
        NowPlayingSnapshotStore.postDarwin()
        return .result()
    }
}
