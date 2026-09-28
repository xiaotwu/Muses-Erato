import XCTest
import Foundation
import SwiftData
import MusesPersistence
import MusesDomain
@testable import Muses

@MainActor final class RunnableSuccessorTests: XCTestCase {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("successor-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func repository(_ url: URL) throws -> SwiftDataSnapshotRepository {
        SwiftDataSnapshotRepository(context: ModelContext(try SwiftDataSnapshotRepository.container(url: url)))
    }
    func testRunnableCandidateKeepsEditsRelationshipsAndRejectsEveryAppRestorePath() throws {
        let root = try directory()
        let fixture = try PhysicalLegacyFixture(url: root.appendingPathComponent("old.sqlite"))
        defer { fixture.closePinAndSettings() }
        let sourceHash = try PublicStoreRouter.fingerprint(fixture.url)
        let destination = root.appendingPathComponent("new.sqlite")
        let parentURL = try PublicStoreRouter.resolve(legacyURL: fixture.url, destinationURL: destination, defaults: fixture.defaults, domainName: fixture.domain)
        let parent = try repository(parentURL)
        let trackID = try TrackID(fixture.trackID.uuidString)
        let oldNote = try XCTUnwrap(parent.videoNotes(trackID: trackID).first)
        try parent.deleteVideoNote(id: oldNote.id, trackID: trackID)
        let edited = VideoNote(trackID: trackID, content: "Current handwritten edit", createdAt: Date(timeIntervalSince1970: 500), updatedAt: Date(timeIntervalSince1970: 800))
        try parent.saveVideoNote(edited)
        let bookmark = try XCTUnwrap(parent.videoBookmarks(trackID: trackID).first)
        let newBookmark = try VideoTimeBookmark(id: bookmark.id, trackID: trackID, timestampMilliseconds: 42, title: "User title", note: "User bookmark edit")
        try parent.saveVideoBookmark(newBookmark)
        var playlist = try XCTUnwrap(parent.localPlaylists().first)
        try playlist.rename("User-renamed list")
        try parent.saveUserNamedPlaylist(playlist)
        let originalReceipt = try parent.legacyArchive().receipt
        let originalDigest = try parent.legacyArchiveDigest()
        let plan = try parent.makeRunnableArchiveSuccessor()
        XCTAssertTrue(plan.excludedOriginalRecordKeys.contains("note:" + oldNote.id.uuidString))
        let target = try PublicArchiveSuccessorRouter.prepareAndActivate(legacyURL: fixture.url, destinationURL: destination, defaults: fixture.defaults, domainName: fixture.domain)
        let live = try repository(target)
        XCTAssertEqual(try live.videoNotes(trackID: trackID), [edited])
        XCTAssertEqual(try live.videoBookmarks(trackID: trackID), [newBookmark])
        let archivedBookmark = try XCTUnwrap(parent.legacyArchive().models["trackBookmark"]?.first)
        let originalBookmarkFields = try XCTUnwrap(JSONSerialization.jsonObject(with: archivedBookmark.fields) as? [String: Any])
        let liveBookmarkRow = try XCTUnwrap(live.context.fetch(FetchDescriptor<MusesSchemaV1.Record>()).first { $0.kindRaw == StoreKind.bookmark.rawValue })
        let liveBookmarkFields = try XCTUnwrap(JSONSerialization.jsonObject(with: liveBookmarkRow.payload) as? [String: Any])
        XCTAssertEqual(liveBookmarkFields["createdAt"] as? Double, originalBookmarkFields["createdAt"] as? Double)
        let identity = try XCTUnwrap(live.get(SuccessorIdentity.self, kind: .migration, id: "runnable-successor-v1"))
        XCTAssertEqual(identity.preservedPlaylistPins[playlist.id.uuidString], try parent.list(LegacyPlaylist.self, kind: .playlist).first?.pinned)
        XCTAssertEqual(try live.track(id: trackID)?.liked, try parent.track(id: trackID)?.liked)
        var expectedQueue = try PublicLibrarySnapshot(repository: parent).queue
        expectedQueue.sourceContext = nil
        XCTAssertEqual(try PublicLibrarySnapshot(repository: live).queue, expectedQueue)
        XCTAssertEqual(try live.localPlaylists(), [playlist])
        XCTAssertEqual(try live.localPlaylists().first?.playbackTrackIDs.count, 2)
        XCTAssertEqual(try live.legacyArchive().receipt, originalReceipt)
        XCTAssertTrue(try live.legacyArchive().tracks.isEmpty)
        XCTAssertTrue(try live.legacyArchive().queue.isEmpty)
        XCTAssertTrue(try live.legacyArchive().models.isEmpty)
        XCTAssertEqual(try live.track(id: trackID)?.metadataOrigin, .placeholder)
        XCTAssertEqual(try parent.legacyArchiveDigest(), originalDigest)
        XCTAssertEqual(try PublicStoreRouter.fingerprint(fixture.url), sourceHash)
        // Edits after activation must survive re-entry, never replaced by the frozen plan.
        let later = edited.edited(content: "After activation")
        try live.saveVideoNote(later)
        XCTAssertEqual(try PublicStoreRouter.resolve(legacyURL: fixture.url, destinationURL: destination, defaults: fixture.defaults, domainName: fixture.domain), target)
        XCTAssertEqual(try repository(target).videoNotes(trackID: trackID), [later])
        _ = try live.deleteSavedTrack(trackID)
        XCTAssertThrowsError(try live.restoreOriginalPlaylist(playlist.id))
        XCTAssertThrowsError(try live.importLegacy(LegacyUserTruthBundle()))
        let capture = try LegacyStoreReader.read(sourceURL: fixture.url, snapshotURL: root.appendingPathComponent("restore-attempt.sqlite"), defaults: fixture.defaults, domainName: fixture.domain)
        XCTAssertThrowsError(try live.importLegacyComplete(capture.bundle))
        XCTAssertThrowsError(try live.installRunnableArchiveSuccessor(plan))
        XCTAssertThrowsError(try live.projectLegacyForPublic(routeID: UUID()))
        XCTAssertTrue(try repository(target).videoNotes(trackID: trackID).isEmpty)
        XCTAssertTrue(try repository(target).videoBookmarks(trackID: trackID).isEmpty)
        XCTAssertTrue(try PublicLibrarySnapshot(repository: repository(target)).tracks.isEmpty)
    }
    func testParentEditDuringPreparationBlocksActivation() throws {
        let root = try directory()
        let fixture = try PhysicalLegacyFixture(url: root.appendingPathComponent("old.sqlite"))
        defer { fixture.closePinAndSettings() }
        let destination = root.appendingPathComponent("new.sqlite")
        let parentURL = try PublicStoreRouter.resolve(legacyURL: fixture.url, destinationURL: destination, defaults: fixture.defaults, domainName: fixture.domain)
        let parent = try repository(parentURL)
        XCTAssertThrowsError(try PublicArchiveSuccessorRouter.prepareAndActivate(legacyURL: fixture.url, destinationURL: destination, defaults: fixture.defaults, domainName: fixture.domain, checkpoint: { phase in
            if phase == .verified {
                var playlist = try XCTUnwrap(parent.localPlaylists().first)
                try playlist.rename("Late parent edit")
                try parent.saveUserNamedPlaylist(playlist)
            }
        }))
        XCTAssertEqual(try parent.localPlaylists().first?.name, "Late parent edit")
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.appendingPathExtension("upgrade").appendingPathComponent("successor-active.json").path))
        XCTAssertThrowsError(try PublicArchiveSuccessorRouter.prepareAndActivate(legacyURL: fixture.url, destinationURL: destination, defaults: fixture.defaults, domainName: fixture.domain))
    }

    func testPreparationFailuresKeepOriginalAndRetryWithoutFallback() throws {
        enum Injected: Error { case failure }
        for phase in [PublicArchiveSuccessorRouter.Checkpoint.intent, .beforeSave, .saved, .verified, .activated] {
            let root = try directory()
            let fixture = try PhysicalLegacyFixture(url: root.appendingPathComponent("old.sqlite"))
            defer { fixture.closePinAndSettings() }
            let original = try PublicStoreRouter.fingerprint(fixture.url)
            let destination = root.appendingPathComponent("new.sqlite")
            XCTAssertThrowsError(try PublicArchiveSuccessorRouter.prepareAndActivate(legacyURL: fixture.url, destinationURL: destination, defaults: fixture.defaults, domainName: fixture.domain, checkpoint: {
                if $0 == phase { throw Injected.failure }
            }))
            XCTAssertEqual(try PublicStoreRouter.fingerprint(fixture.url), original)
            if phase != .activated {
                XCTAssertThrowsError(try PublicStoreRouter.resolve(legacyURL: fixture.url, destinationURL: destination, defaults: fixture.defaults, domainName: fixture.domain))
            }
            let target = try PublicArchiveSuccessorRouter.prepareAndActivate(legacyURL: fixture.url, destinationURL: destination, defaults: fixture.defaults, domainName: fixture.domain)
            XCTAssertEqual(try PublicStoreRouter.resolve(legacyURL: fixture.url, destinationURL: destination, defaults: fixture.defaults, domainName: fixture.domain), target)
            // Renaming only a disposable candidate simulates missing storage; the original remains.
            try FileManager.default.moveItem(at: target, to: target.appendingPathExtension("missing-test"))
            XCTAssertThrowsError(try PublicStoreRouter.resolve(legacyURL: fixture.url, destinationURL: destination, defaults: fixture.defaults, domainName: fixture.domain))
            XCTAssertEqual(try PublicStoreRouter.fingerprint(fixture.url), original)
        }
    }
}
