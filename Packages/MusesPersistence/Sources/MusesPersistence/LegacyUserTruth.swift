import Foundation
import SwiftData
import MusesDomain
import MusesQueue

public struct LegacyNote: Codable, Sendable {
    public let id: UUID; public let trackId: UUID; public let content: String; public let createdAt: Date; public let updatedAt: Date
    public init(id: UUID, trackId: UUID, content: String, createdAt: Date, updatedAt: Date) { self.id = id; self.trackId = trackId; self.content = content; self.createdAt = createdAt; self.updatedAt = updatedAt }
}
public struct LegacyBookmark: Codable, Sendable {
    public let id: UUID; public let trackId: UUID; public let timestampMs: Double; public let title: String?; public let note: String?
    public init(id: UUID, trackId: UUID, timestampMs: Double, title: String?, note: String?) { self.id = id; self.trackId = trackId; self.timestampMs = timestampMs; self.title = title; self.note = note }
}
public struct LegacyPlaylist: Codable, Sendable {
    public let id: UUID; public let name: String; public let createdAt: Date; public let pinned: Bool
    public init(id: UUID, name: String, createdAt: Date, pinned: Bool) { self.id = id; self.name = name; self.createdAt = createdAt; self.pinned = pinned }
}
public struct LegacyPlaylistItem: Codable, Sendable {
    public let id: UUID; public let playlistID: UUID; public let trackID: UUID?; public let order: Int
    public init(id: UUID, playlistID: UUID, trackID: UUID?, order: Int) { self.id = id; self.playlistID = playlistID; self.trackID = trackID; self.order = order }
}
public struct LegacyHistoryEvent: Codable, Sendable {
    public let id: UUID; public let trackID: UUID; public let title: String; public let artist: String; public let startedAt: Date; public let listenedMs: Int; public let outcomeRaw: String
    public init(id: UUID, trackID: UUID, title: String, artist: String, startedAt: Date, listenedMs: Int, outcomeRaw: String) { self.id = id; self.trackID = trackID; self.title = title; self.artist = artist; self.startedAt = startedAt; self.listenedMs = listenedMs; self.outcomeRaw = outcomeRaw }
}
public struct LegacyImport: Codable, Sendable {
    public let id: UUID; public let playlistID: String; public let originalURL: String; public let title: String; public let importedAt: Date
    public init(id: UUID, playlistID: String, originalURL: String, title: String, importedAt: Date) { self.id = id; self.playlistID = playlistID; self.originalURL = originalURL; self.title = title; self.importedAt = importedAt }
}
public struct LegacyImportItem: Codable, Sendable {
    public let id: UUID; public let importID: UUID; public let videoID: String; public let playlistItemID: String?; public let order: Int
    public init(id: UUID, importID: UUID, videoID: String, playlistItemID: String?, order: Int) { self.id = id; self.importID = importID; self.videoID = videoID; self.playlistItemID = playlistItemID; self.order = order }
}
public struct LegacySetting: Codable, Sendable {
    public let key: String; public let value: Data
    public init(key: String, value: Data) { self.key = key; self.value = value }
}

/// Captured by P4 from the old ModelContext and UserDefaults. The source store remains untouched.
public struct LegacyUserTruthBundle: Sendable {
    public var tracks: [LegacyTrackSnapshot] = []
    public var queue: LegacyQueueSnapshot?
    public var notes: [LegacyNote] = []
    public var bookmarks: [LegacyBookmark] = []
    public var playlists: [LegacyPlaylist] = []
    public var playlistItems: [LegacyPlaylistItem] = []
    public var history: [LegacyHistoryEvent] = []
    public var imports: [LegacyImport] = []
    public var importItems: [LegacyImportItem] = []
    public var settings: [LegacySetting] = []
    public init() {}
}

extension SwiftDataSnapshotRepository {
    /// Validates every typed identity and encodes all snapshots before writing; a bad legacy
    /// video ID cannot leave a half-imported target. Uses an idempotent upsert transaction.
    public func importLegacy(_ bundle: LegacyUserTruthBundle) throws {
        if try record(kind: .migration, id: "legacy-v1") != nil { return }
        var values: [StoredValue] = []
        let encoder = JSONEncoder()
        func add<T: Encodable>(_ value: T, kind: StoreKind, id: String) throws {
            values.append(StoredValue(kind: kind, id: id, data: try encoder.encode(value)))
        }
        for old in bundle.tracks {
            let track = try old.mapped()
            try add(track, kind: .track, id: track.id.rawValue)
            if track.liked { try add(track.id, kind: .favorite, id: track.id.rawValue) }
        }
        if let queue = bundle.queue { try add(queue.mapped().restored(), kind: .queue, id: "main") }
        for value in bundle.notes { try add(value, kind: .note, id: value.id.uuidString) }
        for value in bundle.bookmarks { try add(value, kind: .bookmark, id: value.id.uuidString) }
        for value in bundle.playlists { try add(value, kind: .playlist, id: value.id.uuidString) }
        for value in bundle.playlistItems { try add(value, kind: .playlistItem, id: value.id.uuidString) }
        for value in bundle.history { try add(value, kind: .history, id: value.id.uuidString) }
        for value in bundle.imports { try add(value, kind: .importRelation, id: value.id.uuidString) }
        for value in bundle.importItems {
            _ = try VideoID(value.videoID)
            try add(value, kind: .importItem, id: value.id.uuidString)
        }
        for value in bundle.settings { try add(value, kind: .setting, id: value.key) }
        let keys = values.map { $0.kind.rawValue + ":" + $0.id }
        guard Set(keys).count == keys.count else { throw PersistenceError.unsupportedLegacyRecord("duplicate record") }
        try context.transaction {
            for value in values {
                if let row = try record(kind: value.kind, id: value.id) { row.payload = value.data; row.updatedAt = .init() }
                else { context.insert(MusesSchemaV1.Record(kind: value.kind, recordID: value.id, payload: value.data)) }
            }
            context.insert(MusesSchemaV1.Record(kind: .migration, recordID: "legacy-v1", payload: try encoder.encode(Date())))
            try context.save()
        }
    }
}
