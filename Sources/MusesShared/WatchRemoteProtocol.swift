import Foundation

public struct WatchQueueItemSnapshot: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var artist: String

    public init(id: String, title: String, artist: String) {
        self.id = id
        self.title = title
        self.artist = artist
    }
}

public struct WatchRemoteState: Codable, Equatable, Sendable {
    public var trackId: String?
    public var title: String
    public var artist: String
    public var isPlaying: Bool
    public var position: Double
    public var duration: Double
    public var currentIndex: Int
    public var queue: [WatchQueueItemSnapshot]
    public var companionRunning: Bool
    public var updatedAt: Date

    public init(
        trackId: String?,
        title: String,
        artist: String,
        isPlaying: Bool,
        position: Double,
        duration: Double,
        currentIndex: Int,
        queue: [WatchQueueItemSnapshot],
        companionRunning: Bool,
        updatedAt: Date
    ) {
        self.trackId = trackId
        self.title = title
        self.artist = artist
        self.isPlaying = isPlaying
        self.position = position
        self.duration = duration
        self.currentIndex = currentIndex
        self.queue = queue
        self.companionRunning = companionRunning
        self.updatedAt = updatedAt
    }

    public static let empty = WatchRemoteState(
        trackId: nil,
        title: "",
        artist: "",
        isPlaying: false,
        position: 0,
        duration: 0,
        currentIndex: -1,
        queue: [],
        companionRunning: false,
        updatedAt: .distantPast
    )

    public var hasTrack: Bool { trackId != nil && !title.isEmpty }

    public var previousItem: WatchQueueItemSnapshot? {
        guard currentIndex > 0, currentIndex < queue.count else { return nil }
        return queue[currentIndex - 1]
    }

    public var nextItem: WatchQueueItemSnapshot? {
        guard currentIndex >= 0, currentIndex + 1 < queue.count else { return nil }
        return queue[currentIndex + 1]
    }

    public var signature: String {
        "\(trackId ?? "")|\(isPlaying)|\(currentIndex)|\(queue.count)|\(Int(position))"
    }
}

public enum WatchRemoteCommand: String, Codable, Sendable {
    case launch
    case pause
    case play
    case toggle
    case next
    case previous
    case playIndex
    case requestState
}

public struct WatchRemoteEnvelope: Equatable, Sendable {
    public var command: WatchRemoteCommand
    public var index: Int?

    public init(command: WatchRemoteCommand, index: Int? = nil) {
        self.command = command
        self.index = index
    }
}

public enum WatchRemoteCodec {
    public static let commandKey = "cmd"
    public static let indexKey = "index"
    public static let stateKey = "state"
    public static let artworkKey = "art"

    public static func encodeCommand(_ envelope: WatchRemoteEnvelope) -> [String: Any] {
        var payload: [String: Any] = [commandKey: envelope.command.rawValue]
        if let index = envelope.index {
            payload[indexKey] = index
        }
        return payload
    }

    public static func decodeCommand(_ message: [String: Any]) -> WatchRemoteEnvelope? {
        guard let raw = message[commandKey] as? String,
              let command = WatchRemoteCommand(rawValue: raw) else { return nil }
        let index = message[indexKey] as? Int
        return WatchRemoteEnvelope(command: command, index: index)
    }

    public static func encodeState(_ state: WatchRemoteState) -> Data? {
        try? JSONEncoder().encode(state)
    }

    public static func decodeState(_ data: Data) -> WatchRemoteState? {
        try? JSONDecoder().decode(WatchRemoteState.self, from: data)
    }

    public static func reply(state: WatchRemoteState, artwork: Data?) -> [String: Any] {
        var payload: [String: Any] = [:]
        if let data = encodeState(state) {
            payload[stateKey] = data
        }
        if let artwork, !artwork.isEmpty {
            payload[artworkKey] = artwork
        }
        return payload
    }

    public static func parseReply(_ reply: [String: Any]) -> (WatchRemoteState?, Data?) {
        let state: WatchRemoteState?
        if let data = reply[stateKey] as? Data {
            state = decodeState(data)
        } else {
            state = nil
        }
        return (state, reply[artworkKey] as? Data)
    }

    /// Rejects an out-of-range queue index instead of wrapping or inventing a track.
    public static func validatedPlayIndex(_ index: Int, queueCount: Int) -> Int? {
        guard index >= 0, index < queueCount else { return nil }
        return index
    }
}
