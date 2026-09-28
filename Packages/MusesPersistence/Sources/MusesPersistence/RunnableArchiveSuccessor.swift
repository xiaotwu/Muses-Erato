import Foundation
import SwiftData
import MusesDomain
import MusesQueue

/// A runnable projection, not a sanitized copy of a raw historical archive.
/// Original receipts describe their original imports, even when carried as lineage here.
public struct RunnableArchiveSuccessor: Codable, Sendable {
    public let version: Int
    public let id: UUID
    public let originalReceipt: LegacyMigrationReceipt
    public let parentArchiveDigest: String
    public let parentProjectionDigest: String
    public let contracts: [String]
    public let records: [StoredValue]
    public let excludedOriginalRecordKeys: [String]
    public let unresolvedPlaylistNames: [UUID]
    public let preservedPlaylistPins: [String: Bool]
    public var digest: String { get throws { try Self.digest(records) } }
    static func digest(_ records: [StoredValue]) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return ArchiveField.hash(try encoder.encode(records.sorted { $0.kind.rawValue + $0.id < $1.kind.rawValue + $1.id }))
    }
}

public enum LegacyUserFieldContracts {
    public static let revision = "c754fff:notes-service-editor-contract-v1"
    /// Only content inputs, not track titles, opaque snapshots, or whole records.
    public static func evidence(for fields: [ArchiveField]) -> [ArchiveEvidence] {
        fields.compactMap { field in
            let pieces = field.address.split(separator: "/")
            guard pieces.count == 4, pieces[0] == "model",
                  (pieces[1] == "trackNote" && pieces[3] == "content") ||
                  (pieces[1] == "trackBookmark" && ["title", "note"].contains(String(pieces[3]))) else { return nil }
            return ArchiveEvidence(field: field, origin: .userInput, reference: revision)
        }
    }
}

@MainActor public extension SwiftDataSnapshotRepository {
    /// Called only by explicit public create/rename input handlers. The name and evidence
    /// share one transaction; queue/reorder/import/restore writes must not call this method.
    func saveUserNamedPlaylist(_ playlist: LocalPlaylist) throws {
        guard !playlist.usesRemoteName else { try savePlaylist(playlist); return }
        try playlist.validated()
        guard Set(playlist.trackIDs).isSubset(of: Set(try list(Track.self, kind: .track).map(\.id))) else { throw LocalLibraryError.missingTrack }
        let encoder = JSONEncoder()
        let replacements = [(StoreKind.localPlaylist, playlist.id.uuidString, try encoder.encode(playlist.localPersistenceSnapshot)),
            (.migration, "user-playlist-name-v1:" + playlist.id.uuidString, try encoder.encode(ArchiveField.hash(Data(playlist.name.utf8))))]
        do {
            for (kind, id, data) in replacements {
                if let row = try record(kind: kind, id: id) {
                    guard row.payloadVersion == 1 else { throw PersistenceError.corruptRecord(row.key) }
                    row.payload = data
                } else { context.insert(MusesSchemaV1.Record(kind: kind, recordID: id, payload: data)) }
            }
            try context.save()
        } catch { context.rollback(); throw error }
    }

    func projectionDigestForSuccessor() throws -> String {
        let rows = try context.fetch(FetchDescriptor<MusesSchemaV1.Record>())
        // Includes current deletions/edits, evidence and archive versions. No timestamp renewal.
        return try RunnableArchiveSuccessor.digest(rows.map {
            guard $0.payloadVersion == 1, let kind = StoreKind(rawValue: $0.kindRaw) else { throw PersistenceError.corruptRecord($0.key) }
            return StoredValue(kind: kind, id: $0.recordID, data: $0.payload)
        })
    }

