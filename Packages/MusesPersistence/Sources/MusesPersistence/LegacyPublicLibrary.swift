import Foundation
import SwiftData
import CryptoKit
import MusesDomain
import MusesQueue

/// Readable archive, independent of the inherited @Model graph. Export never includes live objects.
public struct LegacyLibraryArchive: Codable, Sendable {
    public let formatVersion: Int
    public let receipt: LegacyMigrationReceipt?
    public let tracks: [LegacyTrackArchive]
    public let queue: [LegacyQueueArchive]
    public let models: [String: [LegacyModelArchive]]
    public let settings: [LegacySetting]
}

/// One public reader used both before activation and on every startup.
public struct PublicLibrarySnapshot {
    public let tracks: [Track]
    public let history: [PlaybackHistoryEntry]
    public let playlists: [LocalPlaylist]
    public let queue: QueueSnapshot

    @MainActor public init(repository: SwiftDataSnapshotRepository) throws {
        tracks = try repository.list(Track.self, kind: .track)
        history = try repository.list(PlaybackHistoryEntry.self, kind: .history)
        playlists = try repository.localPlaylists()
        queue = try repository.queue() ?? .init()
        let ids = Set(tracks.map(\.id))
        guard playlists.allSatisfy({ Set($0.trackIDs).isSubset(of: ids) }),
              Set(history.map(\.trackID)).isSubset(of: ids),
              tracks.allSatisfy({ if case .youtubeVideo = $0.source { return true }; return false }),
              ([queue.current].compactMap { $0 } + queue.upcoming + queue.history).allSatisfy({ entry in
                  tracks.contains { $0.id == entry.trackID && $0.source == entry.source }
              }) else { throw LocalLibraryError.missingTrack }
        _ = try PlaybackQueue(snapshot: queue)
    }
}

@MainActor public extension SwiftDataSnapshotRepository {
    func legacyArchive() throws -> LegacyLibraryArchive {
        var models: [String: [LegacyModelArchive]] = [:]
        for row in try context.fetch(FetchDescriptor<MusesSchemaV1.Record>()) where row.kindRaw == StoreKind.legacyModel.rawValue {
            guard row.payloadVersion == 1, let kind = row.recordID.split(separator: ":").first,
                  LegacyModelKind(rawValue: String(kind)) != nil else { throw PersistenceError.corruptRecord(row.key) }
            models[String(kind), default: []].append(try JSONDecoder().decode(LegacyModelArchive.self, from: row.payload))
        }
        for key in models.keys { models[key]?.sort { $0.id.uuidString < $1.id.uuidString } }
        return LegacyLibraryArchive(formatVersion: 1,
            receipt: try get(LegacyMigrationReceipt.self, kind: .migration, id: "legacy-complete-v1"), tracks: try list(LegacyTrackArchive.self, kind: .legacyTrack),
            queue: try list(LegacyQueueArchive.self, kind: .legacyQueue), models: models,
            settings: try list(LegacySetting.self, kind: .setting))
    }

