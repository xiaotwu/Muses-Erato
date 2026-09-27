import Foundation
import SwiftData
import MusesDomain

public extension LegacyNote {
    func videoNote() throws -> VideoNote {
        try .init(id: id, trackID: TrackID(trackId.uuidString), content: content, createdAt: createdAt, updatedAt: updatedAt)
    }
}
public extension LegacyBookmark {
    func videoBookmark() throws -> VideoTimeBookmark {
        try .init(id: id, trackID: TrackID(trackId.uuidString), timestampMilliseconds: timestampMs, title: title, note: note)
    }
}

extension SwiftDataSnapshotRepository: VideoNotebookRepository {
    public func videoNotes(trackID: TrackID) throws -> [VideoNote] {
        try list(LegacyNote.self, kind: .note).map { try $0.videoNote() }
            .filter { $0.trackID == trackID }
            .sorted { $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt }
    }
    public func videoBookmarks(trackID: TrackID) throws -> [VideoTimeBookmark] {
        try list(LegacyBookmark.self, kind: .bookmark).map { try $0.videoBookmark() }
            .filter { $0.trackID == trackID }
            .sorted { $0.timestampMilliseconds == $1.timestampMilliseconds ? $0.id.uuidString < $1.id.uuidString : $0.timestampMilliseconds < $1.timestampMilliseconds }
    }
    public func saveVideoNote(_ note: VideoNote) throws {
        guard !note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw VideoNotebookError.emptyNote }
        try requireTrack(note.trackID)
        if let old = try get(VideoNote.self, kind: .note, id: note.id.uuidString) {
            guard old.trackID == note.trackID, old.createdAt == note.createdAt else { throw VideoNotebookError.changedIdentity }
        }
        try mergeNotebookPayload(note, kind: .note, id: note.id)
    }
    public func saveVideoBookmark(_ bookmark: VideoTimeBookmark) throws {
        try VideoTimeBookmark.validateTime(bookmark.timestampMilliseconds)
        try requireTrack(bookmark.trackID)
        if let old = try get(VideoTimeBookmark.self, kind: .bookmark, id: bookmark.id.uuidString) {
            guard old.trackID == bookmark.trackID else { throw VideoNotebookError.changedIdentity }
        }
        try mergeNotebookPayload(bookmark, kind: .bookmark, id: bookmark.id, nullableKeys: ["title", "note"])
    }
    public func deleteVideoNote(id: UUID, trackID: TrackID) throws {
        guard let old = try get(VideoNote.self, kind: .note, id: id.uuidString), old.trackID == trackID else { throw VideoNotebookError.missingEntry }
        try delete(kind: .note, id: id.uuidString)
    }
    public func deleteVideoBookmark(id: UUID, trackID: TrackID) throws {
        guard let old = try get(VideoTimeBookmark.self, kind: .bookmark, id: id.uuidString), old.trackID == trackID else { throw VideoNotebookError.missingEntry }
        try delete(kind: .bookmark, id: id.uuidString)
    }
    private func requireTrack(_ id: TrackID) throws {
        guard try track(id: id) != nil else { throw VideoNotebookError.missingTrack }
    }
    /// Keep all V1 fields, including unrecognized additive fields. Immutable migration
    /// archives and the source-import receipt are never rewritten by user edits.
    private func mergeNotebookPayload<T: Encodable>(_ value: T, kind: StoreKind, id: UUID, nullableKeys: [String] = []) throws {
        let encoded = try JSONEncoder().encode(value)
        guard var updated = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else { throw PersistenceError.corruptRecord(id.uuidString) }
        for key in nullableKeys where updated[key] == nil { updated[key] = NSNull() }
        let old = try record(kind: kind, id: id.uuidString)
        if let old, old.payloadVersion != 1 { throw PersistenceError.corruptRecord(old.key) }
        var merged: [String: Any] = [:]
        if let old {
            guard let fields = try JSONSerialization.jsonObject(with: old.payload) as? [String: Any] else { throw PersistenceError.corruptRecord(old.key) }
            merged = fields
        }
        merged.merge(updated) { _, new in new }
        let payload = try JSONSerialization.data(withJSONObject: merged, options: .sortedKeys)
        do {
            if let old { old.payload = payload; old.updatedAt = .init() }
            else { context.insert(MusesSchemaV1.Record(kind: kind, recordID: id.uuidString, payload: payload)) }
            try context.save()
        } catch { context.rollback(); throw error }
    }
}

public extension SwiftDataSnapshotRepository {
    /// Standalone notebook clear: one save, rollback on failure. Only mutable
    /// note/bookmark projections are removed; source archives/receipts survive.
    func deleteVideoNotebook(trackID: TrackID) throws { try deleteNotebookProjection(trackID: trackID, kind: nil) }
    func deleteVideoNotes(trackID: TrackID) throws { try deleteNotebookProjection(trackID: trackID, kind: .note) }
    func deleteVideoBookmarks(trackID: TrackID) throws { try deleteNotebookProjection(trackID: trackID, kind: .bookmark) }

    private func deleteNotebookProjection(trackID: TrackID, kind: StoreKind?) throws {
        do {
            try stageNotebookProjectionDeletion(trackID: trackID, kind: kind)
            try context.save()
        } catch { context.rollback(); throw error }
    }

    /// For the owner's atomic saved-video deletion transaction. Validates all
    /// candidate payloads BEFORE marking any rows. Does not save. The caller must
    /// save track/playlist/queue/notebook changes together, or roll back on error.
    /// Do not call the standalone deleteVideoNotebook in a multi-step deletion.
    func stageVideoNotebookDeletion(trackID: TrackID) throws {
        try stageNotebookProjectionDeletion(trackID: trackID, kind: nil)
    }

    private func stageNotebookProjectionDeletion(trackID: TrackID, kind: StoreKind?) throws {
        let noteKind = StoreKind.note.rawValue, bookmarkKind = StoreKind.bookmark.rawValue
        let candidates = try context.fetch(FetchDescriptor<MusesSchemaV1.Record>(predicate: #Predicate {
            $0.kindRaw == noteKind || $0.kindRaw == bookmarkKind
        }))
        var rows: [MusesSchemaV1.Record] = []
        for row in candidates where kind == nil || row.kindRaw == kind?.rawValue {
            guard row.payloadVersion == 1 else { throw PersistenceError.corruptRecord(row.key) }
            let owner: UUID
            do {
                if row.kindRaw == noteKind { owner = try JSONDecoder().decode(LegacyNote.self, from: row.payload).trackId }
                else { owner = try JSONDecoder().decode(LegacyBookmark.self, from: row.payload).trackId }
            } catch { throw PersistenceError.corruptRecord(row.key) }
            if owner.uuidString == trackID.rawValue { rows.append(row) }
        }
        for row in rows { context.delete(row) }
    }
}
