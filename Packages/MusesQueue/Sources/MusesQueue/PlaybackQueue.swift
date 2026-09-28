import Foundation
import MusesDomain

public struct QueueEntry: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let trackID: TrackID
    public let source: PlaybackSource
    public init(id: UUID = UUID(), trackID: TrackID, source: PlaybackSource) { self.id = id; self.trackID = trackID; self.source = source }
}
public enum QueueRepeat: String, Codable, Sendable { case off, all, one }
public enum QueueError: Error, Equatable, Sendable { case duplicateEntryID, entryNotFound, generationExhausted }

public struct QueueSnapshot: Codable, Equatable, Sendable {
    public var current: QueueEntry?
    public var upcoming: [QueueEntry]
    public var history: [QueueEntry]
    /// Opaque route or collection identifier, never a display title.
    public var sourceContext: String?
    public var repeatMode: QueueRepeat
    public var shuffleEnabled: Bool
    public var shuffleSeed: UInt64
    public var generation: UInt64
    public var positionMilliseconds: Int
    public var intent: PlaybackIntent
    public init(current: QueueEntry? = nil, upcoming: [QueueEntry] = [], history: [QueueEntry] = [], sourceContext: String? = nil, repeatMode: QueueRepeat = .off, shuffleEnabled: Bool = false, shuffleSeed: UInt64 = 0, generation: UInt64 = 0, positionMilliseconds: Int = 0, intent: PlaybackIntent = .pause) {
        self.current = current; self.upcoming = upcoming; self.history = history; self.sourceContext = sourceContext; self.repeatMode = repeatMode; self.shuffleEnabled = shuffleEnabled; self.shuffleSeed = shuffleSeed; self.generation = generation; self.positionMilliseconds = positionMilliseconds; self.intent = intent
    }
    public func restored() -> Self {
        var copy = self
        copy.intent = .pause
        return copy
    }
}

/// Synchronous value reducer. The coordinator is the sole owner and tags adapter commands with generation.
public struct PlaybackQueue: Sendable {
    public private(set) var snapshot: QueueSnapshot
    public init(snapshot: QueueSnapshot = .init()) throws {
        let ids = ([snapshot.current].compactMap { $0 } + snapshot.upcoming + snapshot.history).map(\.id)
        guard Set(ids).count == ids.count else { throw QueueError.duplicateEntryID }
        self.snapshot = snapshot.restored()
    }
    private mutating func advanceGeneration() throws {
        guard snapshot.generation < UInt64.max else { throw QueueError.generationExhausted }
        snapshot.generation += 1
    }
    private func contains(_ id: UUID) -> Bool { snapshot.current?.id == id || snapshot.upcoming.contains { $0.id == id } || snapshot.history.contains { $0.id == id } }
    public mutating func playNow(_ entry: QueueEntry, context: String? = nil) throws {
        guard !contains(entry.id) else { throw QueueError.duplicateEntryID }
        try advanceGeneration()
        if let current = snapshot.current { snapshot.history.append(current) }
        snapshot.current = entry; snapshot.sourceContext = context; snapshot.positionMilliseconds = 0; snapshot.intent = .play
    }
    /// Establish collection navigation while retaining explicitly queued upcoming entries.
    public mutating func playCollection(_ entries: [QueueEntry], startingAt index: Int, context: String) throws {
        guard entries.indices.contains(index) else { throw QueueError.entryNotFound }
        let ids = entries.map(\.id)
        guard Set(ids).count == ids.count, !ids.contains(where: contains) else { throw QueueError.duplicateEntryID }
        try advanceGeneration()
        if let current = snapshot.current { snapshot.history.append(current) }
        snapshot.history.append(contentsOf: entries.prefix(index))
        snapshot.current = entries[index]
        snapshot.upcoming.insert(contentsOf: entries.dropFirst(index + 1), at: 0)
        snapshot.sourceContext = context
        snapshot.positionMilliseconds = 0
        snapshot.intent = .play
    }
    public mutating func playNext(_ entry: QueueEntry) throws {
        guard !contains(entry.id) else { throw QueueError.duplicateEntryID }
        try advanceGeneration(); snapshot.upcoming.insert(entry, at: 0)
    }
    public mutating func append(_ entry: QueueEntry) throws {
        guard !contains(entry.id) else { throw QueueError.duplicateEntryID }
        try advanceGeneration(); snapshot.upcoming.append(entry)
    }
    @discardableResult public mutating func remove(id: UUID) throws -> QueueEntry {
        guard let index = snapshot.upcoming.firstIndex(where: { $0.id == id }) else { throw QueueError.entryNotFound }
        try advanceGeneration(); return snapshot.upcoming.remove(at: index)
    }
    public mutating func reorder(id: UUID, to index: Int) throws {
        guard let old = snapshot.upcoming.firstIndex(where: { $0.id == id }), index >= 0, index < snapshot.upcoming.count else { throw QueueError.entryNotFound }
        try advanceGeneration()
        let entry = snapshot.upcoming.remove(at: old); snapshot.upcoming.insert(entry, at: index)
    }
    @discardableResult public mutating func next() throws -> QueueEntry? {
        if snapshot.repeatMode == .one, let current = snapshot.current {
            try advanceGeneration(); snapshot.positionMilliseconds = 0; return current
        }
        guard !snapshot.upcoming.isEmpty || (snapshot.repeatMode == .all && !snapshot.history.isEmpty) else {
            try advanceGeneration(); snapshot.intent = .pause; return nil
        }
        try advanceGeneration()
        if snapshot.upcoming.isEmpty { snapshot.upcoming = snapshot.history; snapshot.history = [] }
        if let current = snapshot.current { snapshot.history.append(current) }
        snapshot.current = snapshot.upcoming.removeFirst(); snapshot.positionMilliseconds = 0
        return snapshot.current
    }
    @discardableResult public mutating func previous() throws -> QueueEntry? {
        guard let previous = snapshot.history.last else { return nil }
        try advanceGeneration()
        snapshot.history.removeLast()
        if let current = snapshot.current { snapshot.upcoming.insert(current, at: 0) }
        snapshot.current = previous; snapshot.positionMilliseconds = 0
        return previous
    }
    public mutating func setRepeat(_ mode: QueueRepeat) throws { try advanceGeneration(); snapshot.repeatMode = mode }
    public mutating func setShuffle(_ enabled: Bool, seed: UInt64) throws {
        try advanceGeneration(); snapshot.shuffleEnabled = enabled; snapshot.shuffleSeed = seed
        if enabled { snapshot.upcoming.sort { rank($0.id, seed: seed) < rank($1.id, seed: seed) } }
    }
    public mutating func checkpoint(positionMilliseconds: Int) { snapshot.positionMilliseconds = max(0, positionMilliseconds) }
    public mutating func setIntent(_ intent: PlaybackIntent) { snapshot.intent = intent }
}

private func rank(_ id: UUID, seed: UInt64) -> UInt64 {
    var hash = 14695981039346656037 ^ seed
    for byte in id.uuidString.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
    return hash
}