    func makeRunnableArchiveSuccessor(id: UUID = UUID()) throws -> RunnableArchiveSuccessor {
        guard try record(kind: .migration, id: "runnable-successor-v1") == nil else { throw ArchiveLifecycleError.restoreBlocked }
        if let staged = try get(ArchiveSuccessor.self, kind: .migration, id: "archive-successor-v1") {
            guard staged.version == 1, staged.excludedAddresses.isEmpty else {
                throw PersistenceError.unsupportedLegacyRecord("field exclusions require explicit projection mapping")
            }
        }
        let archive = try legacyArchive()
        guard let receipt = archive.receipt else { throw PersistenceError.unsupportedLegacyRecord("successor requires original import lineage") }
        let current = try PublicLibrarySnapshot(repository: self)
        let currentIDs = Set(current.tracks.map(\.id))
        var records: [StoredValue] = []
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        func add<T: Encodable>(_ value: T, _ kind: StoreKind, _ id: String) throws {
            records.append(StoredValue(kind: kind, id: id, data: try encoder.encode(value)))
        }
        for var track in current.tracks {
            // Keep explicit user edits, favorites and actual playback identity; unknown/API
            // display fields receive existing public placeholders, never a new fetch date.
            track.expireYouTubeMetadata(force: true)
            try add(track.localPersistenceSnapshot, .track, track.id.rawValue)
        }
        // Read current mutable projections, NEVER restore archived deleted/edited user text.
        // Dedicated note/bookmark writers are audited in archive-source-contracts.json.
        for note in try list(LegacyNote.self, kind: .note) {
            guard currentIDs.contains(try TrackID(note.trackId.uuidString)) else { throw PersistenceError.unsupportedLegacyRecord("orphan note requires review") }
            try add(note, .note, note.id.uuidString)
        }
        for bookmark in try list(LegacyBookmark.self, kind: .bookmark) {
            guard currentIDs.contains(try TrackID(bookmark.trackId.uuidString)) else { throw PersistenceError.unsupportedLegacyRecord("orphan bookmark requires review") }
            try VideoTimeBookmark.validateTime(bookmark.timestampMs)
            var fields = try JSONSerialization.jsonObject(with: encoder.encode(bookmark)) as! [String: Any]
            // The current adapter's V1 payload omitted createdAt; recover ONLY this local
            // creation timestamp for a still-live bookmark. Never restore deleted content.
            if let original = archive.models[LegacyModelKind.trackBookmark.rawValue]?.first(where: { $0.id == bookmark.id }),
               let raw = try JSONSerialization.jsonObject(with: original.fields) as? [String: Any], let created = raw["createdAt"] {
                fields["createdAt"] = created
            }
            if let row = try record(kind: .bookmark, id: bookmark.id.uuidString),
               let raw = try JSONSerialization.jsonObject(with: row.payload) as? [String: Any], let created = raw["createdAt"] { fields["createdAt"] = created }
            records.append(StoredValue(kind: .bookmark, id: bookmark.id.uuidString,
                data: try JSONSerialization.data(withJSONObject: fields, options: .sortedKeys)))
        }
        var unresolved: [UUID] = []
        for var playlist in current.playlists {
            let evidenceID = "user-playlist-name-v1:" + playlist.id.uuidString
            let digest = try get(String.self, kind: .migration, id: evidenceID)
            if playlist.usesRemoteName {
                // Keep refreshable source identity, without retaining or attributing API text.
                playlist = playlist.localPersistenceSnapshot
            } else if digest == ArchiveField.hash(Data(playlist.name.utf8)) {
                try add(digest!, .migration, evidenceID)
            } else {
                unresolved.append(playlist.id)
                try playlist.rename("Recovered playlist")
            }
            try add(playlist, .localPlaylist, playlist.id.uuidString)
        }
        for event in current.history { try add(event, .history, event.id.uuidString) }
        var queue = current.queue
        queue.sourceContext = nil; queue.intent = .pause
        try add(queue, .queue, "main") // IDs/order only; raw archive queue JSON never copied.
        let activeKeys = Set(records.map { $0.kind.rawValue + ":" + $0.id })
        var originalKeys = archive.tracks.map { "track:" + $0.id.uuidString }
        for (kind, target) in [("trackNote", "note"), ("trackBookmark", "bookmark"), ("playlist", "localPlaylist")] {
            originalKeys += archive.models[kind, default: []].map { target + ":" + $0.id.uuidString }
        }
        let survivingPlaylistIDs = Set(current.playlists.map(\.id))
        let pins = Dictionary(uniqueKeysWithValues: try list(LegacyPlaylist.self, kind: .playlist)
            .filter { survivingPlaylistIDs.contains($0.id) }.map { ($0.id.uuidString, $0.pinned) })
        return RunnableArchiveSuccessor(version: 1, id: id, originalReceipt: receipt,
            parentArchiveDigest: try legacyArchiveDigest(), parentProjectionDigest: try projectionDigestForSuccessor(),
            contracts: [LegacyUserFieldContracts.revision, "public-playlist-explicit-name-v1", "public-current-projections-v1"],
            records: records, excludedOriginalRecordKeys: originalKeys.filter { !activeKeys.contains($0) }.sorted(),
            unresolvedPlaylistNames: unresolved.sorted { $0.uuidString < $1.uuidString }, preservedPlaylistPins: pins)
    }

