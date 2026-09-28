import Foundation
import SwiftData
import CryptoKit
import Darwin
import MusesPersistence

/// Hooks are injected by tests/executables, never enabled by production environment variables.
enum LegacyUpgradeCheckpoint: String, CaseIterable {
    case snapshot, beforeLegacyCommit, legacyCommitted, projected, prepared, activated, deletionMarked, deletionPurged
}

@MainActor
enum PublicStoreRouter {
    struct Activation: Codable {
        var version: Int = 1
        let routeID: UUID
        let sourceDigest: String
        let archiveDigest: String
    }

    struct Deletion: Codable {
        var version: Int = 1
        let routeID: UUID
        var externalCleanupComplete: Bool = true
        var settingsCleared: Bool = false
        var generationInitialized: Bool = false
        var cleanupComplete: Bool
    }
    enum ExternalDeletionPending: Error { case cleanupRequired }
    private static var deletionsInThisProcess = Set<UUID>()

    /// Explicit user deletion supersedes rollback retention. A durable tombstone wins
    /// over both pending/active migration markers, even if termination follows immediately.
    static func requestDeletion(legacyURL: URL, destinationURL: URL, defaults: UserDefaults, domainName: String,
                                externalCleanupRequired: Bool = false,
                                checkpoint: @escaping (LegacyUpgradeCheckpoint) throws -> Void = { _ in }) throws -> URL {
        let root = destinationURL.appendingPathExtension("upgrade")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let deletion = Deletion(routeID: UUID(), externalCleanupComplete: !externalCleanupRequired, cleanupComplete: false)
        try durableWrite(try JSONEncoder().encode(deletion), to: root.appendingPathComponent("deleted.json"))
        deletionsInThisProcess.insert(deletion.routeID)
        try checkpoint(.deletionMarked)
        if externalCleanupRequired { return candidate(root: root, id: deletion.routeID) }
        return try resolve(legacyURL: legacyURL, destinationURL: destinationURL,
            defaults: defaults, domainName: domainName, checkpoint: checkpoint)
    }

    static func completeExternalDeletion(destinationURL: URL) throws {
        let url = destinationURL.appendingPathExtension("upgrade").appendingPathComponent("deleted.json")
        var deletion = try JSONDecoder().decode(Deletion.self, from: Data(contentsOf: url))
        guard deletion.version == 1 else { throw PersistenceError.unsupportedLegacyRecord("deletion route version") }
        deletion.externalCleanupComplete = true
        try durableWrite(try JSONEncoder().encode(deletion), to: url)
    }

    static func deletionNeedsRestart(destinationURL: URL) -> Bool {
        let url = destinationURL.appendingPathExtension("upgrade").appendingPathComponent("deleted.json")
        guard let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode(Deletion.self, from: data) else { return false }
        return !value.cleanupComplete
    }

