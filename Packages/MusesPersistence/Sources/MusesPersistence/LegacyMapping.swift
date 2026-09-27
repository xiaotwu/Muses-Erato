import Foundation
import MusesDomain
import MusesQueue

/// Value bridge matching fields on the inherited `Sources/Muses/Domain/Track` model.
/// P4 reads the old model in its own ModelContext and passes only this snapshot across.
public struct LegacyTrackSnapshot: Codable, Sendable {
    public let id: UUID
    public let title: String
    public let artist: String
    public let youTubeId: String
    public let durationMs: Int
    public let liked: Bool
    public init(id: UUID, title: String, artist: String, youTubeId: String, durationMs: Int, liked: Bool) {
        self.id = id; self.title = title; self.artist = artist; self.youTubeId = youTubeId; self.durationMs = durationMs; self.liked = liked
    }
    public func mapped() throws -> Track {
        let video = try VideoID(youTubeId)
        return try Track(id: TrackID(id.uuidString), title: title, artist: artist, source: .youtubeVideo(video), provenance: Provenance(provider: ProviderID("youtube"), originalID: youTubeId), durationMilliseconds: max(0, durationMs), liked: liked)
    }
}

/// Legacy QueueState keeps an ordered `itemsJSON` list and a currentIndex. The app bridge
/// decodes its legacy QueueItem rows into these plain values before calling `mapped()`.
public struct LegacyQueueSnapshot: Codable, Sendable {
    public let items: [LegacyQueueEntry]
    public let currentIndex: Int
    public let repeatModeRaw: String
    public let shuffle: Bool
    public let lastPositionMs: Double?
    public init(items: [LegacyQueueEntry], currentIndex: Int, repeatModeRaw: String, shuffle: Bool, lastPositionMs: Double?) {
        self.items = items; self.currentIndex = currentIndex; self.repeatModeRaw = repeatModeRaw; self.shuffle = shuffle; self.lastPositionMs = lastPositionMs
    }
    public func mapped() throws -> QueueSnapshot {
        let entries = try items.map { try $0.mapped() }
        guard currentIndex >= -1 && currentIndex < entries.count else { throw PersistenceError.unsupportedLegacyRecord("queue.currentIndex") }
        let current = currentIndex >= 0 ? entries[currentIndex] : nil
        let upcoming = currentIndex >= 0 ? Array(entries.dropFirst(currentIndex + 1)) : entries
        return QueueSnapshot(current: current, upcoming: upcoming, repeatMode: QueueRepeat(rawValue: repeatModeRaw) ?? .off, shuffleEnabled: shuffle, positionMilliseconds: max(0, Int(lastPositionMs ?? 0)), intent: .pause)
    }
}
public struct LegacyQueueEntry: Codable, Sendable {
    public let id: UUID
    public let trackID: UUID
    public let youTubeId: String
    public init(id: UUID, trackID: UUID, youTubeId: String) { self.id = id; self.trackID = trackID; self.youTubeId = youTubeId }
    public func mapped() throws -> QueueEntry { try QueueEntry(id: id, trackID: TrackID(trackID.uuidString), source: .youtubeVideo(VideoID(youTubeId))) }
}
