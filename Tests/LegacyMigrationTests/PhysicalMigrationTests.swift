import XCTest
import Foundation
import SwiftData
import SQLite3
import CryptoKit
import MusesPersistence
@testable import Muses

@MainActor
final class PhysicalMigrationTests: XCTestCase {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("legacy-proof-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func assertManifest(_ actual: [String: [LegacyModelArchive]],
                                _ expected: [String: [LegacyModelArchive]], file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(Set(actual.keys), Set(expected.keys), file: file, line: line)
        for (model, rows) in expected {
            let read = actual[model, default: []]
            XCTAssertEqual(Set(read.map(\.id)), Set(rows.map(\.id)), model, file: file, line: line)
            for row in rows {
                let found = try XCTUnwrap(read.first { $0.id == row.id }, model, file: file, line: line)
                XCTAssertEqual(found.fieldNames, row.fieldNames, model, file: file, line: line)
                XCTAssertEqual(try JSONSerialization.jsonObject(with: found.fields) as? NSDictionary,
                               try JSONSerialization.jsonObject(with: row.fields) as? NSDictionary,
                               model, file: file, line: line)
            }
        }
    }

    func testOriginalPhysicalWALToReadOnlySnapshotToV1AndRollback() throws {
        let root = try directory()
        // Core Data closes SQLite handles asynchronously; let the OS clean this temporary directory.
        let source = root.appendingPathComponent("original.store")
        let fixture = try PhysicalLegacyFixture(url: source)
        defer { fixture.closePinAndSettings() }
        let before = try Data(contentsOf: source)
        let walURL = URL(fileURLWithPath: source.path + "-wal")
        let wal = try Data(contentsOf: walURL)
        XCTAssertGreaterThan(wal.count, 32, "must contain committed WAL pages")
        // The pinned connection sees the pre-write snapshot. All Track rows are in WAL.
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(fixture.pin, "SELECT count(*) FROM ZTRACK", -1, &statement, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        XCTAssertEqual(sqlite3_column_int(statement, 0), 0)
        sqlite3_finalize(statement)

        let capture = try LegacyStoreReader.read(sourceURL: source, snapshotURL: root.appendingPathComponent("copy.store"),
                                                 defaults: fixture.defaults, domainName: fixture.domain)
        XCTAssertEqual(capture.manifest.count, 19)
        try assertManifest(capture.manifest, fixture.expected)
        XCTAssertEqual(capture.bundle.userTruth.settings.count, fixture.explicitSettings.count)
        for setting in capture.bundle.userTruth.settings {
            let envelope = try XCTUnwrap(try PropertyListSerialization.propertyList(from: setting.value, format: nil) as? NSDictionary)
            XCTAssertEqual(envelope, ["value": try XCTUnwrap(fixture.explicitSettings[setting.key])] as NSDictionary)
        }
        XCTAssertEqual(try Data(contentsOf: source), before)
        XCTAssertEqual(try Data(contentsOf: walURL), wal)

        let target = root.appendingPathComponent("v1.store")
        try autoreleasepool {
            let container = try SwiftDataSnapshotRepository.container(url: target)
            let repo = SwiftDataSnapshotRepository(context: ModelContext(container))
            var invalid = capture.bundle
            invalid.inspectedModels.remove("Track")
            XCTAssertThrowsError(try repo.importLegacyComplete(invalid))
            XCTAssertTrue(try repo.context.fetch(FetchDescriptor<MusesSchemaV1.Record>()).isEmpty)
        }
        // Failure leaves the source reopenable by the inherited schema.
        try verifyOriginal(source, fixture: fixture)
        try autoreleasepool {
            let container = try SwiftDataSnapshotRepository.container(url: target)
            let repo = SwiftDataSnapshotRepository(context: ModelContext(container))
            try repo.importLegacyComplete(capture.bundle)
        }
        try autoreleasepool {
            let container = try SwiftDataSnapshotRepository.container(url: target)
            let repo = SwiftDataSnapshotRepository(context: ModelContext(container))
            let recaptured = try LegacyStoreReader.read(sourceURL: source,
                snapshotURL: root.appendingPathComponent("retry-copy.store"), defaults: fixture.defaults, domainName: fixture.domain)
            try repo.importLegacyComplete(recaptured.bundle) // fresh Sets and fetch order after reopening
            let receipt = try XCTUnwrap(repo.get(LegacyMigrationReceipt.self, kind: .migration, id: "legacy-complete-v1"))
            XCTAssertEqual(receipt.payloadSHA256.count, 64)
            XCTAssertEqual(try repo.context.fetch(FetchDescriptor<MusesSchemaV1.Record>()).count, receipt.recordCount + 1)
            let archived = try repo.list(LegacyModelArchive.self, kind: .legacyModel)
            XCTAssertEqual(archived.count, capture.bundle.otherModels.values.flatMap { $0 }.count)
            for row in capture.bundle.otherModels.values.flatMap({ $0 }) {
                let found = try XCTUnwrap(archived.first { $0.id == row.id })
                XCTAssertEqual(found.fields, row.fields)
                XCTAssertEqual(found.fieldNames, row.fieldNames)
            }
            let tracks = try repo.list(LegacyTrackArchive.self, kind: .legacyTrack)
            XCTAssertEqual(tracks.count, capture.bundle.tracks.count)
            XCTAssertEqual(tracks.first?.lyricsOffsetMs, capture.bundle.tracks.first?.lyricsOffsetMs)
            let queue = try XCTUnwrap(repo.list(LegacyQueueArchive.self, kind: .legacyQueue).first)
            XCTAssertEqual(queue.itemsJSON, capture.bundle.queue?.itemsJSON)
            XCTAssertEqual(queue.upNextJSON, capture.bundle.queue?.upNextJSON)
            XCTAssertEqual(queue.historyJSON, capture.bundle.queue?.historyJSON)
            XCTAssertEqual(queue.groupsJSON, capture.bundle.queue?.groupsJSON)
            XCTAssertEqual(try repo.queue()?.intent.rawValue, "pause")
            // Corrupt target is rejected, never silently repaired on retry.
            let row = try XCTUnwrap(repo.context.fetch(FetchDescriptor<MusesSchemaV1.Record>()).first)
            row.payload = Data("corrupt".utf8)
            try repo.context.save()
            XCTAssertThrowsError(try repo.importLegacyComplete(capture.bundle))
        }
        try verifyOriginal(source, fixture: fixture)
        XCTAssertEqual(try Data(contentsOf: source), before)
        XCTAssertEqual(try Data(contentsOf: walURL), wal)
        // Preserve a reviewable physical fixture when explicitly requested by CI/developer.
        if let artifactPath = ProcessInfo.processInfo.environment["MUSES_LEGACY_PROOF_OUTPUT"] {
            let output = URL(fileURLWithPath: artifactPath)
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            for suffix in ["", "-wal", "-shm"] {
                try FileManager.default.copyItem(atPath: source.path + suffix, toPath: output.appendingPathComponent("original.store").path + suffix)
            }
            try JSONEncoder().encode(fixture.expected).write(to: output.appendingPathComponent("manifest.json"))
            try PropertyListSerialization.data(fromPropertyList: fixture.explicitSettings, format: .binary, options: 0)
                .write(to: output.appendingPathComponent("settings.plist.bin"))
        }
    }

    func testControlledPreparationAndReadOnlyTargetSaveFailure() throws {
        let root = try directory()
        // Core Data closes SQLite handles asynchronously; let the OS clean this temporary directory.
        let fixture = try PhysicalLegacyFixture(url: root.appendingPathComponent("original.store"))
        defer { fixture.closePinAndSettings() }
        let target = root.appendingPathComponent("cannot-save.store")
        try autoreleasepool { _ = try SwiftDataSnapshotRepository.container(url: target) }
        let capture = try LegacyStoreReader.read(sourceURL: fixture.url, snapshotURL: root.appendingPathComponent("snapshot.store"),
                                                defaults: fixture.defaults, domainName: fixture.domain)
        try autoreleasepool {
            let container = try ModelContainer(for: MusesSchemaV1.Record.self, migrationPlan: MusesMigrationPlan.self,
                configurations: ModelConfiguration(url: target, allowsSave: false))
            let context = ModelContext(container)
            context.autosaveEnabled = false
            let repo = SwiftDataSnapshotRepository(context: context)
            XCTAssertThrowsError(try repo.importLegacyComplete(capture.bundle))
        }
        try autoreleasepool {
            let container = try SwiftDataSnapshotRepository.container(url: target)
            let repo = SwiftDataSnapshotRepository(context: ModelContext(container))
            XCTAssertTrue(try repo.context.fetch(FetchDescriptor<MusesSchemaV1.Record>()).isEmpty)
            try repo.importLegacyComplete(capture.bundle)
        }
        let attempt = root.appendingPathComponent("attempt")
        let result = try LegacyMigrationPreparation.prepare(sourceURL: fixture.url, attemptDirectory: attempt,
            defaults: fixture.defaults, domainName: fixture.domain)
        let marker = try JSONDecoder().decode(LegacyMigrationPreparation.Prepared.self,
            from: Data(contentsOf: attempt.appendingPathComponent("prepared.json")))
        XCTAssertEqual(marker.receipt, result.receipt)
        XCTAssertThrowsError(try LegacyMigrationPreparation.prepare(sourceURL: fixture.url, attemptDirectory: attempt,
            defaults: fixture.defaults, domainName: fixture.domain))
        try verifyOriginal(fixture.url, fixture: fixture)
    }

    func testNullFieldsAndMalformedQueueFailClosed() throws {
        let root = try directory()
        let fixture = try PhysicalLegacyFixture(url: root.appendingPathComponent("original.store"))
        defer { fixture.closePinAndSettings() }
        let context = ModelContext(fixture.container)
        context.autosaveEnabled = false
        let track = try XCTUnwrap(context.fetch(FetchDescriptor<Track>()).first)
        track.mediaKindRaw = nil
        track.lyrics = nil
        track.lyricsOffsetMs = nil
        track.lastPlayedAt = nil
        let bookmark = try XCTUnwrap(context.fetch(FetchDescriptor<TrackBookmark>()).first)
        bookmark.note = nil
        bookmark.title = nil
        let item = try XCTUnwrap(context.fetch(FetchDescriptor<PlaylistItem>()).first)
        item.track = nil
        try context.save()
        let capture = try LegacyStoreReader.read(sourceURL: fixture.url, snapshotURL: root.appendingPathComponent("nullable.store"),
            defaults: fixture.defaults, domainName: fixture.domain)
        XCTAssertNil(capture.bundle.tracks.first?.mediaKindRaw)
        let archivedTrack = try XCTUnwrap(capture.manifest["Track"]?.first)
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: archivedTrack.fields) as? [String: Any])
        for key in ["mediaKindRaw", "lyrics", "lyricsOffsetMs", "lastPlayedAt"] { XCTAssertTrue(fields[key] is NSNull) }
        let archivedBookmark = try XCTUnwrap(capture.bundle.otherModels[.trackBookmark]?.first)
        let bookmarkFields = try XCTUnwrap(JSONSerialization.jsonObject(with: archivedBookmark.fields) as? [String: Any])
        XCTAssertTrue(bookmarkFields["note"] is NSNull)
        XCTAssertTrue(bookmarkFields["title"] is NSNull)
        let queue = try XCTUnwrap(context.fetch(FetchDescriptor<QueueState>()).first)
        queue.groupsJSON = "[{\"broken\":true}]"
        try context.save()
        let attempt = root.appendingPathComponent("rejected-attempt")
        XCTAssertThrowsError(try LegacyMigrationPreparation.prepare(sourceURL: fixture.url,
            attemptDirectory: attempt, defaults: fixture.defaults, domainName: fixture.domain))
        XCTAssertFalse(FileManager.default.fileExists(atPath: attempt.appendingPathComponent("prepared.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: attempt.appendingPathComponent("muses-public-v1.sqlite").path))
    }

    func testCommittedPhysicalFixtureOnThisRuntime() throws {
        #if SWIFT_PACKAGE
        let committed = try XCTUnwrap(Bundle.module.resourceURL).appendingPathComponent("Fixtures")
        #else
        let committed = try XCTUnwrap(Bundle(for: Self.self).resourceURL)
        #endif
        struct Provenance: Decodable {
            let fixtureSHA256: [String: String]
            let modelSourceSHA256: [String: String]
        }
        let provenance = try JSONDecoder().decode(Provenance.self,
            from: Data(contentsOf: committed.appendingPathComponent("provenance.json")))
        func checksum(_ url: URL) throws -> String {
            SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
        }
        for (name, expectedHash) in provenance.fixtureSHA256 {
            XCTAssertEqual(try checksum(committed.appendingPathComponent(name)), expectedHash, name)
        }
        #if os(macOS)
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        for (name, expectedHash) in provenance.modelSourceSHA256 {
            XCTAssertEqual(try checksum(repository.appendingPathComponent(name)), expectedHash, name)
        }
        #endif
        let root = try directory()
        let source = root.appendingPathComponent("original.store")
        for suffix in ["", "-wal", "-shm"] {
            try FileManager.default.copyItem(at: committed.appendingPathComponent("original.store" + suffix),
                                            to: URL(fileURLWithPath: source.path + suffix))
        }
        let domain = "muses.committed-proof." + UUID().uuidString
        let settings = try XCTUnwrap(PropertyListSerialization.propertyList(
            from: Data(contentsOf: committed.appendingPathComponent("settings.plist.bin")), format: nil) as? [String: Any])
        UserDefaults.standard.setPersistentDomain(settings, forName: domain)
        defer { UserDefaults.standard.removePersistentDomain(forName: domain) }
        let expected = try JSONDecoder().decode([String: [LegacyModelArchive]].self,
            from: Data(contentsOf: committed.appendingPathComponent("manifest.json")))
        let capture = try LegacyStoreReader.read(sourceURL: source, snapshotURL: root.appendingPathComponent("copy.store"),
            defaults: .standard, domainName: domain)
        try assertManifest(capture.manifest, expected)
        let prepared = try LegacyMigrationPreparation.prepare(sourceURL: source,
            attemptDirectory: root.appendingPathComponent("verified"), defaults: .standard, domainName: domain)
        XCTAssertGreaterThan(prepared.receipt.recordCount, 30)
    }

    private func verifyOriginal(_ source: URL, fixture: PhysicalLegacyFixture) throws {
        try autoreleasepool {
            // Actual original MusesSchema.current, without a migration plan, just as the previous app.
            let container = try ModelContainer(for: MusesSchema.current,
                configurations: [ModelConfiguration(schema: MusesSchema.current, url: source,
                                                      allowsSave: false, cloudKitDatabase: .none)])
            let context = ModelContext(container)
            let tracks = try context.fetch(FetchDescriptor<Track>())
            XCTAssertEqual(tracks.count, 1)
            XCTAssertEqual(tracks.first?.id, fixture.trackID)
            XCTAssertEqual(tracks.first?.youTubeImportItems?.count, 2)
            XCTAssertEqual(try context.fetch(FetchDescriptor<PlaylistItem>()).count, 2)
        }
    }

    func testOccupiedTargetAndInvalidSnapshotNeverDestroySource() throws {
        let root = try directory()
        // Core Data closes SQLite handles asynchronously; let the OS clean this temporary directory.
        let fixture = try PhysicalLegacyFixture(url: root.appendingPathComponent("original.store"))
        defer { fixture.closePinAndSettings() }
        let copy = root.appendingPathComponent("copy.store")
        let capture = try LegacyStoreReader.read(sourceURL: fixture.url, snapshotURL: copy,
                                                defaults: fixture.defaults, domainName: fixture.domain)
        XCTAssertThrowsError(try LegacyStoreReader.read(sourceURL: fixture.url, snapshotURL: copy,
                                                        defaults: fixture.defaults, domainName: fixture.domain))
        let container = try SwiftDataSnapshotRepository.container(url: root.appendingPathComponent("occupied.store"))
        let repo = SwiftDataSnapshotRepository(context: ModelContext(container))
        try repo.put("existing user edit", kind: .setting, id: "user")
        XCTAssertThrowsError(try repo.importLegacyComplete(capture.bundle))
        XCTAssertEqual(try repo.get(String.self, kind: .setting, id: "user"), "existing user edit")
        try verifyOriginal(fixture.url, fixture: fixture)
    }
}
