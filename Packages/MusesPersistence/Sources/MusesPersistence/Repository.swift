import Foundation
import SwiftData
import MusesDomain
import MusesQueue

public enum StoreKind: String, Codable, Sendable { case track, favorite, note, bookmark, playlist, playlistItem, history, queue, importRelation, importItem, setting, migration }
public struct StoredValue: Codable, Equatable, Sendable {
    public let kind: StoreKind
    public let id: String
    public let data: Data
    public init(kind: StoreKind, id: String, data: Data) { self.kind = kind; self.id = id; self.data = data }
}
public enum PersistenceError: Error, Sendable { case corruptRecord(String), unsupportedLegacyRecord(String) }

/// V1 is an additive store for migrated user truth. Payloads are versioned snapshots, never SwiftData objects crossing an actor.
public enum MusesSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    public static var models: [any PersistentModel.Type] { [Record.self] }
    @Model public final class Record {
        @Attribute(.unique) public var key: String
        public var kindRaw: String
        public var recordID: String
        public var payload: Data
        public var payloadVersion: Int
        public var updatedAt: Date
        public init(kind: StoreKind, recordID: String, payload: Data, payloadVersion: Int = 1, updatedAt: Date = .init()) {
            self.key = kind.rawValue + ":" + recordID
            self.kindRaw = kind.rawValue; self.recordID = recordID; self.payload = payload; self.payloadVersion = payloadVersion; self.updatedAt = updatedAt
        }
    }
}

public enum MusesMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [MusesSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

@MainActor public protocol SnapshotRepository {
    func put<Value: Encodable>(_ value: Value, kind: StoreKind, id: String) throws
    func get<Value: Decodable>(_ type: Value.Type, kind: StoreKind, id: String) throws -> Value?
    func list<Value: Decodable>(_ type: Value.Type, kind: StoreKind) throws -> [Value]
    func delete(kind: StoreKind, id: String) throws
}

@MainActor public final class SwiftDataSnapshotRepository: SnapshotRepository {
    public let context: ModelContext
    public init(context: ModelContext) { self.context = context }
    public static func container(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let configuration = url.map { ModelConfiguration(url: $0) } ?? ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: MusesSchemaV1.Record.self, migrationPlan: MusesMigrationPlan.self, configurations: configuration)
    }
    func record(kind: StoreKind, id: String) throws -> MusesSchemaV1.Record? {
        let key = kind.rawValue + ":" + id
        return try context.fetch(FetchDescriptor<MusesSchemaV1.Record>(predicate: #Predicate { $0.key == key })).first
    }
    public func put<Value: Encodable>(_ value: Value, kind: StoreKind, id: String) throws {
        let data = try JSONEncoder().encode(value)
        if let row = try record(kind: kind, id: id) { row.payload = data; row.updatedAt = .init() }
        else { context.insert(MusesSchemaV1.Record(kind: kind, recordID: id, payload: data)) }
        try context.save()
    }
    public func get<Value: Decodable>(_ type: Value.Type, kind: StoreKind, id: String) throws -> Value? {
        guard let row = try record(kind: kind, id: id) else { return nil }
        guard row.payloadVersion == 1 else { throw PersistenceError.corruptRecord(row.key) }
        do { return try JSONDecoder().decode(type, from: row.payload) }
        catch { throw PersistenceError.corruptRecord(row.key) }
    }
    public func list<Value: Decodable>(_ type: Value.Type, kind: StoreKind) throws -> [Value] {
        let kindRaw = kind.rawValue
        let rows = try context.fetch(FetchDescriptor<MusesSchemaV1.Record>(predicate: #Predicate { $0.kindRaw == kindRaw }, sortBy: [SortDescriptor(\.recordID)]))
        return try rows.map { row in
            guard row.payloadVersion == 1, let value = try? JSONDecoder().decode(type, from: row.payload) else { throw PersistenceError.corruptRecord(row.key) }
            return value
        }
    }
    public func delete(kind: StoreKind, id: String) throws {
        if let row = try record(kind: kind, id: id) { context.delete(row); try context.save() }
    }
    public func saveTrack(_ track: Track) throws { try put(track, kind: .track, id: track.id.rawValue) }
    public func track(id: TrackID) throws -> Track? { try get(Track.self, kind: .track, id: id.rawValue) }
    public func saveQueue(_ snapshot: QueueSnapshot) throws { try put(snapshot, kind: .queue, id: "main") }
    public func queue() throws -> QueueSnapshot? { try get(QueueSnapshot.self, kind: .queue, id: "main")?.restored() }
}
