import Foundation
import MusesDomain
import MusesQueue

/// Every scalar on the inherited Track model. The compact public Track is only a projection;
/// this archive is the reversible copy of the user's metadata and edits.
public struct LegacyTrackArchive: Codable, Sendable {
    public var id: UUID
    public var title: String
    public var artist: String
    public var albumTitle: String?
    public var albumArtist: String?
    public var durationMs: Int
    public var trackNo: Int?
    public var discNo: Int?
    public var year: Int?
    public var genre: String?
    public var youTubeId: String
    public var mediaKindRaw: String?
    public var releaseCatalogID: String?
    public var releaseOrder: Int?
    public var artistCatalogID: String?
    public var artworkUrl: String?
    public var lyrics: String?
    public var lyricsOffsetMs: Int?
    public var replayGain: Double?
    public var sampleRate: Int?
    public var bitDepth: Int?
    public var codec: String?
    public var bitRate: Int?
    public var channels: Int?
    public var isLossless: Bool
    public var metadataStatusRaw: String
    public var availabilityRaw: String
    public var addedAt: Date
    public var lastPlayedAt: Date?
    public var playCount: Int
    public var liked: Bool

    public func publicTrack() throws -> Track {
        try LegacyTrackSnapshot(id: id, title: title, artist: artist, youTubeId: youTubeId,
                                durationMs: durationMs, liked: liked).mapped()
    }
}

/// Exact persisted QueueState fields. The JSON arrays retain occurrence metadata, advanced
/// groups, history, and track snapshots even when the public player cannot interpret them.
public struct LegacyQueueArchive: Codable, Sendable {
    public var id: UUID
    public var itemsJSON: String
    public var currentIndex: Int
    public var upNextJSON: String
    public var historyJSON: String
    public var repeatModeRaw: String
    public var shuffle: Bool
    public var savedAt: Date
    public var currentTrackId: UUID?
    public var lastPositionMs: Double?
    public var groupsJSON: String?

    public func validate() throws {
        for (name, string) in [("itemsJSON", itemsJSON), ("upNextJSON", upNextJSON),
                               ("historyJSON", historyJSON), ("groupsJSON", groupsJSON ?? "[]")] {
            guard let data = string.data(using: .utf8),
                  (try? JSONSerialization.jsonObject(with: data)) is [Any] else {
                throw PersistenceError.unsupportedLegacyRecord("queue.\(name)")
            }
        }
        let items = try decodeEntries(itemsJSON)
        _ = try decodeEntries(upNextJSON)
        _ = try decodeEntries(historyJSON)
        guard currentIndex >= -1, currentIndex < items.count,
              QueueRepeat(rawValue: repeatModeRaw) != nil,
              lastPositionMs.map({ $0.isFinite && $0 >= 0 && $0 < Double(Int.max) }) ?? true else {
            throw PersistenceError.unsupportedLegacyRecord("queue.position")
        }
    }

    public func publicSnapshot() throws -> QueueSnapshot {
        try validate()
        let items = try decodeEntries(itemsJSON)
        let next = try decodeEntries(upNextJSON)
        let past = try decodeEntries(historyJSON)
        let current = currentIndex >= 0 ? items[currentIndex] : nil
        let future = currentIndex >= 0 ? Array(items.dropFirst(currentIndex + 1)) : items
        let snapshot = QueueSnapshot(current: current, upcoming: next + future, history: past,
            repeatMode: QueueRepeat(rawValue: repeatModeRaw)!, shuffleEnabled: shuffle,
            positionMilliseconds: Int(lastPositionMs ?? 0), intent: .pause)
        _ = try PlaybackQueue(snapshot: snapshot)
        return snapshot
    }

    private func decodeEntries(_ json: String) throws -> [QueueEntry] {
        struct Row: Decodable {
            struct Track: Decodable { let id: UUID; let youTubeId: String }
            let id: UUID
            let track: Track
        }
        do {
            return try JSONDecoder().decode([Row].self, from: Data(json.utf8)).map {
                try QueueEntry(id: $0.id, trackID: TrackID($0.track.id.uuidString),
                               source: .youtubeVideo(VideoID($0.track.youTubeId)))
            }
        } catch {
            throw PersistenceError.unsupportedLegacyRecord("queue entry")
        }
    }
}

/// Lossless scalar snapshot for the remaining inherited models. The source reader provides
/// encoded keyed fields plus the exact set of keys it captured. Required keys are checked
/// before import; a changed old schema must update this contract rather than silently omit data.
public struct LegacyModelArchive: Codable, Sendable {
    public var id: UUID
    public var fields: Data
    public var fieldNames: Set<String>
    public init(id: UUID, fields: Data, fieldNames: Set<String>) {
        self.id = id; self.fields = fields; self.fieldNames = fieldNames
    }
}

public enum LegacyModelKind: String, CaseIterable, Codable, Sendable {
    case youTubeImport, youTubeImportItem, playlist, playlistItem, listeningEvent, trackNote, trackBookmark
    case listeningSession, inboxItem, eqPreset, automationRule, focusSession
    case playlistRevision, syncBatch, syncOperation