    /// Restore/install into a pristine disposable candidate only. A saved snapshot can never
    /// be replayed over a used public repository and revive later-deleted notes/tracks/playlists.
    func installRunnableArchiveSuccessor(_ value: RunnableArchiveSuccessor, beforeSave: () throws -> Void = {}) throws {
        guard value.version == 1 else { throw ArchiveLifecycleError.unsupportedVersion }
        guard try context.fetchCount(FetchDescriptor<MusesSchemaV1.Record>()) == 0 else { throw ArchiveLifecycleError.restoreBlocked }
        let allowed: Set<StoreKind> = [.track, .note, .bookmark, .localPlaylist, .history, .queue, .migration]
        guard Set(value.records.map { $0.kind.rawValue + ":" + $0.id }).count == value.records.count,
              value.records.allSatisfy({ allowed.contains($0.kind) && ($0.kind != .migration || $0.id.hasPrefix("user-playlist-name-v1:")) }) else {
            throw ArchiveLifecycleError.invalidEvidence
        }
        let encoder = JSONEncoder()
        do {
            for row in value.records { context.insert(MusesSchemaV1.Record(kind: row.kind, recordID: row.id, payload: row.data)) }
            // Keep the historical receipt unchanged; immutable metadata is distinct from live edits.
            context.insert(MusesSchemaV1.Record(kind: .migration, recordID: "legacy-complete-v1", payload: try encoder.encode(value.originalReceipt)))
            context.insert(MusesSchemaV1.Record(kind: .migration, recordID: "runnable-successor-v1", payload: try encoder.encode(SuccessorIdentity(value))))
            context.insert(MusesSchemaV1.Record(kind: .migration, recordID: "public-route-v1", payload: try encoder.encode(value.id)))
            _ = try PublicLibrarySnapshot(repository: self)
            // Force decode/ownership validation of notebook data before committing any records.
            try validateSuccessorNotebooks()
            try beforeSave(); try context.save()
        } catch { context.rollback(); throw error }
    }

    func validateSuccessorNotebooks() throws {
        let ids = Set(try list(Track.self, kind: .track).map(\.id))
        for note in try list(LegacyNote.self, kind: .note) {
            guard ids.contains(try TrackID(note.trackId.uuidString)) else { throw VideoNotebookError.missingTrack }
        }
        for bookmark in try list(LegacyBookmark.self, kind: .bookmark) {
            guard ids.contains(try TrackID(bookmark.trackId.uuidString)) else { throw VideoNotebookError.missingTrack }
            try VideoTimeBookmark.validateTime(bookmark.timestampMs)
        }
    }
}

public struct SuccessorIdentity: Codable, Equatable, Sendable {
    public let version: Int
    public let id: UUID
    public let originalReceipt: LegacyMigrationReceipt
    public let initialContentDigest: String
    public let parentArchiveDigest: String
    public let excludedOriginalRecordKeys: [String]
    public let unresolvedPlaylistNames: [UUID]
    public let contracts: [String]
    public let preservedPlaylistPins: [String: Bool]
    init(_ value: RunnableArchiveSuccessor) throws {
        contracts = value.contracts; preservedPlaylistPins = value.preservedPlaylistPins
        version = value.version; id = value.id; originalReceipt = value.originalReceipt
        initialContentDigest = try value.digest; parentArchiveDigest = value.parentArchiveDigest
        excludedOriginalRecordKeys = value.excludedOriginalRecordKeys; unresolvedPlaylistNames = value.unresolvedPlaylistNames
    }
}
