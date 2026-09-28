import Foundation
import SwiftData
import MusesDomain
import MusesQueue
import CryptoKit

public struct LegacyMigrationReceipt: Codable, Equatable, Sendable {
    public let recordCount: Int
    public let payloadSHA256: String
}

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
    /// Early P2 bridge. This omits fields and must not be used for a production upgrade.
    @available(*, deprecated, message: "Use importLegacyComplete after reading the full old schema")
    public func importLegacy(_ bundle: LegacyUserTruthBundle) throws {
        if try record(kind: .migration, id: "legacy-v1") != nil { return }
        try writeLegacy(try preparedLegacyValues(bundle), marker: "legacy-v1")
    }

    /// Import a complete archive in one SwiftData transaction. The caller must read an isolated
    /// copy of the old store and retain the original store files for rollback.
    public func importLegacyComplete(_ bundle: LegacyCompleteBundle, beforeCommit: (() throws -> Void)? = nil) throws {
        let expected: Set<String> = ["Track", "QueueState", "EQPreset", "YouTubeImport",
            "YouTubeImportItem", "Playlist", "PlaylistItem", "ListeningEvent",
            "ListeningSession", "InboxItem", "TrackNote", "TrackBookmark",
            "AutomationRule", "FocusSession", "YouTubePlaylistRevision",
            "YouTubeSyncOperation", "YouTubeSyncBatch", "CatalogRelease", "CatalogArtist"]
        guard bundle.inspectedModels == expected else {
            throw PersistenceError.unsupportedLegacyRecord("source model inventory")
        }
        guard LegacyCompleteBundle.knownSettingKeys.isSubset(of: bundle.inspectedSettingKeys),
              Set(bundle.userTruth.settings.map(\.key)).isSubset(of: bundle.inspectedSettingKeys) else {
            throw PersistenceError.unsupportedLegacyRecord("settings inventory")
        }
        guard bundle.userTruth.tracks.count == bundle.tracks.count,
              Set(bundle.userTruth.tracks.map(\.id)) == Set(bundle.tracks.map(\.id)) else {
            throw PersistenceError.unsupportedLegacyRecord("source projection mismatch")
        }
        for source in bundle.tracks {
            guard let projection = bundle.userTruth.tracks.first(where: { $0.id == source.id }),
                  try projection.mapped() == source.publicTrack() else {
                throw PersistenceError.unsupportedLegacyRecord("track projection mismatch: \(source.id)")
            }
        }
        var truth = bundle.userTruth
        truth.queue = nil
        var values = try preparedLegacyValues(truth)
        let encoder = JSONEncoder()
        for track in bundle.tracks {
            _ = try track.publicTrack()
            values.append(StoredValue(kind: .legacyTrack, id: track.id.uuidString,
                                      data: try encoder.encode(track)))
        }
        if let queue = bundle.queue {
            let snapshot = try queue.publicSnapshot()
            values.append(StoredValue(kind: .queue, id: "main", data: try encoder.encode(snapshot)))
            values.append(StoredValue(kind: .legacyQueue, id: queue.id.uuidString,
                                      data: try encoder.encode(queue)))
        }
        let projectedIDs: [LegacyModelKind: Set<UUID>] = [
            .youTubeImport: Set(bundle.userTruth.imports.map(\.id)),
            .youTubeImportItem: Set(bundle.userTruth.importItems.map(\.id)),
            .playlist: Set(bundle.userTruth.playlists.map(\.id)),
            .playlistItem: Set(bundle.userTruth.playlistItems.map(\.id)),
            .listeningEvent: Set(bundle.userTruth.history.map(\.id)),
            .trackNote: Set(bundle.userTruth.notes.map(\.id)),
            .trackBookmark: Set(bundle.userTruth.bookmarks.map(\.id))
        ]
        for kind in LegacyModelKind.allCases {
            guard let rows = bundle.otherModels[kind],
                  projectedIDs[kind].map({ $0 == Set(rows.map(\.id)) && $0.count == rows.count }) ?? true else {
                throw PersistenceError.unsupportedLegacyRecord("\(kind.rawValue) inventory")
            }
            for row in rows {
                guard row.fieldNames == kind.requiredFields,
                      let object = try? JSONSerialization.jsonObject(with: row.fields) as? [String: Any],
                      Set(object.keys) == row.fieldNames,
                      object["id"] as? String == row.id.uuidString,
                      kind.relationshipFields.allSatisfy({ key in
                          guard let value = object[key] else { return false }
                          if value is NSNull { return true }
                          if key == "items" {
                              guard let ids = value as? [String] else { return false }
                              return ids.allSatisfy { UUID(uuidString: $0) != nil }
                          }
                          guard let id = value as? String else { return false }
                          return UUID(uuidString: id) != nil
                      }) else {
                    throw PersistenceError.unsupportedLegacyRecord("\(kind.rawValue).\(row.id)")
                }
                values.append(StoredValue(kind: .legacyModel, id: "\(kind.rawValue):\(row.id.uuidString)",
                                          data: try encoder.encode(row)))
            }
        }
        let receipt = LegacyMigrationReceipt(recordCount: values.count, payloadSHA256: digest(values))
        if let prior = try record(kind: .migration, id: "legacy-complete-v1") {
            guard prior.payloadVersion == 1,
                  let stored = try? JSONDecoder().decode(LegacyMigrationReceipt.self, from: prior.payload),
                  stored == receipt else { throw PersistenceError.corruptRecord(prior.key) }
            let all = try context.fetch(FetchDescriptor<MusesSchemaV1.Record>())
            guard all.count == receipt.recordCount + 1 else { throw PersistenceError.corruptRecord(prior.key) }
            for value in values {
                guard let row = try record(kind: value.kind, id: value.id), row.payloadVersion == 1,
                      canonicalData(row.payload) == canonicalData(value.data) else {
                    throw PersistenceError.corruptRecord("\(value.kind.rawValue):\(value.id)")
                }
            }
            return
        }
        guard try context.fetch(FetchDescriptor<MusesSchemaV1.Record>()).isEmpty else {
            throw PersistenceError.unsupportedLegacyRecord("target is not empty")
        }
        try writeLegacy(values, marker: "legacy-complete-v1", markerPayload: try encoder.encode(receipt), beforeCommit: beforeCommit)
    }

    private func digest(_ values: [StoredValue]) -> String {
        var data = Data()
        for value in values.sorted(by: { ($0.kind.rawValue, $0.id) < ($1.kind.rawValue, $1.id) }) {
            data.append(contentsOf: value.kind.rawValue.utf8)
            data.append(0)
            data.append(contentsOf: value.id.utf8)
            data.append(0)
            data.append(canonicalData(value.data))
            data.append(0)
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func canonicalData(_ payload: Data) -> Data {
        guard let object = try? JSONSerialization.jsonObject(with: payload, options: .fragmentsAllowed),
              let sorted = try? JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed, .sortedKeys]) else {
            return payload
        }
        return sorted
    }

    private func preparedLegacyValues(_ bundle: LegacyUserTruthBundle) throws -> [StoredValue] {
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
        return values
    }

    private func writeLegacy(_ values: [StoredValue], marker: String, markerPayload: Data? = nil, beforeCommit: (() throws -> Void)? = nil) throws {
        let keys = values.map { $0.kind.rawValue + ":" + $0.id }
        guard Set(keys).count == keys.count else { throw PersistenceError.unsupportedLegacyRecord("duplicate record") }
        try context.transaction {
            for value in values {
                if let row = try record(kind: value.kind, id: value.id) { row.payload = value.data; row.updatedAt = .init() }
                else { context.insert(MusesSchemaV1.Record(kind: value.kind, recordID: value.id, payload: value.data)) }
            }
            context.insert(MusesSchemaV1.Record(kind: .migration, recordID: marker,
                                                payload: try markerPayload ?? JSONEncoder().encode(Date())))
            try beforeCommit?()
            try context.save()
        }
    }
}
