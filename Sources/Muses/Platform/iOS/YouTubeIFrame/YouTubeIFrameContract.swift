import Foundation

/// P1-local boundary. P4 maps these values to P2's PlaybackSource/Event types.
struct IFrameVideoID: Equatable, Hashable, Sendable {
    let rawValue: String

    init?(_ rawValue: String) {
        guard rawValue.utf8.count == 11,
              rawValue.utf8.allSatisfy({ ($0 >= 65 && $0 <= 90) ||
                  ($0 >= 97 && $0 <= 122) || ($0 >= 48 && $0 <= 57) ||
                  $0 == 45 || $0 == 95 }) else { return nil }
        self.rawValue = rawValue
    }

    var watchURL: URL { URL(string: "https://www.youtube.com/watch?v=\(rawValue)")! }
}

enum IFrameFailure: Equatable, Sendable {
    case invalidParameter
    case playerUnavailable
    case unavailableVideo
    case embeddingDisabled
    case missingClientIdentity
    case network
    case unknownPlayerError(Int)
}

enum IFrameEventKind: Equatable, Sendable {
    case loading, ready, playing, paused, buffering, ended, cued, playBlocked
    case time(position: Double, duration: Double)
    case failed(IFrameFailure)
}

struct IFrameEvent: Equatable, Sendable {
    let videoID: IFrameVideoID
    let generation: UInt64
    let kind: IFrameEventKind
}

/// Rejects messages from old players, removed views, and unexpected origins.
struct IFrameEventGate {
    let expectedOriginHost: String
    private(set) var videoID: IFrameVideoID?
    private(set) var generation: UInt64 = 0
    private(set) var isAlive = true
    private var endedGeneration: UInt64?

    init(expectedOriginHost: String) {
        self.expectedOriginHost = expectedOriginHost
    }

    mutating func load(_ id: IFrameVideoID) -> UInt64 {
        generation &+= 1
        videoID = id
        endedGeneration = nil
        return generation
    }

    mutating func clear() {
        generation &+= 1
        videoID = nil
        endedGeneration = nil
    }

    mutating func teardown() {
        generation &+= 1
        videoID = nil
        isAlive = false
    }

    mutating func accept(_ message: [String: Any], isMainFrame: Bool,
                         originScheme: String, originHost: String) -> IFrameEvent? {
        guard isAlive, isMainFrame, originScheme == "https",
              originHost == expectedOriginHost,
              let id = videoID,
              message["videoID"] as? String == id.rawValue,
              let rawGeneration = message["generation"] as? String,
              rawGeneration == String(generation),
              let name = message["kind"] as? String else { return nil }

        let kind: IFrameEventKind
        switch name {
        case "playBlocked": kind = .playBlocked
        case "ready": kind = .ready
        case "playing": kind = .playing
        case "paused": kind = .paused
        case "buffering": kind = .buffering
        case "cued": kind = .cued
        case "ended":
            guard endedGeneration != generation else { return nil }
            endedGeneration = generation
            kind = .ended
        case "time":
            guard let position = message["position"] as? Double,
                  let duration = message["duration"] as? Double,
                  position.isFinite, duration.isFinite,
                  position >= 0, duration >= 0 else { return nil }
            kind = .time(position: position, duration: duration)
        case "error":
            guard let code = message["code"] as? Int else { return nil }
            let failure: IFrameFailure
            switch code {
            case 2: failure = .invalidParameter
            case 5: failure = .playerUnavailable
            case 100: failure = .unavailableVideo
            case 101, 150: failure = .embeddingDisabled
            case 153: failure = .missingClientIdentity
            default: failure = .unknownPlayerError(code)
            }
            kind = .failed(failure)
        default: return nil
        }
        return IFrameEvent(videoID: id, generation: generation, kind: kind)
    }
}

/// A host pause blocks a late Playing event only until pause is confirmed. Background
/// suppression remains independent, and returning to the foreground never requests playback.
struct IFrameHostPausePolicy {
    private(set) var backgrounded = false
    private(set) var pendingPause = false
    var suppressPlaying: Bool { backgrounded || pendingPause }
    mutating func requestPlay() { pendingPause = false }
    mutating func requestPause() { pendingPause = true }
    mutating func endRequest() { pendingPause = false }
    mutating func setBackgrounded(_ value: Bool) { backgrounded = value; if value { pendingPause = true } }
}
