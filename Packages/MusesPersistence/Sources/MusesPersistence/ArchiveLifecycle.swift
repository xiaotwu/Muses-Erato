import Foundation
import CryptoKit
import SwiftData

/// Evidence is a reviewed input, never inferred from a title, provider ID or migration date.
public enum ArchiveOrigin: String, Codable, Sendable { case userInput, publicAPI, authorizedAPI, unknown }
public struct ArchiveField: Codable, Equatable, Sendable {
    public let address: String
    public let value: Data // canonical JSON fragment; opaque nested JSON is not relabeled as local content
    public var digest: String { Self.hash(value) }
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}
public struct ArchiveEvidence: Codable, Sendable {
    public let address: String
    public let valueDigest: String
    public let origin: ArchiveOrigin
    /// Auditable source-contract/review reference, not credentials or an account identifier.
    public let reference: String
    public let fetchedAt: Date?
    public let authorizationReference: String?
    public init(field: ArchiveField, origin: ArchiveOrigin, reference: String,
                fetchedAt: Date? = nil, authorizationReference: String? = nil) {
        address = field.address; valueDigest = field.digest; self.origin = origin
        self.reference = reference; self.fetchedAt = fetchedAt; self.authorizationReference = authorizationReference
    }
}
public enum ArchiveDisposition: String, Codable, Sendable { case preserveUserInput, temporaryAPI, removalDue, unresolved, excludedByDeletion }
public struct ArchiveAssessment: Codable, Sendable {
    public let address: String
    public let digest: String
    public let origin: ArchiveOrigin
    public let disposition: ArchiveDisposition
    public let evidenceReference: String?
    public let deadline: Date?
    public let fetchedAt: Date?
    public let authorizationReference: String?
}
public struct ArchiveSuccessor: Codable, Sendable {
    public let version: Int
    /// Describes the original complete import ONLY. Never recomputed to describe the successor.
    public let originalReceipt: LegacyMigrationReceipt?
    public let parentArchiveDigest: String
    public let assessedAt: Date
    public let assessments: [ArchiveAssessment]
    /// Only evidenced user input, keyed by original record/field identity. No whole mixed records.
    public let userFields: [ArchiveField]
    public let excludedAddresses: Set<String>
    public var hasUnresolvedFields: Bool { assessments.contains { $0.disposition == .unresolved } }
}
public enum ArchiveLifecycleError: Error, Equatable {
    case invalidPolicyClock, invalidEvidence, duplicateAddress, unsupportedVersion, restoreBlocked, invalidArtifact, removalUnverified
}

public enum ArchiveLifecycle {
    /// This interval is supplied by the reviewed policy. It is not permission to retain data.
    /// Evaluation is synchronous with an injected clock; no promise of execution while suspended.
    public static func successor(fields: [ArchiveField], evidence: [ArchiveEvidence],
                                 originalReceipt: LegacyMigrationReceipt?, parentArchiveDigest: String,
                                 now: Date, maximumAPIAge: TimeInterval,
                                 revokedAuthorizations: Set<String> = [], excludedAddresses: Set<String> = []) throws -> ArchiveSuccessor {
        guard now.timeIntervalSinceReferenceDate.isFinite, maximumAPIAge.isFinite, maximumAPIAge > 0 else {
            throw ArchiveLifecycleError.invalidPolicyClock
        }
        guard Set(fields.map(\.address)).count == fields.count,
              Set(evidence.map(\.address)).count == evidence.count else { throw ArchiveLifecycleError.duplicateAddress }
        let byAddress = Dictionary(uniqueKeysWithValues: fields.map { ($0.address, $0) })
        for item in evidence {
            guard byAddress[item.address]?.digest == item.valueDigest,
                  !item.reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  item.origin != .authorizedAPI || !(item.authorizationReference ?? "").isEmpty else {
                throw ArchiveLifecycleError.invalidEvidence
            }
        }
        let reviews = Dictionary(uniqueKeysWithValues: evidence.map { ($0.address, $0) })
        var preserved: [ArchiveField] = []
        let assessments = fields.sorted { $0.address < $1.address }.map { field -> ArchiveAssessment in
            let review = reviews[field.address]
            let origin = review?.origin ?? .unknown
            var deadline: Date?
            let disposition: ArchiveDisposition
            if excludedAddresses.contains(field.address) { disposition = .excludedByDeletion }
            else if origin == .userInput { disposition = .preserveUserInput; preserved.append(field) }
            else if origin == .unknown { disposition = .unresolved }
            else if let fetched = review?.fetchedAt, fetched.timeIntervalSinceReferenceDate.isFinite, fetched <= now {
                let end = fetched.addingTimeInterval(maximumAPIAge)
                deadline = end
                disposition = now >= end || review?.authorizationReference.map { revokedAuthorizations.contains($0) } == true
                    ? .removalDue : .temporaryAPI
            } else { disposition = .removalDue } // Missing/future age never receives a fresh lease.
            return ArchiveAssessment(address: field.address, digest: field.digest, origin: origin,
                disposition: disposition, evidenceReference: review?.reference, deadline: deadline,
                fetchedAt: review?.fetchedAt, authorizationReference: review?.authorizationReference)
        }
        return ArchiveSuccessor(version: 1, originalReceipt: originalReceipt, parentArchiveDigest: parentArchiveDigest,
            assessedAt: now, assessments: assessments, userFields: preserved, excludedAddresses: excludedAddresses)
    }