    private static func resolveDeletion(_ deletionURL: URL, legacyURL: URL, destinationURL: URL,
                                        defaults: UserDefaults, domainName: String,
                                        checkpoint: (LegacyUpgradeCheckpoint) throws -> Void) throws -> URL {
        let fm = FileManager.default
        let root = deletionURL.deletingLastPathComponent()
        var deletion = try JSONDecoder().decode(Deletion.self, from: Data(contentsOf: deletionURL))
        guard deletion.version == 1 else { throw PersistenceError.unsupportedLegacyRecord("deletion route version") }
        guard deletion.externalCleanupComplete else { throw ExternalDeletionPending.cleanupRequired }
        if !deletion.settingsCleared {
            let values = defaults.persistentDomain(forName: domainName) ?? [:]
            // This non-personal policy-version flag owns the running consent UI.
            // Keep it, while removing legacy account/feature choices (including old web consent).
            defaults.setPersistentDomain(values.filter {
                $0.key == "muses.privacy.acceptedVersion" || !$0.key.hasPrefix("muses.")
            }, forName: domainName)
            guard defaults.synchronize() else { throw PersistenceError.corruptRecord("settings deletion not durable") }
            deletion.settingsCleared = true
            try durableWrite(try JSONEncoder().encode(deletion), to: deletionURL)
        }
        if !deletion.cleanupComplete {
            if !deletionsInThisProcess.contains(deletion.routeID) {
                // A new process has no open Core Data handles from the old generation.
                for base in [legacyURL, destinationURL] {
                    for suffix in ["", "-wal", "-shm"] {
                        let url = URL(fileURLWithPath: base.path + suffix)
                        if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
                    }
                }
                for url in try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
                    where UUID(uuidString: url.lastPathComponent) != nil && url.lastPathComponent != deletion.routeID.uuidString {
                    try fm.removeItem(at: url)
                }
                for name in ["active.json", "pending.json"] {
                    let url = root.appendingPathComponent(name)
                    if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
                }
                try checkpoint(.deletionPurged)
                deletion.cleanupComplete = true
                try durableWrite(try JSONEncoder().encode(deletion), to: deletionURL)
            }
        }
        let target = candidate(root: root, id: deletion.routeID)
        if deletion.generationInitialized, !fm.fileExists(atPath: target.path) {
            throw PersistenceError.corruptRecord("deleted generation store is missing; no replacement created")
        }
        try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try autoreleasepool {
            let container = try SwiftDataSnapshotRepository.container(url: target)
            let repo = SwiftDataSnapshotRepository(context: ModelContext(container))
            if let existing = try repo.get(UUID.self, kind: .migration, id: "public-route-v1") {
                guard existing == deletion.routeID else { throw PersistenceError.corruptRecord("deleted route identity") }
            } else {
                guard !deletion.generationInitialized,
                      try repo.context.fetch(FetchDescriptor<MusesSchemaV1.Record>()).isEmpty else {
                    throw PersistenceError.corruptRecord("deleted route missing identity")
                }
                try repo.put(deletion.routeID, kind: .migration, id: "public-route-v1")
            }
            _ = try PublicLibrarySnapshot(repository: repo)
        }
        if !deletion.generationInitialized {
            for suffix in ["", "-wal"] {
                let url = URL(fileURLWithPath: target.path + suffix)
                if fm.fileExists(atPath: url.path) { try sync(url) }
            }
            try sync(target.deletingLastPathComponent())
            deletion.generationInitialized = true
            try durableWrite(try JSONEncoder().encode(deletion), to: deletionURL)
        }
        return target
    }

    static func resolve(legacyURL: URL, destinationURL: URL, defaults: UserDefaults, domainName: String,
                        checkpoint: @escaping (LegacyUpgradeCheckpoint) throws -> Void = { _ in }) throws -> URL {
        let fm = FileManager.default
        let root = destinationURL.appendingPathExtension("upgrade")
        let deletedURL = root.appendingPathComponent("deleted.json")
        if fm.fileExists(atPath: deletedURL.path) {
            return try resolveDeletion(deletedURL, legacyURL: legacyURL, destinationURL: destinationURL,
                defaults: defaults, domainName: domainName, checkpoint: checkpoint)
        }
        let activeURL = root.appendingPathComponent("active.json")
        let pendingURL = root.appendingPathComponent("pending.json")
        if fm.fileExists(atPath: activeURL.path) {
            let active = try JSONDecoder().decode(Activation.self, from: Data(contentsOf: activeURL))
            guard active.version == 1 else { throw PersistenceError.unsupportedLegacyRecord("active route version") }
            let target = candidate(root: root, id: active.routeID)
            guard try fingerprint(legacyURL) == active.sourceDigest else {
                throw PersistenceError.unsupportedLegacyRecord("original library changed after activation; preserve both libraries for recovery")
            }
            try verify(target: target, id: active.routeID, archiveDigest: active.archiveDigest)
            return target
        }
        let hasPending = fm.fileExists(atPath: pendingURL.path)
        guard artifactsPresent(legacyURL) || hasPending else {
            if !fm.fileExists(atPath: destinationURL.path), artifactsPresent(destinationURL) {
                throw PersistenceError.corruptRecord("orphan public store sidecar")
            }
            try fm.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            return destinationURL
        }
        guard fm.fileExists(atPath: legacyURL.path) else { throw LegacySnapshotError.sourceMissing }
        // An un-routed public library could contain edits. Never overwrite or merge implicitly.
        guard !artifactsPresent(destinationURL) else {
            throw PersistenceError.unsupportedLegacyRecord("both legacy and un-routed public libraries exist")
        }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        if hasPending {
            let id = try JSONDecoder().decode(UUID.self, from: Data(contentsOf: pendingURL))
            let preparedURL = attempt(root: root, id: id).appendingPathComponent("prepared.json")
            if fm.fileExists(atPath: preparedURL.path) {
                let prepared = try JSONDecoder().decode(LegacyMigrationPreparation.Prepared.self, from: Data(contentsOf: preparedURL))
                return try activate(prepared, root: root, legacyURL: legacyURL, checkpoint: checkpoint)
            }
            // Incomplete attempt is evidence, not authoritative state. Leave it intact and
            // retry from a fresh snapshot, including any source changes made after a rollback.
        }
        let id = UUID()
        try durableWrite(try JSONEncoder().encode(id), to: pendingURL)
        let prepared = try LegacyMigrationPreparation.prepare(sourceURL: legacyURL,
            attemptDirectory: attempt(root: root, id: id), defaults: defaults, domainName: domainName,
            routeID: id, checkpoint: checkpoint)
        return try activate(prepared, root: root, legacyURL: legacyURL, checkpoint: checkpoint)
    }

