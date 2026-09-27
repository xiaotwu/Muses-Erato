import Foundation

public enum DistributionChannel: String, Codable, Sendable { case appStore, adHoc, internalTesting, macOSDirect }
public enum ContentOrigin: String, Codable, Sendable { case youtube, localUserFile, licensedRemote }

public struct ContentRights: Codable, Hashable, Sendable {
    public let origin: ContentOrigin
    /// A reviewed license record identifier; nil means no independent native-media permission.
    public let licenseEvidenceID: String?
    public init(origin: ContentOrigin, licenseEvidenceID: String? = nil) { self.origin = origin; self.licenseEvidenceID = licenseEvidenceID }
}

public struct DistributionCapabilities: Codable, Hashable, Sendable {
    public let channel: DistributionChannel
    public let permittedEvidenceIDs: Set<String>
    public let allowsLocalFiles: Bool
    public init(channel: DistributionChannel, permittedEvidenceIDs: Set<String> = [], allowsLocalFiles: Bool = false) {
        self.channel = channel; self.permittedEvidenceIDs = permittedEvidenceIDs; self.allowsLocalFiles = allowsLocalFiles
    }
    public func allows(_ source: PlaybackSource, rights: ContentRights) -> Bool {
        switch source {
        case .youtubeVideo: return rights.origin == .youtube
        case .localFile: return rights.origin == .localUserFile && allowsLocalFiles
        case .authorizedRemote:
            guard rights.origin == .licensedRemote, let evidence = rights.licenseEvidenceID else { return false }
            return permittedEvidenceIDs.contains(evidence)
        }
    }
}

public struct PlaybackCapabilities: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt16
    public init(rawValue: UInt16) { self.rawValue = rawValue }
    public static let seek = Self(rawValue: 1 << 0)
    public static let queueByID = Self(rawValue: 1 << 1)
    public static let backgroundAudio = Self(rawValue: 1 << 2)
    public static let audioProcessing = Self(rawValue: 1 << 3)
    public static let offlineMedia = Self(rawValue: 1 << 4)
    public static let rate = Self(rawValue: 1 << 5)
    public static let gapless = Self(rawValue: 1 << 6)
    public static let systemRemote = Self(rawValue: 1 << 7)
    public static let videoVisible = Self(rawValue: 1 << 8)
}

public enum PlaybackCapabilityPolicy {
    public static func effective(source: PlaybackSource, rights: ContentRights, distribution: DistributionCapabilities, adapter: PlaybackCapabilities, runtime: PlaybackCapabilities) -> PlaybackCapabilities {
        guard distribution.allows(source, rights: rights) else { return [] }
        var available = adapter.intersection(runtime)
        if case .youtubeVideo = source {
            guard available.contains(.videoVisible) else { return [] }
            available.subtract([.backgroundAudio, .audioProcessing, .offlineMedia, .gapless, .systemRemote])
        }
        return available
    }
}

public enum PlaybackState: String, Codable, Sendable { case idle, loading, ready, playing, paused, buffering, ended, failed }
public enum PlaybackIntent: String, Codable, Sendable { case play, pause }
public enum PlaybackFailure: String, Codable, Error, Sendable { case unsupportedSource, permissionDenied, unavailable, notEmbeddable, network, adapterFailed }
public struct PlaybackSnapshot: Codable, Equatable, Sendable {
    public var state: PlaybackState
    public var source: PlaybackSource?
    public var generation: UInt64
    public var intent: PlaybackIntent
    public var positionMilliseconds: Int
    public var durationMilliseconds: Int?
    public var capabilities: PlaybackCapabilities
    public var failure: PlaybackFailure?
    public init(state: PlaybackState = .idle, source: PlaybackSource? = nil, generation: UInt64 = 0, intent: PlaybackIntent = .pause, positionMilliseconds: Int = 0, durationMilliseconds: Int? = nil, capabilities: PlaybackCapabilities = [], failure: PlaybackFailure? = nil) {
        self.state = state; self.source = source; self.generation = generation; self.intent = intent; self.positionMilliseconds = positionMilliseconds; self.durationMilliseconds = durationMilliseconds; self.capabilities = capabilities; self.failure = failure
    }
}
public struct PlaybackEvent: Codable, Equatable, Sendable {
    public let state: PlaybackState
    public let source: PlaybackSource
    public let generation: UInt64
    public let positionMilliseconds: Int?
    public let durationMilliseconds: Int?
    public let failure: PlaybackFailure?
    public init(state: PlaybackState, source: PlaybackSource, generation: UInt64, positionMilliseconds: Int? = nil, durationMilliseconds: Int? = nil, failure: PlaybackFailure? = nil) {
        self.state = state; self.source = source; self.generation = generation; self.positionMilliseconds = positionMilliseconds; self.durationMilliseconds = durationMilliseconds; self.failure = failure
    }
}

public protocol PlaybackAdapter: AnyObject {
    var capabilities: PlaybackCapabilities { get }
    var events: AsyncStream<PlaybackEvent> { get }
    func load(_ source: PlaybackSource, intent: PlaybackIntent, generation: UInt64) async throws
    func play(generation: UInt64) async throws
    func pause(generation: UInt64) async
    func seek(to positionMilliseconds: Int, generation: UInt64) async throws
    func teardown() async
}

public enum SkipDirection: Sendable { case next, previous }
@MainActor public protocol PlaybackCoordinatorProtocol: AnyObject {
    var snapshot: PlaybackSnapshot { get }
    func load(_ source: PlaybackSource, context: String?) async throws
    func play() async throws
    func pause() async
    func seek(to positionMilliseconds: Int) async throws
    func skip(_ direction: SkipDirection) async throws
}
