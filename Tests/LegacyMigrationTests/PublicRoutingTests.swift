import XCTest
import Foundation
import SwiftData
import MusesPersistence
import MusesDomain
@testable import Muses

@MainActor
final class PublicRoutingTests: XCTestCase {
    private func root() throws -> URL {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("route-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return path
    }
    func testLifecycleStagesPhysicalArchiveWithoutChangingOriginalOrReceipt() throws {
        let directory = try root()
        let fixture = try PhysicalLegacyFixture(url: directory.appendingPathComponent("old.sqlite"))
        defer { fixture.closePinAndSettings() }
        let original = try PublicStoreRouter.fingerprint(fixture.url)
        let destination = directory.appendingPathComponent("new.sqlite")
        let target = try PublicStoreRouter.resolve(legacyURL: fixture.url, destinationURL: destination,
            defaults: fixture.defaults, domainName: fixture.domain)
        let repo = SwiftDataSnapshotRepository(context: ModelContext(try SwiftDataSnapshotRepository.container(url: target)))
        let archive = try repo.legacyArchive()
        let digest = try repo.legacyArchiveDigest()
        let fields = try ArchiveLifecycle.inventory(archive)
        XCTAssertTrue(fields.contains { $0.address.hasSuffix("/itemsJSON") })
        XCTAssertTrue(fields.contains { $0.address.contains("/syncBatch/") && $0.address.hasSuffix("/desiredSnapshotData") })
        let note = try XCTUnwrap(fields.first { $0.address.contains("/trackNote/") && $0.address.hasSuffix("/content") })
        let evidence = ArchiveEvidence(field: note, origin: .userInput, reference: "synthetic fixture explicit user content")
        let successor = try ArchiveLifecycle.successor(fields: fields, evidence: [evidence],
            originalReceipt: archive.receipt, parentArchiveDigest: digest,
            now: Date(timeIntervalSince1970: 2_000_000_000), maximumAPIAge: 29 * 86_400)
        XCTAssertEqual(successor.userFields, [note])
        XCTAssertTrue(successor.hasUnresolvedFields)
        try repo.stageArchiveSuccessor(successor)
        XCTAssertThrowsError(try repo.restoreOriginalPlaylist(fixture.playlistID))
        XCTAssertEqual(try PublicStoreRouter.resolve(legacyURL: fixture.url, destinationURL: destination,
            defaults: fixture.defaults, domainName: fixture.domain), target)
        XCTAssertEqual(try repo.legacyArchive().receipt, archive.receipt)
        XCTAssertEqual(try repo.legacyArchiveDigest(), digest)
        XCTAssertEqual(try PublicStoreRouter.fingerprint(fixture.url), original)
    }

    func testNewUserAndIncompleteLegacyFailClosed() throws {
        let directory = try root()
        let source = directory.appendingPathComponent("old.sqlite")
        let destination = directory.appendingPathComponent("new.sqlite")
        XCTAssertEqual(try PublicStoreRouter.resolve(legacyURL: source, destinationURL: destination,
            defaults: .standard, domainName: "muses.test.routing"), destination)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        try Data("orphan".utf8).write(to: URL(fileURLWithPath: source.path + "-wal"))
        XCTAssertThrowsError(try PublicStoreRouter.resolve(legacyURL: source, destinationURL: destination,
            defaults: .standard, domainName: "muses.test.routing"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testProjectionOccurrencesEditsAndArchiveRecoverySurviveRestart() throws {
        let directory = try root()
        let fixture = try PhysicalLegacyFixture(url: directory.appendingPathComponent("old.sqlite"))
        defer { fixture.closePinAndSettings() }
        let originalSHM = try Data(contentsOf: URL(fileURLWithPath: fixture.url.path + "-shm"))
        let digest = try PublicStoreRouter.fingerprint(fixture.url)
        let destination = directory.appendingPathComponent("new.sqlite")
        let target = try PublicStoreRouter.resolve(legacyURL: fixture.url, destinationURL: destination,
            defaults: fixture.defaults, domainName: fixture.domain)
        let repo = SwiftDataSnapshotRepository(context: ModelContext(try SwiftDataSnapshotRepository.container(url: target)))
        let library = try PublicLibrarySnapshot(repository: repo)
        XCTAssertEqual(library.history.first?.trackID.rawValue, fixture.trackID.uuidString)
        XCTAssertEqual(library.playlists.first?.occurrences?.count, 2)
        XCTAssertEqual(library.playlists.first?.trackIDs.count, 1)
        XCTAssertEqual(library.playlists.first?.playbackTrackIDs.count, 2)
        XCTAssertEqual(Set(library.playlists.first?.occurrences?.map(\.id) ?? []), Set(fixture.expected["PlaylistItem", default: []].map(\.id)))
        XCTAssertEqual(try repo.legacyArchive().models.keys.count, 15)
        XCTAssertEqual(try repo.list(LegacyNote.self, kind: .note).count, 1)
        XCTAssertEqual(try repo.list(LegacyBookmark.self, kind: .bookmark).count, 1)
        var edited = try XCTUnwrap(library.tracks.first)
        edited.title = "A public user edit"
        try repo.saveTrack(edited)
        let selected = try PublicStoreRouter.resolve(legacyURL: fixture.url, destinationURL: destination,
            defaults: fixture.defaults, domainName: fixture.domain)
        XCTAssertEqual(selected, target)
        XCTAssertEqual(try repo.track(id: edited.id)?.title, edited.title)
        let restored = try repo.restoreOriginalPlaylist(fixture.playlistID)
        XCTAssertNotEqual(restored.id, fixture.playlistID)
        XCTAssertEqual(restored.playbackTrackIDs.count, 2)
        XCTAssertEqual(try PublicStoreRouter.fingerprint(fixture.url), digest)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: fixture.url.path + "-shm")), originalSHM)
        // Corrupt archives do not authorize replacement or fallback to old data.
        let record = try XCTUnwrap(repo.context.fetch(FetchDescriptor<MusesSchemaV1.Record>()).first { $0.kindRaw == "legacyTrack" })
        record.payload = Data("broken".utf8)
        try repo.context.save()
        XCTAssertThrowsError(try PublicStoreRouter.resolve(legacyURL: fixture.url, destinationURL: destination,
            defaults: fixture.defaults, domainName: fixture.domain))
    }

    func testThrownCheckpointsResumeAndNeverTouchSource() throws {
        enum Interrupted: Error { case stop }
        for phase in [LegacyUpgradeCheckpoint.snapshot, .beforeLegacyCommit, .legacyCommitted, .projected, .prepared, .activated] {
            let directory = try root()
            let fixture = try PhysicalLegacyFixture(url: directory.appendingPathComponent("old.sqlite"))
            defer { fixture.closePinAndSettings() }
            let before = try PublicStoreRouter.fingerprint(fixture.url)
            let destination = directory.appendingPathComponent("new.sqlite")
            XCTAssertThrowsError(try PublicStoreRouter.resolve(legacyURL: fixture.url, destinationURL: destination,
                defaults: fixture.defaults, domainName: fixture.domain) { if $0 == phase { throw Interrupted.stop } })
            let selected = try PublicStoreRouter.resolve(legacyURL: fixture.url, destinationURL: destination,
                defaults: fixture.defaults, domainName: fixture.domain)
            let repo = SwiftDataSnapshotRepository(context: ModelContext(try SwiftDataSnapshotRepository.container(url: selected)))
            XCTAssertEqual(try PublicLibrarySnapshot(repository: repo).playlists.first?.playbackTrackIDs.count, 2)
            XCTAssertEqual(try PublicStoreRouter.fingerprint(fixture.url), before)
        }
    }

    func testDeletedWorkingLibraryNeverReimportsInSameProcess() throws {
        let directory = try root()
        let fixture = try PhysicalLegacyFixture(url: directory.appendingPathComponent("old.sqlite"))
        defer { fixture.closePinAndSettings() }
        let destination = directory.appendingPathComponent("new.sqlite")
        let initial = try PublicStoreRouter.resolve(legacyURL: fixture.url, destinationURL: destination,
            defaults: fixture.defaults, domainName: fixture.domain)
        var preferences = fixture.defaults.persistentDomain(forName: fixture.domain) ?? [:]
        preferences["muses.privacy.acceptedVersion"] = 1
        fixture.defaults.setPersistentDomain(preferences, forName: fixture.domain)
        let fresh = try PublicStoreRouter.requestDeletion(legacyURL: fixture.url, destinationURL: destination,
            defaults: fixture.defaults, domainName: fixture.domain)
        XCTAssertNotEqual(initial, fresh)
        XCTAssertTrue(PublicStoreRouter.deletionNeedsRestart(destinationURL: destination))
        let retained = fixture.defaults.persistentDomain(forName: fixture.domain) ?? [:]
        XCTAssertEqual(retained["muses.privacy.acceptedVersion"] as? Int, 1)
        XCTAssertFalse(retained.keys.contains { $0.hasPrefix("muses.") && $0 != "muses.privacy.acceptedVersion" })
        var newPreferences = retained
        newPreferences["muses.newPreferenceAfterDeletion"] = true
        fixture.defaults.setPersistentDomain(newPreferences, forName: fixture.domain)
        let restarted = try PublicStoreRouter.resolve(legacyURL: fixture.url, destinationURL: destination,
            defaults: fixture.defaults, domainName: fixture.domain)
        let repo = SwiftDataSnapshotRepository(context: ModelContext(try SwiftDataSnapshotRepository.container(url: restarted)))
        XCTAssertTrue(try PublicLibrarySnapshot(repository: repo).tracks.isEmpty)
        XCTAssertTrue(try repo.legacyArchive().tracks.isEmpty)
        XCTAssertEqual(fixture.defaults.persistentDomain(forName: fixture.domain)?["muses.newPreferenceAfterDeletion"] as? Bool, true)
    }

    func testUnknownRouteVersionDoesNotOpenOrReplaceCandidate() throws {
        let directory = try root()
        let fixture = try PhysicalLegacyFixture(url: directory.appendingPathComponent("old.sqlite"))
        defer { fixture.closePinAndSettings() }
        let destination = directory.appendingPathComponent("new.sqlite")
        _ = try PublicStoreRouter.resolve(legacyURL: fixture.url, destinationURL: destination,
            defaults: fixture.defaults, domainName: fixture.domain)
        let marker = destination.appendingPathExtension("upgrade").appendingPathComponent("active.json")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: marker)) as? [String: Any])
        object["version"] = 99
        let bytes = try JSONSerialization.data(withJSONObject: object, options: .sortedKeys)
        try bytes.write(to: marker)
        XCTAssertThrowsError(try PublicStoreRouter.resolve(legacyURL: fixture.url, destinationURL: destination,
            defaults: fixture.defaults, domainName: fixture.domain))
        XCTAssertEqual(try Data(contentsOf: marker), bytes)
    }
}