    /// Inventory every persisted scalar, including unknown/future fields. Nested opaque values
    /// remain one unknown field unless an explicit field-specific review establishes their origin.
    public static func inventory(_ archive: LegacyLibraryArchive) throws -> [ArchiveField] {
        guard archive.formatVersion == 1 else { throw ArchiveLifecycleError.unsupportedVersion }
        var result: [ArchiveField] = []
        func append(_ data: Data, prefix: String) throws {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw PersistenceError.corruptRecord("archive inventory object")
            }
            for key in object.keys.sorted() {
                result.append(ArchiveField(address: prefix + "/" + key.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1"),
                    value: try JSONSerialization.data(withJSONObject: object[key]!, options: [.sortedKeys, .fragmentsAllowed])))
            }
        }
        let encoder = JSONEncoder()
        for track in archive.tracks { try append(encoder.encode(track), prefix: "track/" + track.id.uuidString) }
        for queue in archive.queue { try append(encoder.encode(queue), prefix: "queue/" + queue.id.uuidString) }
        for kind in archive.models.keys.sorted() {
            for model in archive.models[kind]! { try append(model.fields, prefix: "model/" + kind + "/" + model.id.uuidString) }
        }
        for setting in archive.settings {
            // Encode the full setting: its value may be mixed/private even when its key sounds local.
            try append(encoder.encode(setting), prefix: "setting/" + setting.key)
        }
        guard Set(result.map(\.address)).count == result.count else { throw ArchiveLifecycleError.duplicateAddress }
        return result.sorted { $0.address < $1.address }
    }
}

/// Protocol state for a future approved physical-copy cleanup. No file deletion implementation
/// is shipped here. Callers must durably save the intent BEFORE invoking any removal adapter.
public struct ArchiveRemovalJournal: Codable, Sendable {
    public let version: Int
    public let successorID: UUID
    public let requiredArtifactIDs: Set<String>
    public private(set) var verifiedAbsent: Set<String>
    public private(set) var failedArtifactIDs: Set<String>
    public var allListedArtifactsAbsent: Bool { version == 1 && !requiredArtifactIDs.isEmpty && failedArtifactIDs.isEmpty && verifiedAbsent == requiredArtifactIDs }
    public init(successorID: UUID, requiredArtifactIDs: Set<String>) throws {
        guard !requiredArtifactIDs.isEmpty, !requiredArtifactIDs.contains("") else { throw ArchiveLifecycleError.invalidArtifact }
        version = 1; self.successorID = successorID; self.requiredArtifactIDs = requiredArtifactIDs
        verifiedAbsent = []; failedArtifactIDs = []
    }
    /// An error or a successful unlink with surviving bytes both leave cleanup pending.
    /// Tests use synthetic files; production wiring requires the reviewed destruction scope.
    public mutating func attempt(_ artifactID: String, remove: () throws -> Void, isAbsent: () throws -> Bool) throws {
        guard version == 1 else { throw ArchiveLifecycleError.unsupportedVersion }
        guard requiredArtifactIDs.contains(artifactID) else { throw ArchiveLifecycleError.invalidArtifact }
        verifiedAbsent.remove(artifactID)
        do {
            try remove()
            guard try isAbsent() else { throw ArchiveLifecycleError.removalUnverified }
            verifiedAbsent.insert(artifactID); failedArtifactIDs.remove(artifactID)
        } catch { failedArtifactIDs.insert(artifactID); throw error }
    }
}

@MainActor public extension SwiftDataSnapshotRepository {
    /// Explicit engineering staging API; not called by startup or expiry. No source/archive changes.
    /// A staged successor prevents the existing whole-archive restore from bypassing its exclusions.
    func stageArchiveSuccessor(_ successor: ArchiveSuccessor) throws {
        guard successor.version == 1 else { throw ArchiveLifecycleError.unsupportedVersion }
        guard successor.parentArchiveDigest == (try legacyArchiveDigest()),
              successor.originalReceipt == (try legacyArchive().receipt) else { throw ArchiveLifecycleError.invalidEvidence }
        let fields = try ArchiveLifecycle.inventory(legacyArchive())
        let assessments = successor.assessments
        guard assessments.count == fields.count,
              Set(assessments.map(\.address)).count == fields.count,
              fields.allSatisfy({ field in assessments.contains { $0.address == field.address && $0.digest == field.digest } }),
              Set(successor.userFields.map(\.address)).count == successor.userFields.count,
              Set(successor.userFields.map(\.address)) == Set(assessments.filter { $0.disposition == .preserveUserInput }.map(\.address)),
              successor.userFields.allSatisfy({ field in
                  fields.contains(field) && !successor.excludedAddresses.contains(field.address)
                    && assessments.contains { $0.address == field.address && $0.origin == .userInput && !($0.evidenceReference ?? "").isEmpty }
              }) else { throw ArchiveLifecycleError.invalidEvidence }
        // Do not overwrite an existing staged decision with a less restrictive plan.
        guard try record(kind: .migration, id: "archive-successor-v1") == nil else { throw ArchiveLifecycleError.restoreBlocked }
        try put(successor, kind: .migration, id: "archive-successor-v1")
    }
    func requireOriginalArchiveRestoreAllowed() throws {
        // Presence blocks even malformed/unknown-version payloads; never fall back to old originals.
        guard try record(kind: .migration, id: "archive-successor-v1") == nil,
              try record(kind: .migration, id: "runnable-successor-v1") == nil else { throw ArchiveLifecycleError.restoreBlocked }
    }
}
