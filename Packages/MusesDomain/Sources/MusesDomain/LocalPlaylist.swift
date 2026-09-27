import Foundation

public enum LocalLibraryError: Error, Equatable, Sendable {
    case emptyName, invalidOrder, missingTrack
}

/// Device-local collection. Never represents or mutates a YouTube account playlist.
/// A video occurs at most once; adding it again is an idempotent operation.
public struct LocalPlaylist: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public private(set) var name: String
    public private(set) var trackIDs: [TrackID]
    public let createdAt: Date

    public init(id: UUID = UUID(), name: String, trackIDs: [TrackID] = [], createdAt: Date = .init()) throws {
        self.id = id
        self.name = try Self.validName(name)
        guard Set(trackIDs).count == trackIDs.count else { throw LocalLibraryError.invalidOrder }
        self.trackIDs = trackIDs
        self.createdAt = createdAt
    }
    public mutating func rename(_ name: String) throws { self.name = try Self.validName(name) }
    public mutating func add(_ id: TrackID) { if !trackIDs.contains(id) { trackIDs.append(id) } }
    public mutating func remove(_ id: TrackID) { trackIDs.removeAll { $0 == id } }
    public mutating func reorder(_ ids: [TrackID]) throws {
        guard ids.count == trackIDs.count, Set(ids) == Set(trackIDs) else { throw LocalLibraryError.invalidOrder }
        trackIDs = ids
    }
    public func validated() throws {
        _ = try Self.validName(name)
        guard Set(trackIDs).count == trackIDs.count else { throw LocalLibraryError.invalidOrder }
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