    public var requiredFields: Set<String> {
        switch self {
        case .youTubeImport: return ["id", "playlistId", "url", "title", "channel", "artworkUrl", "importedAt", "lastSyncedAt", "accountChannelID", "remoteCheckedAt", "baseRevisionID", "remoteShadowRevisionID", "deletedAt", "remoteWritable", "items"]
        case .youTubeImportItem: return ["id", "import_", "youTubeId", "playlistItemID", "title", "artist", "durationMs", "order", "availabilityRaw", "track"]
        case .playlist: return ["id", "name", "createdAt", "pinned", "items"]
        case .playlistItem: return ["id", "order", "playlist", "track"]
        case .listeningEvent: return ["id", "trackId", "trackTitle", "artist", "albumTitle", "startedAt", "endedAt", "listenedMs", "completionRatio", "outcomeRaw", "contextSummaryJSON", "sessionId"]
        case .trackNote: return ["id", "trackId", "content", "createdAt", "updatedAt"]
        case .trackBookmark: return ["id", "trackId", "timestampMs", "title", "note", "createdAt"]
        case .listeningSession: return ["id", "startedAt", "updatedAt", "endedAt", "statusRaw", "queueSnapshotJSON", "currentTrackId", "currentPositionMs", "contextSummaryJSON"]
        case .inboxItem: return ["id", "trackId", "trackTitle", "artist", "albumTitle", "durationSeconds", "youTubeId", "artworkUrl", "addedAt", "sourceRaw", "stateRaw", "snoozeUntil", "listenedMs", "notes"]
        case .eqPreset: return ["id", "name", "bandsJSON", "createdAt"]
        case .automationRule: return ["id", "name", "enabled", "triggerRaw", "conditionsJSON", "actionRaw", "cooldownMs", "lastFiredAt"]
        case .focusSession: return ["id", "startedAt", "plannedDurationMs", "endedAt", "playlistId", "listeningSessionId", "statusRaw"]
        case .playlistRevision: return ["id", "importID", "accountChannelID", "kindRaw", "createdAt", "snapshotData", "fingerprint", "pinned"]
        case .syncBatch: return ["id", "importID", "accountChannelID", "playlistID", "stateRaw", "baseRevisionID", "localRevisionID", "remoteRevisionID", "expectedRemoteFingerprint", "desiredSnapshotData", "preRemoteSnapshotData", "createdAt", "startedAt", "remoteObservedAt", "completedAt", "invalidatedReason"]
        case .syncOperation: return ["id", "idempotencyKey", "importID", "accountChannelID", "batchID", "sequence", "kindRaw", "stateRaw", "playlistItemID", "videoID", "fromPosition", "toPosition", "previousPlaylistItemID", "nextPlaylistItemID", "remoteResultID", "attempts", "lastError", "createdAt", "startedAt", "remoteObservedAt", "completedAt"]
        }
    }

    public var relationshipFields: Set<String> {
        switch self {
        case .youTubeImport: ["items"]
        case .youTubeImportItem: ["import_", "track"]
        case .playlist: ["items"]
        case .playlistItem: ["playlist", "track"]
        default: []
        }
    }
}

public struct LegacyCompleteBundle: Sendable {
    public static let knownSettingKeys: Set<String> = [
        "muses.nowPlayingMode",
        "muses.nowPlaying.lyricsMode",
        "muses.theme",
        "muses.eq.activePresetId",
        "muses.lyrics.source",
        "muses.lyrics.intelligence",
        "muses.audio.quality",
        "muses.updates.checkAutomatically",
        "muses.liveActivities.enabled",
        "muses.updates.lastCheckAt",
        "muses.updates.latestVersion",
        "muses.yt.cookieSource",
        "muses.yt.cookiePath",
        "muses.webHome.enabled",
        "muses.webHome.consentVersion",
        "muses.webHome.defaultBrowserConsent",
        "muses.webHome.browserSource",
        "muses.yt.showAdvanced",
        "muses.notifications.trackChange",
        "muses.playback.crossfadeSeconds",
        "muses.playback.replayGainEnabled",
        "muses.playback.volume",
        "muses.gpuAcceleration",
        "muses.language",
        "muses.yt.quality",
        "muses.yt.videoQuality",
        "muses.ui.hoverPreviewSound",
        "muses.ui.sidebarPlaylistOrder",
        "muses.playback.resumeAfterVideo",
        "muses.yt.personalDiscovery",
        "muses.home.recommendationMode",
        "muses.ff.smartHistory",
        "muses.ff.sessions",
        "muses.ff.advancedQueue",
        "muses.ff.inbox",
        "muses.ff.notes",
        "muses.ff.advancedLyrics",
        "muses.ff.focusMode",
        "muses.ff.audioNerd",
        "muses.ff.context",
        "muses.ff.automation",
        "muses.ff.miniPlayer",
        "muses.ff.tray",
        "muses.ff.desktopLyrics",
        "muses.ff.globalHotkeys",
        "muses.ff.localHardening",
        "muses.ff.discovery",
        "muses.ff.situationalNew",
        "muses.globalHotkeys.bindings",
        "muses.audio.preferredOutputDevice",
        "muses.context.trackActiveApp",
        "muses.search.recentQueries",
    ]

    public var userTruth: LegacyUserTruthBundle
    public var tracks: [LegacyTrackArchive]
    public var queue: LegacyQueueArchive?
    public var otherModels: [LegacyModelKind: [LegacyModelArchive]]
    /// The source reader must enumerate all 19 inherited model tables, including empty ones.
    public var inspectedModels: Set<String>
    public var inspectedSettingKeys: Set<String>
    public init(userTruth: LegacyUserTruthBundle, tracks: [LegacyTrackArchive], queue: LegacyQueueArchive?,
                otherModels: [LegacyModelKind: [LegacyModelArchive]], inspectedModels: Set<String>,
                inspectedSettingKeys: Set<String>) {
        self.userTruth = userTruth; self.tracks = tracks; self.queue = queue
        self.otherModels = otherModels; self.inspectedModels = inspectedModels
        self.inspectedSettingKeys = inspectedSettingKeys
    }

}
