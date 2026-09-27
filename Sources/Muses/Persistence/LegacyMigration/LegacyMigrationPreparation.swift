import Foundation
import SwiftData
import MusesPersistence

/// Controlled transition stage: prepare and verify a separate V1 store, but do not
/// change the public startup route or replace any original store/sidecar/default.
/// The caller owns a fresh attempt directory and keeps it for diagnosis on failure.
@MainActor
enum LegacyMigrationPreparation {
    struct Prepared: Codable {
        let storeURL: URL
        let sourceSnapshotURL: URL
        let receipt: LegacyMigrationReceipt
    }

    static func prepare(sourceURL: URL, attemptDirectory: URL,
                        defaults: UserDefaults, domainName: String) throws -> Prepared {
        guard !FileManager.default.fileExists(atPath: attemptDirectory.path) else {
            throw LegacySnapshotError.destinationExists
        }
        try FileManager.default.createDirectory(at: attemptDirectory, withIntermediateDirectories: true)
        let snapshot = attemptDirectory.appendingPathComponent("legacy.snapshot.sqlite")
        let capture = try LegacyStoreReader.read(sourceURL: sourceURL, snapshotURL: snapshot,
                                                defaults: defaults, domainName: domainName)
        let target = attemptDirectory.appendingPathComponent("muses-public-v1.sqlite")
        try autoreleasepool {
            let container = try SwiftDataSnapshotRepository.container(url: target)
            let context = ModelContext(container)
            context.autosaveEnabled = false
            try SwiftDataSnapshotRepository(context: context).importLegacyComplete(capture.bundle)
        }
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
            return receipt
        }
        let prepared = Prepared(storeURL: target, sourceSnapshotURL: snapshot, receipt: receipt)
        // Written last; absence means interrupted/unverified. This is evidence only,
        // never sufficient authorization for PublicYouTubeApp to switch stores.
        try JSONEncoder().encode(prepared).write(to: attemptDirectory.appendingPathComponent("prepared.json"), options: .atomic)
        return prepared
    }
}
