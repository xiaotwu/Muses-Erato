import Foundation

public enum VideoNotebookError: Error, Equatable, LocalizedError, Sendable {
    case invalidTime, emptyNote, missingTrack, missingEntry, changedIdentity, unavailable
    public var errorDescription: String? {
        switch self {
        case .invalidTime: "Enter a finite, nonnegative time in seconds."
        case .emptyNote: "Write some text before saving the note."
        case .missingTrack: "The saved video could not be found."
        case .missingEntry: "This notebook entry could not be found."
        case .changedIdentity: "The original entry identity cannot be changed."
        case .unavailable: "The local notebook is unavailable. Try loading it again."
        }
    }
}

/// User-authored text. Wire keys match the initial LegacyNote projection.
public struct VideoNote: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let trackID: TrackID
    public let content: String
    public let createdAt: Date
    public let updatedAt: Date
    public init(id: UUID = UUID(), trackID: TrackID, content: String, createdAt: Date = .init(), updatedAt: Date = .init()) {
        self.id = id; self.trackID = trackID; self.content = content
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
    enum CodingKeys: String, CodingKey { case id, trackID = "trackId", content, createdAt, updatedAt }
    public func edited(content: String, at date: Date = .init()) -> Self {
        .init(id: id, trackID: trackID, content: content, createdAt: createdAt, updatedAt: date)
    }
}

/// A location in a video, not permission to start or continue playback.
public struct VideoTimeBookmark: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let trackID: TrackID
    public let timestampMilliseconds: Double
    public let title: String?
    public let note: String?
    public init(id: UUID = UUID(), trackID: TrackID, timestampMilliseconds: Double, title: String? = nil, note: String? = nil) throws {
        try Self.validateTime(timestampMilliseconds)
        self.id = id; self.trackID = trackID; self.timestampMilliseconds = timestampMilliseconds
        self.title = title; self.note = note
    }
    public static func validateTime(_ milliseconds: Double) throws {
        guard milliseconds.isFinite, milliseconds >= 0, milliseconds < Double(Int.max) else { throw VideoNotebookError.invalidTime }
    }
    enum CodingKeys: String, CodingKey { case id, trackID = "trackId", timestampMilliseconds = "timestampMs", title, note }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: values.decode(UUID.self, forKey: .id), trackID: values.decode(TrackID.self, forKey: .trackID),
                      timestampMilliseconds: values.decode(Double.self, forKey: .timestampMilliseconds),
                      title: values.decodeIfPresent(String.self, forKey: .title), note: values.decodeIfPresent(String.self, forKey: .note))
    }
}

/// Actor-neutral snapshots cross this boundary; no SwiftData model escapes it.
@MainActor public protocol VideoNotebookRepository: AnyObject {
    func videoNotes(trackID: TrackID) throws -> [VideoNote]
    func videoBookmarks(trackID: TrackID) throws -> [VideoTimeBookmark]
    func saveVideoNote(_ note: VideoNote) throws
    func saveVideoBookmark(_ bookmark: VideoTimeBookmark) throws
    func deleteVideoNotes(trackID: TrackID) throws
    func deleteVideoBookmarks(trackID: TrackID) throws
    func deleteVideoNote(id: UUID, trackID: TrackID) throws
    func deleteVideoBookmark(id: UUID, trackID: TrackID) throws
}
