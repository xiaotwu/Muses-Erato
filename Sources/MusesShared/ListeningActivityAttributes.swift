import ActivityKit
import Foundation

public struct ListeningActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var title: String
        public var artist: String
        public var isPlaying: Bool
        public var trackId: String
        public var artworkFileName: String?

        public init(
            title: String,
            artist: String,
            isPlaying: Bool,
            trackId: String,
            artworkFileName: String? = nil
        ) {
            self.title = title
            self.artist = artist
            self.isPlaying = isPlaying
            self.trackId = trackId
            self.artworkFileName = artworkFileName
        }
    }

    public var startedAt: Date

    public init(startedAt: Date) {
        self.startedAt = startedAt
    }
}
