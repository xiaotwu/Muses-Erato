import Foundation

public enum LocalLibraryError: Error, Equatable, Sendable {
    case emptyName, invalidOrder, missingTrack
}

/// Device-local collection. Never represents or mutates a YouTube account playlist.
/// trackIDs is the unique membership projection. Occurrence-aware editors preserve
/// repeated and unavailable entries independently; playback uses their full order.
public struct LocalPlaylist: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public private(set) var name: String
    public private(set) var trackIDs: [TrackID]
    public let createdAt: Date
    public private(set) var occurrences: [LocalPlaylistOccurrence]?
    public var playbackTrackIDs: [TrackID] { occurrences?.compactMap(\.trackID) ?? trackIDs }

    public init(id: UUID = UUID(), name: String, trackIDs: [TrackID] = [], createdAt: Date = .init(), occurrences: [LocalPlaylistOccurrence]? = nil) throws {
        self.id = id
        self.name = try Self.validName(name)
        guard Set(trackIDs).count == trackIDs.count else { throw LocalLibraryError.invalidOrder }
        self.trackIDs = trackIDs
        self.createdAt = createdAt
        self.occurrences = occurrences
        try validated()
    }
    public var entryCount: Int { occurrences?.count ?? trackIDs.count }
    public mutating func removeOccurrence(_ id: UUID) {
        guard occurrences != nil else { return }
        occurrences?.removeAll { $0.id == id }
        rebuildProjection()
    }
    public mutating func reorderOccurrences(_ ids: [UUID]) throws {
        guard let original = occurrences, ids.count == original.count,
              Set(ids).count == ids.count, Set(ids) == Set(original.map(\.id)) else { throw LocalLibraryError.invalidOrder }
        let entries = Dictionary(uniqueKeysWithValues: original.map { ($0.id, $0) })
        occurrences = ids.compactMap { entries[$0] }
        rebuildProjection()
    }
    public mutating func removeAllEntries() {
        trackIDs = []
        if occurrences != nil { occurrences = [] }
    }
    private mutating func rebuildProjection() {
        guard let occurrences else { return }
        var seen = Set<TrackID>()
        trackIDs = occurrences.compactMap(\.trackID).filter { seen.insert($0).inserted }
    }
    public mutating func rename(_ name: String) throws { self.name = try Self.validName(name) }
    public mutating func add(_ id: TrackID) {
        if !trackIDs.contains(id) {
            trackIDs.append(id)
            if occurrences != nil { occurrences?.append(.init(id: UUID(), trackID: id)) }
        }
    }
    public mutating func remove(_ id: TrackID) {
        trackIDs.removeAll { $0 == id }
        occurrences?.removeAll { $0.trackID == id }
    }
    public mutating func reorder(_ ids: [TrackID]) throws {
        guard ids.count == trackIDs.count, Set(ids) == Set(trackIDs) else { throw LocalLibraryError.invalidOrder }
        trackIDs = ids
        if let original = occurrences {
            occurrences = ids.flatMap { id in original.filter { $0.trackID == id } }
                + original.filter { $0.trackID == nil }
        }
    }
    public func validated() throws {
        _ = try Self.validName(name)
        guard Set(trackIDs).count == trackIDs.count else { throw LocalLibraryError.invalidOrder }
        if let occurrences {
            var seen = Set<TrackID>()
            let projection = occurrences.compactMap(\.trackID).filter { seen.insert($0).inserted }
            guard Set(occurrences.map(\.id)).count == occurrences.count, projection == trackIDs else {
                throw LocalLibraryError.invalidOrder
            }
        }
    }
    private static func validName(_ name: String) throws -> String {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw LocalLibraryError.emptyName }
        return value
    }
}

/// Wire-compatible with the initial public app's PlayedVideo payload.
public struct PlaybackHistoryEntry: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let trackID: TrackID
    public let date: Date
    public init(id: UUID = UUID(), trackID: TrackID, date: Date = .init()) {
        self.id = id; self.trackID = trackID; self.date = date
    }
}

public struct LocalPlaylistOccurrence: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let trackID: TrackID?
    public init(id: UUID, trackID: TrackID?) { self.id = id; self.trackID = trackID }
}
