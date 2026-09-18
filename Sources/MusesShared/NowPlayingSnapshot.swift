import Foundation

public struct NowPlayingSnapshot: Codable, Equatable, Sendable {
    public var trackId: String?
    public var title: String
    public var artist: String
    public var isPlaying: Bool
    public var artworkFileName: String?
    public var updatedAt: Date

    public init(
        trackId: String?,
        title: String,
        artist: String,
        isPlaying: Bool,
        artworkFileName: String?,
        updatedAt: Date
    ) {
        self.trackId = trackId
        self.title = title
        self.artist = artist
        self.isPlaying = isPlaying
        self.artworkFileName = artworkFileName
        self.updatedAt = updatedAt
    }

    public static let empty = NowPlayingSnapshot(
        trackId: nil,
        title: "Muses",
        artist: "Open the app to play",
        isPlaying: false,
        artworkFileName: nil,
        updatedAt: .distantPast
    )

    public var hasTrack: Bool { trackId != nil }

    /// Current track, or the last one if the queue is empty so home-screen widgets stay useful.
    public static func currentOrRecent(
        trackId: String?,
        title: String,
        artist: String,
        isPlaying: Bool,
        previous: NowPlayingSnapshot?,
        now: Date = Date()
    ) -> NowPlayingSnapshot {
        if let trackId {
            let artwork = previous?.trackId == trackId ? previous?.artworkFileName : nil
            return NowPlayingSnapshot(
                trackId: trackId,
                title: title,
                artist: artist,
                isPlaying: isPlaying,
                artworkFileName: artwork,
                updatedAt: now
            )
        }
        if var previous, previous.hasTrack {
            previous.isPlaying = false
            previous.updatedAt = now
            return previous
        }
        return .empty
    }
}

public enum PlaybackRemoteCommand: String, Codable, Sendable {
    case toggle
    case next
    case previous
}

public enum LiveActivityDecision: Equatable, Sendable {
    case none
    case start
    case update
    case end
    case restart
}

public struct LiveActivitySessionPolicy: Equatable, Sendable {
    public var pauseTimeout: TimeInterval
    public var maxDuration: TimeInterval

    public init(
        pauseTimeout: TimeInterval = 10 * 60,
        maxDuration: TimeInterval = 8 * 60 * 60
    ) {
        self.pauseTimeout = pauseTimeout
        self.maxDuration = maxDuration
    }

    public func decide(
        enabled: Bool,
        hasTrack: Bool,
        isPlaying: Bool,
        hasActivity: Bool,
        startedAt: Date?,
        lastPausedAt: Date?,
        now: Date
    ) -> LiveActivityDecision {
        if !enabled || !hasTrack {
            return hasActivity ? .end : .none
        }
        if isPlaying {
            if !hasActivity { return .start }
            if let startedAt, now.timeIntervalSince(startedAt) >= maxDuration {
                return .restart
            }
            return .update
        }
        guard hasActivity else { return .none }
        if let lastPausedAt, now.timeIntervalSince(lastPausedAt) >= pauseTimeout {
            return .end
        }
        return .update
    }
}

public enum MusesAppGroup {
    public static let identifier = "group.com.xiaotwu.muses.erato"
    public static let snapshotKey = "nowPlaying.snapshot"
    public static let commandKey = "nowPlaying.pendingCommand"
    public static let darwinName = "com.xiaotwu.muses.erato.playback"
    public static let nowPlayingURL = URL(string: "muses-erato://nowplaying")!
}

public final class NowPlayingSnapshotStore: @unchecked Sendable {
    public static let shared = NowPlayingSnapshotStore(
        defaults: UserDefaults(suiteName: MusesAppGroup.identifier) ?? .standard,
        containerURL: FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: MusesAppGroup.identifier)
    )

    private let defaults: UserDefaults
    private let containerURL: URL?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults, containerURL: URL?) {
        self.defaults = defaults
        self.containerURL = containerURL
    }

    public func save(_ snapshot: NowPlayingSnapshot) {
        if let data = try? encoder.encode(snapshot) {
            defaults.set(data, forKey: MusesAppGroup.snapshotKey)
        }
    }

    public func load() -> NowPlayingSnapshot? {
        guard let data = defaults.data(forKey: MusesAppGroup.snapshotKey) else { return nil }
        return try? decoder.decode(NowPlayingSnapshot.self, from: data)
    }

    public func clear() {
        defaults.removeObject(forKey: MusesAppGroup.snapshotKey)
    }

    public func enqueue(_ command: PlaybackRemoteCommand) {
        defaults.set(command.rawValue, forKey: MusesAppGroup.commandKey)
    }

    public func dequeue() -> PlaybackRemoteCommand? {
        guard let raw = defaults.string(forKey: MusesAppGroup.commandKey) else { return nil }
        defaults.removeObject(forKey: MusesAppGroup.commandKey)
        return PlaybackRemoteCommand(rawValue: raw)
    }

    public func artworkURL(fileName: String) -> URL? {
        containerURL?.appendingPathComponent(fileName)
    }

    public func writeArtwork(_ data: Data, fileName: String = "now-playing.jpg") -> String? {
        guard let url = artworkURL(fileName: fileName) else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    public func artworkData(fileName: String?) -> Data? {
        guard let fileName, let url = artworkURL(fileName: fileName) else { return nil }
        return try? Data(contentsOf: url)
    }

    public static func postDarwin() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(MusesAppGroup.darwinName as CFString),
            nil,
            nil,
            true
        )
    }
}
