import Foundation
import SwiftData
import MusesPersistence
import CryptoKit

/// Explicit, non-destructive candidate activation. No startup/UI call prepares a successor.
/// The external pointer is authoritative on restart; retained parents are never fallbacks.
@MainActor enum PublicArchiveSuccessorRouter {
    enum Checkpoint: String { case intent, beforeSave, saved, verified, activated }
    struct Pending: Codable {
        let version: Int
        let parentID: UUID
        let parentProjectionDigest: String
    }
    struct Active: Codable {
        let version: Int
        let identity: SuccessorIdentity
    }
    static func selectedIfPresent(destinationURL: URL) throws -> URL? {
        let root = destinationURL.appendingPathExtension("upgrade")
        let active = root.appendingPathComponent("successor-active.json")
        if FileManager.default.fileExists(atPath: active.path) {
            let value = try JSONDecoder().decode(Active.self, from: Data(contentsOf: active))
            guard value.version == 1, value.identity.version == 1 else { throw ArchiveLifecycleError.unsupportedVersion }
            let target = candidate(root, value.identity.id)
            try verify(target, identity: value.identity)
            return target
        }
        if FileManager.default.fileExists(atPath: root.appendingPathComponent("successor-pending.json").path) {
            throw PersistenceError.unsupportedLegacyRecord("successor preparation pending; explicit retry required, original retained")
        }
        return nil
    }

