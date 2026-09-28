import Foundation
import SwiftData
import MusesPersistence

/// Prepare and verify a separate V1 store. PublicStoreRouter publishes its route
/// only after this phase succeeds. Originals and defaults are never replaced.
/// The caller owns a fresh attempt directory and keeps it for diagnosis on failure.
@MainActor
enum LegacyMigrationPreparation {
    struct Prepared: Codable {
        var version: Int = 1
        let storeURL: URL
        let sourceSnapshotURL: URL
        let receipt: LegacyMigrationReceipt
        let routeID: UUID
        let sourceDigest: String
        let archiveDigest: String
    }

    static func prepare(sourceURL: URL, attemptDirectory: URL,
                        defaults: UserDefaults, domainName: String, routeID: UUID = UUID(),
                        checkpoint: @escaping (LegacyUpgradeCheckpoint) throws -> Void = { _ in }) throws -> Prepared {
        guard !FileManager.default.fileExists(atPath: attemptDirectory.path) else {
            throw LegacySnapshotError.destinationExists
        }
        try FileManager.default.createDirectory(at: attemptDirectory, withIntermediateDirectories: true)
        let sourceDigest = try PublicStoreRouter.fingerprint(sourceURL)
        let snapshot = attemptDirectory.appendingPathComponent("legacy.snapshot.sqlite")
        let capture = try LegacyStoreReader.read(sourceURL: sourceURL, snapshotURL: snapshot,
                                                defaults: defaults, domainName: domainName)
        try checkpoint(.snapshot)
        let target = attemptDirectory.appendingPathComponent("muses-public-v1.sqlite")
        try autoreleasepool {
            let container = try SwiftDataSnapshotRepository.container(url: target)
            let context = ModelContext(container)
            context.autosaveEnabled = false
            try SwiftDataSnapshotRepository(context: context).importLegacyComplete(capture.bundle) {
                try checkpoint(.beforeLegacyCommit)
            }
        }
        try checkpoint(.legacyCommitted)
        let receipt: LegacyMigrationReceipt = try autoreleasepool {
            let container = try SwiftDataSnapshotRepository.container(url: target)
            let context = ModelContext(container)
            context.autosaveEnabled = false
            let repo = SwiftDataSnapshotRepository(context: context)
            // The retry validator compares every persisted record, not just a marker.
            try repo.importLegacyComplete(capture.bundle)
            guard let receipt = try repo.get(LegacyMigrationReceipt.self, kind: .migration, id: "legacy-complete-v1") else {
                throw PersistenceError.corruptRecord("missing verified receipt")
            }
            try repo.projectLegacyForPublic(routeID: routeID)
            return receipt
        }
        try checkpoint(.projected)
        let archiveDigest: String = try autoreleasepool {
            let container = try SwiftDataSnapshotRepository.container(url: target)
            return try SwiftDataSnapshotRepository(context: ModelContext(container)).legacyArchiveDigest()
        }
        try PublicStoreRouter.verify(target: target, id: routeID, archiveDigest: archiveDigest)
        guard try PublicStoreRouter.fingerprint(sourceURL) == sourceDigest else {
            throw PersistenceError.unsupportedLegacyRecord("source changed during preparation")
        }
        let prepared = Prepared(storeURL: target, sourceSnapshotURL: snapshot, receipt: receipt,
                                routeID: routeID, sourceDigest: sourceDigest, archiveDigest: archiveDigest)
        try PublicStoreRouter.durableWrite(try JSONEncoder().encode(prepared),
            to: attemptDirectory.appendingPathComponent("prepared.json"))
        try checkpoint(.prepared)
        return prepared
    }
}
