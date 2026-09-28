import XCTest
import SwiftData
import MusesDomain
@testable import MusesPersistence

@MainActor final class RunnableSuccessorTests: XCTestCase {
    private var retainedContainers: [ModelContainer] = []
    private func source() throws -> SwiftDataSnapshotRepository {
        let container = try SwiftDataSnapshotRepository.container(inMemory: true)
        retainedContainers.append(container)
        let repo = SwiftDataSnapshotRepository(context: ModelContext(container))
        try repo.put(LegacyMigrationReceipt(recordCount: 0, payloadSHA256: "historical"), kind: .migration, id: "legacy-complete-v1")
        let track = Track(id: try TrackID(UUID().uuidString), title: "Unknown title", artist: "Unknown artist",
            source: .youtubeVideo(try VideoID("abcdefghijk")), provenance: try Provenance(provider: ProviderID("youtube"), originalID: "abcdefghijk"))
        try repo.saveTrack(track)
        return repo
    }
    func testOnlyReviewedContentAndExplicitNamesAreClassifiedAsUser() throws {
        let content = ArchiveField(address: "model/trackNote/id/content", value: Data("\"user\"".utf8))
        let bookmark = ArchiveField(address: "model/trackBookmark/id/title", value: Data("\"caption\"".utf8))
        let name = ArchiveField(address: "model/playlist/id/name", value: Data("\"remote copied title\"".utf8))
        let queue = ArchiveField(address: "queue/id/itemsJSON", value: Data("\"mixed\"".utf8))
        XCTAssertEqual(Set(LegacyUserFieldContracts.evidence(for: [content, bookmark, name, queue]).map(\.address)), [content.address, bookmark.address])
        let repo = try source()
        let track = try XCTUnwrap(repo.list(Track.self, kind: .track).first)
        var playlist = try LocalPlaylist(name: "Unknown historical name", trackIDs: [track.id])
        try repo.savePlaylist(playlist)
        let unknown = try repo.makeRunnableArchiveSuccessor()
        XCTAssertEqual(unknown.unresolvedPlaylistNames, [playlist.id])
        XCTAssertEqual(try JSONDecoder().decode(LocalPlaylist.self, from: XCTUnwrap(unknown.records.first { $0.kind == .localPlaylist }).data).name, "Recovered playlist")
        try playlist.rename("Explicit handwritten name")
        try repo.saveUserNamedPlaylist(playlist)
        XCTAssertTrue(try repo.makeRunnableArchiveSuccessor().unresolvedPlaylistNames.isEmpty)
        // An unproven later rewrite cannot reuse evidence for different bytes.
        try playlist.rename("Unproven overwrite")
        try repo.savePlaylist(playlist)
        XCTAssertEqual(try repo.makeRunnableArchiveSuccessor().unresolvedPlaylistNames, [playlist.id])
    }
    func testInstallSaveFailureRollsBackAndCannotReplayOverUserChanges() throws {
        enum Failure: Error { case disk }
        let repo = try source()
        let track = try XCTUnwrap(repo.list(Track.self, kind: .track).first)
        let note = VideoNote(trackID: track.id, content: "User note")
        try repo.saveVideoNote(note)
        let plan = try repo.makeRunnableArchiveSuccessor()
        let container = try SwiftDataSnapshotRepository.container(inMemory: true)
        let target = SwiftDataSnapshotRepository(context: container.mainContext)
        XCTAssertThrowsError(try target.installRunnableArchiveSuccessor(plan, beforeSave: { throw Failure.disk }))
        XCTAssertEqual(try target.context.fetchCount(FetchDescriptor<MusesSchemaV1.Record>()), 0)
        XCTAssertEqual(try repo.videoNotes(trackID: track.id), [note])
        try target.installRunnableArchiveSuccessor(plan)
        try target.deleteVideoNote(id: note.id, trackID: track.id)
        XCTAssertThrowsError(try target.installRunnableArchiveSuccessor(plan))
        XCTAssertTrue(try target.videoNotes(trackID: track.id).isEmpty)
        XCTAssertThrowsError(try target.importLegacy(LegacyUserTruthBundle()))
    }
    func testOrphanUserTextAndUnmappedExclusionFailWithoutDroppingData() throws {
        let repo = try source()
        let orphan = LegacyNote(id: UUID(), trackId: UUID(), content: "Only copy of orphan note", createdAt: Date(), updatedAt: Date())
        try repo.put(orphan, kind: .note, id: orphan.id.uuidString)
        XCTAssertThrowsError(try repo.makeRunnableArchiveSuccessor())
        XCTAssertEqual(try repo.list(LegacyNote.self, kind: .note).first?.content, orphan.content)
        try repo.delete(kind: .note, id: orphan.id.uuidString)
        let archive = try repo.legacyArchive()
        let staged = try ArchiveLifecycle.successor(fields: [], evidence: [], originalReceipt: archive.receipt,
            parentArchiveDigest: repo.legacyArchiveDigest(), now: Date(), maximumAPIAge: 29 * 86_400, excludedAddresses: ["unknown-field"])
        try repo.stageArchiveSuccessor(staged)
        XCTAssertThrowsError(try repo.makeRunnableArchiveSuccessor())
    }
}
