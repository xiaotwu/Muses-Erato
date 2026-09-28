import Foundation
import SwiftData
import MusesDomain
import MusesQueue

public struct LocalLibraryDeletionSnapshot {
    public let tracks: [Track]
    public let playlists: [LocalPlaylist]
    public let history: [PlaybackHistoryEntry]
    public let queue: QueueSnapshot
}

public extension SwiftDataSnapshotRepository {
    /// Current public-library graph only. Legacy archives/source stores remain untouched. Notebook projections
    /// participate in the same save through the notebook staging interface.
    func deleteSavedTrack(_ id: TrackID) throws -> LocalLibraryDeletionSnapshot {
        try deleteSavedTracks([id])
    }

    func deleteSavedTracks(_ ids: Set<TrackID>) throws -> LocalLibraryDeletionSnapshot {
        try deleteSavedTracks(ids, save: { try context.save() })
    }

    func clearLocalFavorites() throws -> [Track] {
        var tracks = try list(Track.self, kind: .track)
        let encoder = JSONEncoder()
        for index in tracks.indices { tracks[index].liked = false }
        let payloads = try tracks.map { ($0.id, try encoder.encode($0.localPersistenceSnapshot)) }
        do {
            for (id, data) in payloads {
                guard let row = try record(kind: .track, id: id.rawValue), row.payloadVersion == 1 else { throw PersistenceError.corruptRecord(id.rawValue) }
                row.payload = data; row.updatedAt = Date()
            }
            let kind = StoreKind.favorite.rawValue
            for row in try context.fetch(FetchDescriptor<MusesSchemaV1.Record>(predicate: #Predicate { $0.kindRaw == kind })) { context.delete(row) }
            try context.save(); return tracks
        } catch { context.rollback(); throw error }
    }

    func removeLocalHistory(for id: TrackID) throws -> [PlaybackHistoryEntry] {
        let history = try list(PlaybackHistoryEntry.self, kind: .history)
        do {
            for entry in history where entry.trackID == id {
                if let row = try record(kind: .history, id: entry.id.uuidString) { context.delete(row) }
            }
            try context.save()
            return history.filter { $0.trackID != id }
        } catch { context.rollback(); throw error }
    }

    func removeLocalFavorite(_ id: TrackID) throws -> Track {
        guard var track = try track(id: id) else { throw LocalLibraryError.missingTrack }
        track.liked = false
        let data = try JSONEncoder().encode(track.localPersistenceSnapshot)
        do {
            guard let row = try record(kind: .track, id: id.rawValue), row.payloadVersion == 1 else { throw PersistenceError.corruptRecord(id.rawValue) }
            row.payload = data; row.updatedAt = Date()
            if let favorite = try record(kind: .favorite, id: id.rawValue) { context.delete(favorite) }
            try context.save()
            return track
        } catch { context.rollback(); throw error }
    }
}

extension SwiftDataSnapshotRepository {
    // Internal save seam exercises rollback after staged mutations in package tests.
    func deleteSavedTracks(_ ids: Set<TrackID>, save: () throws -> Void) throws -> LocalLibraryDeletionSnapshot {
        let tracks = try list(Track.self, kind: .track)
        guard ids.isSubset(of: Set(tracks.map(\.id))) else { throw LocalLibraryError.missingTrack }
        var playlists = try localPlaylists()
        let history = try list(PlaybackHistoryEntry.self, kind: .history)
        var queue = try self.queue() ?? QueueSnapshot()
        guard queue.generation < UInt64.max else { throw QueueError.generationExhausted }
        queue.generation += 1
        queue.upcoming.removeAll { ids.contains($0.trackID) }
        queue.history.removeAll { ids.contains($0.trackID) }
        if queue.current.map({ ids.contains($0.trackID) }) == true {
            queue.current = nil; queue.positionMilliseconds = 0; queue.sourceContext = nil
        }
        queue.intent = .pause
        _ = try PlaybackQueue(snapshot: queue)
        for index in playlists.indices { for id in ids { playlists[index].remove(id) } }
        let encoder = JSONEncoder()
        let replacements = try playlists.map { (StoreKind.localPlaylist, $0.id.uuidString, try encoder.encode($0.localPersistenceSnapshot)) }
            + [(.queue, "main", try encoder.encode(queue))]
        do {
            for id in ids { try stageVideoNotebookDeletion(trackID: id) }
            for (kind, key, data) in replacements {
                if let row = try record(kind: kind, id: key) {
                    guard row.payloadVersion == 1 else { throw PersistenceError.corruptRecord(row.key) }
                    row.payload = data; row.updatedAt = Date()
                } else { context.insert(MusesSchemaV1.Record(kind: kind, recordID: key, payload: data)) }
            }
            for entry in history where ids.contains(entry.trackID) {
                if let row = try record(kind: .history, id: entry.id.uuidString) { context.delete(row) }
            }
            for id in ids {
                if let favorite = try record(kind: .favorite, id: id.rawValue) { context.delete(favorite) }
                if let track = try record(kind: .track, id: id.rawValue) { context.delete(track) }
            }
            try save()
            return LocalLibraryDeletionSnapshot(tracks: tracks.filter { !ids.contains($0.id) }, playlists: playlists,
                history: history.filter { !ids.contains($0.trackID) }, queue: queue)
        } catch { context.rollback(); throw error }
    }
}