    /// Calling again after termination retries only the originally bound, unchanged parent.
    /// Partial candidates are evidence and are retained under different UUIDs.
    static func prepareAndActivate(legacyURL: URL, destinationURL: URL, defaults: UserDefaults, domainName: String,
                                   checkpoint: (Checkpoint) throws -> Void = { _ in }) throws -> URL {
        let fm = FileManager.default
        let root = destinationURL.appendingPathExtension("upgrade")
        guard !fm.fileExists(atPath: root.appendingPathComponent("deleted.json").path) else { throw ArchiveLifecycleError.restoreBlocked }
        if fm.fileExists(atPath: root.appendingPathComponent("successor-active.json").path) {
            return try selectedIfPresent(destinationURL: destinationURL)!
        }
        let pendingURL = root.appendingPathComponent("successor-pending.json")
        let pending: Pending
        let parent: URL
        if fm.fileExists(atPath: pendingURL.path) {
            pending = try JSONDecoder().decode(Pending.self, from: Data(contentsOf: pendingURL))
            guard pending.version == 1 else { throw ArchiveLifecycleError.unsupportedVersion }
            parent = candidate(root, pending.parentID)
        } else {
            parent = try PublicStoreRouter.resolve(legacyURL: legacyURL, destinationURL: destinationURL, defaults: defaults, domainName: domainName)
            guard let parentID = UUID(uuidString: parent.deletingLastPathComponent().lastPathComponent),
                  parent.standardizedFileURL == candidate(root, parentID).standardizedFileURL else {
                throw PersistenceError.unsupportedLegacyRecord("successor requires a verified migrated parent")
            }
            pending = Pending(version: 1, parentID: parentID, parentProjectionDigest: try read(parent) { try $0.projectionDigestForSuccessor() })
            try PublicStoreRouter.durableWrite(JSONEncoder().encode(pending), to: pendingURL)
        }
        try checkpoint(.intent)
        let plan = try read(parent) { repo in
            guard try repo.projectionDigestForSuccessor() == pending.parentProjectionDigest else { throw ArchiveLifecycleError.invalidEvidence }
            return try repo.makeRunnableArchiveSuccessor()
        }
        let target = candidate(root, plan.id)
        try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: false)
        try autoreleasepool {
            let container = try SwiftDataSnapshotRepository.container(url: target)
            let repo = SwiftDataSnapshotRepository(context: ModelContext(container))
            try repo.installRunnableArchiveSuccessor(plan, beforeSave: { try checkpoint(.beforeSave) })
        }
        try checkpoint(.saved)
        let identity = try read(target) { repo in
            guard let identity = try repo.get(SuccessorIdentity.self, kind: .migration, id: "runnable-successor-v1"),
                  identity.initialContentDigest == (try plan.digest) else { throw ArchiveLifecycleError.invalidEvidence }
            // Verify every preserved initial payload after physical reopen, not just row counts.
            let all = try repo.context.fetch(FetchDescriptor<MusesSchemaV1.Record>())
            for row in plan.records {
                guard all.contains(where: { $0.kindRaw == row.kind.rawValue && $0.recordID == row.id && $0.payload == row.data }) else {
                    throw ArchiveLifecycleError.invalidEvidence
                }
            }
            return identity
        }
        try verify(target, identity: identity)
        try checkpoint(.verified)
        // Refuse activation if another writer edited/deleted anything in the parent meanwhile.
        guard try read(parent, { try $0.projectionDigestForSuccessor() }) == pending.parentProjectionDigest else {
            throw ArchiveLifecycleError.invalidEvidence
        }
        for suffix in ["", "-wal"] {
            let file = URL(fileURLWithPath: target.path + suffix)
            if fm.fileExists(atPath: file.path) { try PublicStoreRouter.sync(file) }
        }
        try PublicStoreRouter.sync(target.deletingLastPathComponent())
        try PublicStoreRouter.durableWrite(JSONEncoder().encode(Active(version: 1, identity: identity)), to: root.appendingPathComponent("successor-active.json"))
        try checkpoint(.activated)
        return target
    }
    struct RetainedArtifact: Codable {
        let path: String
        let role: String
        let bytes: Int
        let sha256: String?
        let destructionImpact: String
    }
    /// A read-only, concrete per-file decision inventory. Never authorizes unlinking anything.
    static func retainedCopyInventory(legacyURL: URL, destinationURL: URL) throws -> [RetainedArtifact] {
        let fm = FileManager.default
        let root = destinationURL.appendingPathExtension("upgrade")
        let selected = try selectedIfPresent(destinationURL: destinationURL)?.deletingLastPathComponent()
        var urls = [URL]()
        for base in [legacyURL, destinationURL] {
            for suffix in ["", "-wal", "-shm"] {
                let url = URL(fileURLWithPath: base.path + suffix)
                if fm.fileExists(atPath: url.path) { urls.append(url) }
            }
        }
        var enumerationError: Error?
        if let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey], errorHandler: { _, error in
            enumerationError = error; return false
        }) {
            for case let url as URL in enumerator {
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                if values.isRegularFile == true || values.isSymbolicLink == true { urls.append(url) }
            }
        }
        if let enumerationError { throw enumerationError }
        return try urls.sorted { $0.path < $1.path }.map { url in
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            let role: String
            let impact: String
            if values.isSymbolicLink == true {
                return RetainedArtifact(path: url.path, role: "unresolved-symlink", bytes: 0, sha256: nil, destructionImpact: "Target not inspected; no destruction authorized")
            } else if url.deletingLastPathComponent() == selected {
                role = "active-successor"; impact = "Would destroy the current library and post-activation edits; retain"
            } else if url.deletingLastPathComponent() == root {
                role = "route-control"; impact = "Could remove the restore barrier or deletion authority; retain"
            } else {
                role = "protected-original-or-recovery"; impact = "May remove the only copy of unknown titles, lyrics, old names, raw queue/sync/settings or historical edits; requires reviewed user decision"
            }
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var hash = SHA256()
            while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty { hash.update(data: data) }
            return RetainedArtifact(path: url.path, role: role, bytes: values.fileSize ?? 0,
                sha256: hash.finalize().map { String(format: "%02x", $0) }.joined(), destructionImpact: impact)
        }
    }

    private static func candidate(_ root: URL, _ id: UUID) -> URL {
        root.appendingPathComponent(id.uuidString).appendingPathComponent("muses-public-v1.sqlite")
    }
    private static func read<T>(_ url: URL, _ body: (SwiftDataSnapshotRepository) throws -> T) throws -> T {
        guard FileManager.default.fileExists(atPath: url.path) else { throw LegacySnapshotError.sourceMissing }
        return try autoreleasepool {
            let container = try ModelContainer(for: MusesSchemaV1.Record.self, migrationPlan: MusesMigrationPlan.self,
                configurations: ModelConfiguration(url: url, allowsSave: false, cloudKitDatabase: .none))
            return try body(SwiftDataSnapshotRepository(context: ModelContext(container)))
        }
    }
    private static func verify(_ url: URL, identity: SuccessorIdentity) throws {
        try read(url) { repo in
            guard try repo.get(SuccessorIdentity.self, kind: .migration, id: "runnable-successor-v1") == identity,
                  try repo.get(UUID.self, kind: .migration, id: "public-route-v1") == identity.id,
                  try repo.legacyArchive().receipt == identity.originalReceipt else { throw ArchiveLifecycleError.invalidEvidence }
            _ = try PublicLibrarySnapshot(repository: repo)
            try repo.validateSuccessorNotebooks()
        }
    }
}