    private static func activate(_ prepared: LegacyMigrationPreparation.Prepared, root: URL, legacyURL: URL,
                                 checkpoint: (LegacyUpgradeCheckpoint) throws -> Void) throws -> URL {
        let target = candidate(root: root, id: prepared.routeID)
        guard prepared.version == 1, prepared.storeURL.standardizedFileURL == target.standardizedFileURL,
              try fingerprint(legacyURL) == prepared.sourceDigest else {
            throw PersistenceError.unsupportedLegacyRecord("prepared source or target changed")
        }
        try verify(target: target, id: prepared.routeID, archiveDigest: prepared.archiveDigest)
        for suffix in ["", "-wal"] {
            let file = URL(fileURLWithPath: target.path + suffix)
            if FileManager.default.fileExists(atPath: file.path) { try sync(file) }
        }
        try sync(target.deletingLastPathComponent())
        // Atomic pointer publication: SQLite files never move while Core Data owns them.
        let active = Activation(routeID: prepared.routeID, sourceDigest: prepared.sourceDigest, archiveDigest: prepared.archiveDigest)
        try durableWrite(try JSONEncoder().encode(active), to: root.appendingPathComponent("active.json"))
        try checkpoint(.activated)
        return target
    }

    static func verify(target: URL, id: UUID, archiveDigest: String) throws {
        guard FileManager.default.fileExists(atPath: target.path) else { throw LegacySnapshotError.sourceMissing }
        try autoreleasepool {
            let container = try ModelContainer(for: MusesSchemaV1.Record.self, migrationPlan: MusesMigrationPlan.self,
                configurations: ModelConfiguration(url: target, allowsSave: false, cloudKitDatabase: .none))
            let repo = SwiftDataSnapshotRepository(context: ModelContext(container))
            guard try repo.get(UUID.self, kind: .migration, id: "public-route-v1") == id,
                  try repo.legacyArchiveDigest() == archiveDigest else {
                throw PersistenceError.corruptRecord("active route identity/archive")
            }
            _ = try PublicLibrarySnapshot(repository: repo)
            _ = try repo.legacyArchive()
        }
    }

    static func fingerprint(_ source: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: source.path) else { throw LegacySnapshotError.sourceMissing }
        var hash = SHA256()
        for suffix in ["", "-wal"] {
            hash.update(data: Data(suffix.utf8))
            let url = URL(fileURLWithPath: source.path + suffix)
            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty { hash.update(data: data) }
            }
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func durableWrite(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        try sync(url)
        try sync(url.deletingLastPathComponent())
    }
    private static func sync(_ url: URL) throws {
        let fd = open(url.path, O_RDONLY)
        guard fd >= 0 else { throw PersistenceError.corruptRecord("sync open \(url.lastPathComponent)") }
        defer { close(fd) }
        guard fsync(fd) == 0 else { throw PersistenceError.corruptRecord("sync \(url.lastPathComponent)") }
    }
    private static func artifactsPresent(_ url: URL) -> Bool {
        ["", "-wal", "-shm"].contains { FileManager.default.fileExists(atPath: url.path + $0) }
    }
    private static func attempt(root: URL, id: UUID) -> URL { root.appendingPathComponent(id.uuidString) }
    private static func candidate(root: URL, id: UUID) -> URL { attempt(root: root, id: id).appendingPathComponent("muses-public-v1.sqlite") }
}