    /// Digest only immutable originals. Public favorites, playlists and history may change after activation.
    func legacyArchiveDigest() throws -> String {
        let kinds: Set<String> = ["legacyTrack", "legacyQueue", "legacyModel", "setting"]
        let records = try context.fetch(FetchDescriptor<MusesSchemaV1.Record>()).filter { kinds.contains($0.kindRaw) }
        var input = Data()
        for row in records.sorted(by: { $0.key < $1.key }) {
            guard row.payloadVersion == 1 else { throw PersistenceError.corruptRecord(row.key) }
            let object = try JSONSerialization.jsonObject(with: row.payload, options: .fragmentsAllowed)
            input.append(contentsOf: row.key.utf8)
            input.append(0)
            input.append(try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .fragmentsAllowed]))
            input.append(0)
        }
        return SHA256.hash(data: input).map { String(format: "%02x", $0) }.joined()
    }

    /// Returns ALL original occurrences, even if no longer playable. A restore never overwrites edits.
    func originalPlaylists() throws -> [LocalPlaylist] {
        let parents = try list(LegacyPlaylist.self, kind: .playlist)
        let items = try list(LegacyPlaylistItem.self, kind: .playlistItem)
        let available = Set(try list(Track.self, kind: .track).map(\.id))
        return try parents.map { parent in
            let occurrences = try items.filter { $0.playlistID == parent.id }
                .sorted { $0.order == $1.order ? $0.id.uuidString < $1.id.uuidString : $0.order < $1.order }
                .map { item in
                    let track = try item.trackID.map { try TrackID($0.uuidString) }
                    return LocalPlaylistOccurrence(id: item.id, trackID: track.flatMap { available.contains($0) ? $0 : nil })
                }
            var seen = Set<TrackID>()
            let ids = occurrences.compactMap(\.trackID).filter { seen.insert($0).inserted }
            return try LocalPlaylist(id: parent.id, name: parent.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Recovered playlist" : parent.name,
                trackIDs: ids, createdAt: parent.createdAt, occurrences: occurrences)
        }
    }

    func restoreOriginalPlaylist(_ id: UUID) throws -> LocalPlaylist {
        let referenced = Set(try list(LegacyPlaylistItem.self, kind: .playlistItem)
            .filter { $0.playlistID == id }.compactMap(\.trackID))
        var recovered: LocalPlaylist?
        try context.transaction {
            // Rehydrate only this playlist's missing tracks; existing public edits win.
            for original in try list(LegacyTrackArchive.self, kind: .legacyTrack) where referenced.contains(original.id) {
                let track = try original.publicTrack()
                if try self.track(id: track.id) == nil {
                    context.insert(MusesSchemaV1.Record(kind: .track, recordID: track.id.rawValue,
                        payload: try JSONEncoder().encode(track)))
                }
            }
            guard let original = try originalPlaylists().first(where: { $0.id == id }) else {
                throw PersistenceError.unsupportedLegacyRecord("missing original playlist")
            }
            let playlist = try LocalPlaylist(name: original.name + " (restored)", trackIDs: original.trackIDs,
                createdAt: .init(), occurrences: original.occurrences)
            context.insert(MusesSchemaV1.Record(kind: .localPlaylist, recordID: playlist.id.uuidString,
                payload: try JSONEncoder().encode(playlist)))
            try context.save()
            recovered = playlist
        }
        guard let recovered else { throw PersistenceError.corruptRecord("restored playlist") }
        return recovered
    }

    /// Runs only on an isolated candidate AFTER the complete import has been verified.
    func projectLegacyForPublic(routeID: UUID) throws {
        guard try record(kind: .migration, id: "public-route-v1") == nil else {
            throw PersistenceError.unsupportedLegacyRecord("already projected")
        }
        let oldHistory = try list(LegacyHistoryEvent.self, kind: .history)
        var trackIDs = Set(try list(Track.self, kind: .track).map(\.id))
        struct Queued: Decodable {
            struct Snapshot: Decodable {
                let id: UUID; let title: String; let artist: String; let youTubeId: String
                let durationSeconds: Double; let liked: Bool?
            }
            let track: Snapshot
        }
        var queueTracks: [Track] = []
        for archived in try list(LegacyQueueArchive.self, kind: .legacyQueue) {
            for json in [archived.itemsJSON, archived.upNextJSON, archived.historyJSON] {
                for item in try JSONDecoder().decode([Queued].self, from: Data(json.utf8)) {
                    let id = try TrackID(item.track.id.uuidString)
                    guard item.track.durationSeconds.isFinite, item.track.durationSeconds >= 0,
                          item.track.durationSeconds < Double(Int.max / 1000) else {
                        throw PersistenceError.unsupportedLegacyRecord("queue duration")
                    }
                    if trackIDs.insert(id).inserted {
                        queueTracks.append(try Track(id: id, title: item.track.title, artist: item.track.artist,
                            source: .youtubeVideo(VideoID(item.track.youTubeId)),
                            provenance: Provenance(provider: ProviderID("youtube"), originalID: item.track.youTubeId),
                            durationMilliseconds: Int(item.track.durationSeconds * 1000), liked: item.track.liked ?? false))
                    }
                }
            }
        }
        let playlists = try originalPlaylists()
        try context.transaction {
            for track in queueTracks {
                context.insert(MusesSchemaV1.Record(kind: .track, recordID: track.id.rawValue,
                    payload: try JSONEncoder().encode(track)))
            }
            for entry in oldHistory {
                let id = try TrackID(entry.trackID.uuidString)
                guard let row = try record(kind: .history, id: entry.id.uuidString) else { continue }
                // Deleted-track events remain fully accessible in the original model archive.
                if trackIDs.contains(id) {
                    row.payload = try JSONEncoder().encode(PlaybackHistoryEntry(id: entry.id, trackID: id, date: entry.startedAt))
                } else { context.delete(row) }
            }
            for playlist in playlists {
                context.insert(MusesSchemaV1.Record(kind: .localPlaylist, recordID: playlist.id.uuidString,
                    payload: try JSONEncoder().encode(playlist)))
            }
            context.insert(MusesSchemaV1.Record(kind: .migration, recordID: "public-route-v1",
                payload: try JSONEncoder().encode(routeID)))
            try context.save()
        }
        _ = try PublicLibrarySnapshot(repository: self)
    }

}
