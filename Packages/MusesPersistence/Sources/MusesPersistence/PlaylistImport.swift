import Foundation
import SwiftData
import MusesDomain

public extension SwiftDataSnapshotRepository {
    /// IDs are user-selected library membership; API display metadata is never written.
    func importPlaylist(name: String, videoIDs: [VideoID]) throws -> (LocalPlaylist, [Track]) {
        let existing = try list(Track.self, kind: .track)
        var added: [Track] = []
        var ordered: [TrackID] = []
        for video in videoIDs {
            let track: Track
            if let saved = (existing + added).first(where: { $0.source == .youtubeVideo(video) }) { track = saved }
            else {
                track = try Track(id: TrackID(UUID().uuidString), title: "YouTube video \(video.rawValue)", artist: "YouTube", source: .youtubeVideo(video), provenance: Provenance(provider: ProviderID("youtube"), originalID: video.rawValue), metadataOrigin: .placeholder)
                added.append(track)
            }
            ordered.append(track.id)
        }
        var seen = Set<TrackID>()
        let playlist = try LocalPlaylist(name: name, trackIDs: ordered.filter { seen.insert($0).inserted }, occurrences: ordered.map { LocalPlaylistOccurrence(id: UUID(), trackID: $0) })
        do {
            for track in added {
                context.insert(MusesSchemaV1.Record(kind: .track, recordID: track.id.rawValue, payload: try JSONEncoder().encode(track.localPersistenceSnapshot)))
            }
            context.insert(MusesSchemaV1.Record(kind: .localPlaylist, recordID: playlist.id.uuidString, payload: try JSONEncoder().encode(playlist)))
            try context.save()
        } catch { context.rollback(); throw error }
        return (playlist, added)
    }
}
