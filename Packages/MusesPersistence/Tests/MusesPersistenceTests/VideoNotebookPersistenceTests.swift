import XCTest
import SwiftData
import MusesDomain
@testable import MusesPersistence

@MainActor final class VideoNotebookPersistenceTests: XCTestCase {
    private func track(_ id: UUID) throws -> Track {
        try LegacyTrackSnapshot(id: id, title: "Saved", artist: "YouTube", youTubeId: "dQw4w9WgXcQ", durationMs: 0, liked: false).mapped()
    }
    func testLegacyProjectionReadEditDiskReopenAndDelete() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "notebook.sqlite")
        let track = try track(UUID())
        let noteID = UUID(), bookmarkID = UUID()
        let created = Date(timeIntervalSince1970: 123)
        do {
            let container = try SwiftDataSnapshotRepository.container(url: url)
            let repo = SwiftDataSnapshotRepository(context: container.mainContext)
            try repo.saveTrack(track)
            let note = LegacyNote(id: noteID, trackId: UUID(uuidString: track.id.rawValue)!, content: "Keep\nold words", createdAt: created, updatedAt: created)
            let bookmark = LegacyBookmark(id: bookmarkID, trackId: UUID(uuidString: track.id.rawValue)!, timestampMs: 1250.5, title: "Old", note: "Don't lose this")
            try repo.put(note, kind: .note, id: noteID.uuidString)
            try repo.put(bookmark, kind: .bookmark, id: bookmarkID.uuidString)
            let loaded = try XCTUnwrap(repo.videoNotes(trackID: track.id).first)
            XCTAssertEqual(loaded.id, noteID)
            XCTAssertEqual(loaded.trackID, track.id)
            try repo.saveVideoNote(loaded.edited(content: "Updated", at: Date(timeIntervalSince1970: 456)))
            let oldBookmark = try XCTUnwrap(repo.videoBookmarks(trackID: track.id).first)
            try repo.saveVideoBookmark(.init(id: oldBookmark.id, trackID: oldBookmark.trackID, timestampMilliseconds: 3456.75, title: "New", note: oldBookmark.note))
        }
        let container = try SwiftDataSnapshotRepository.container(url: url)
        let repo = SwiftDataSnapshotRepository(context: container.mainContext)
        let note = try XCTUnwrap(repo.videoNotes(trackID: track.id).first)
        XCTAssertEqual(note.content, "Updated")
        XCTAssertEqual(note.createdAt, created)
        XCTAssertEqual(note.updatedAt, Date(timeIntervalSince1970: 456))
        XCTAssertEqual(try repo.get(LegacyNote.self, kind: .note, id: noteID.uuidString)?.trackId.uuidString, track.id.rawValue)
        let bookmark = try XCTUnwrap(repo.get(LegacyBookmark.self, kind: .bookmark, id: bookmarkID.uuidString))
        XCTAssertEqual(bookmark.timestampMs, 3456.75)
        XCTAssertEqual(bookmark.title, "New")
        XCTAssertEqual(bookmark.note, "Don't lose this")
        try repo.deleteVideoNote(id: noteID, trackID: track.id)
        try repo.deleteVideoBookmark(id: bookmarkID, trackID: track.id)
        let second = try SwiftDataSnapshotRepository.container(url: url)
        let reopened = SwiftDataSnapshotRepository(context: second.mainContext)
        XCTAssertTrue(try reopened.videoNotes(trackID: track.id).isEmpty)
        XCTAssertTrue(try reopened.videoBookmarks(trackID: track.id).isEmpty)
        XCTAssertNotNil(try reopened.track(id: track.id))
    }
    func testUnknownFieldsFutureVersionsAndTrackOwnershipAreProtected() throws {
        let container = try SwiftDataSnapshotRepository.container(inMemory: true)
        let repo = SwiftDataSnapshotRepository(context: container.mainContext)
        let a = try track(UUID()), b = try track(UUID())
        try repo.saveTrack(a); try repo.saveTrack(b)
        let bookmark = try VideoTimeBookmark(trackID: a.id, timestampMilliseconds: 1234.5, title: "", note: nil)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(bookmark)) as? [String: Any])
        object["createdAt"] = 123.5
        object["futureUserField"] = ["keep": "everything"]
        let row = MusesSchemaV1.Record(kind: .bookmark, recordID: bookmark.id.uuidString, payload: try JSONSerialization.data(withJSONObject: object))
        container.mainContext.insert(row)
        try container.mainContext.save()
        try repo.saveVideoBookmark(.init(id: bookmark.id, trackID: a.id, timestampMilliseconds: 4567.25, title: bookmark.title, note: "Added"))
        let changed = try XCTUnwrap(JSONSerialization.jsonObject(with: row.payload) as? [String: Any])
        XCTAssertEqual(changed["createdAt"] as? Double, 123.5)
        XCTAssertEqual(changed["futureUserField"] as? [String: String], ["keep": "everything"])
        XCTAssertThrowsError(try repo.saveVideoBookmark(.init(id: bookmark.id, trackID: b.id, timestampMilliseconds: 1000)))
        XCTAssertThrowsError(try repo.deleteVideoBookmark(id: bookmark.id, trackID: b.id))
        let bytes = row.payload
        row.payloadVersion = 99
        try container.mainContext.save()
        XCTAssertThrowsError(try repo.saveVideoBookmark(bookmark))
        XCTAssertThrowsError(try repo.deleteVideoBookmark(id: bookmark.id, trackID: a.id))
        XCTAssertEqual(row.payload, bytes)
        XCTAssertEqual(row.payloadVersion, 99)
        XCTAssertThrowsError(try repo.saveVideoNote(.init(trackID: try TrackID(UUID().uuidString), content: "Orphan")))
        XCTAssertThrowsError(try repo.saveVideoNote(.init(trackID: a.id, content: "  \n")))
    }
    func testProjectionDeletionCanJoinTrackTransactionWithoutTouchingArchives() throws {
        let container = try SwiftDataSnapshotRepository.container(inMemory: true)
        let repo = SwiftDataSnapshotRepository(context: container.mainContext)
        let a = try track(UUID()), b = try track(UUID())
        try repo.saveTrack(a); try repo.saveTrack(b)
        try repo.saveVideoNote(.init(trackID: a.id, content: "A"))
        try repo.saveVideoNote(.init(trackID: b.id, content: "B"))
        try repo.saveVideoBookmark(.init(trackID: a.id, timestampMilliseconds: 1234))
        try repo.put("untouched receipt", kind: .migration, id: "receipt")
        try repo.put("untouched source", kind: .legacyModel, id: "trackNote:source")
        // A later step in the owner's transaction fails; rollback retains notebook.
        try repo.stageVideoNotebookDeletion(trackID: a.id)
        container.mainContext.rollback()
        XCTAssertEqual(try repo.videoNotes(trackID: a.id).count, 1)
        XCTAssertEqual(try repo.videoBookmarks(trackID: a.id).count, 1)
        let bad = MusesSchemaV1.Record(kind: .bookmark, recordID: "future", payload: Data(), payloadVersion: 99)
        container.mainContext.insert(bad)
        try container.mainContext.save()
        XCTAssertThrowsError(try repo.deleteVideoNotebook(trackID: a.id))
        XCTAssertEqual(try repo.videoNotes(trackID: a.id).count, 1)
        container.mainContext.delete(bad)
        try container.mainContext.save()
        try repo.deleteVideoNotebook(trackID: a.id)
        XCTAssertTrue(try repo.videoNotes(trackID: a.id).isEmpty)
        XCTAssertTrue(try repo.videoBookmarks(trackID: a.id).isEmpty)
        XCTAssertEqual(try repo.videoNotes(trackID: b.id).count, 1)
        XCTAssertEqual(try repo.get(String.self, kind: .migration, id: "receipt"), "untouched receipt")
        XCTAssertEqual(try repo.get(String.self, kind: .legacyModel, id: "trackNote:source"), "untouched source")
        XCTAssertNotNil(try repo.track(id: a.id), "The notebook helper does not delete the track itself")
    }

    func testClearListsKeepsOtherKindAndOtherVideo() throws {
        let container = try SwiftDataSnapshotRepository.container(inMemory: true)
        let repo = SwiftDataSnapshotRepository(context: container.mainContext)
        let a = try track(UUID()), b = try track(UUID())
        try repo.saveTrack(a); try repo.saveTrack(b)
        try repo.saveVideoNote(.init(trackID: a.id, content: "A"))
        try repo.saveVideoNote(.init(trackID: b.id, content: "B"))
        try repo.saveVideoBookmark(.init(trackID: a.id, timestampMilliseconds: 1))
        try repo.saveVideoBookmark(.init(trackID: b.id, timestampMilliseconds: 2))
        try repo.deleteVideoNotes(trackID: a.id)
        XCTAssertTrue(try repo.videoNotes(trackID: a.id).isEmpty)
        XCTAssertEqual(try repo.videoBookmarks(trackID: a.id).count, 1)
        XCTAssertEqual(try repo.videoNotes(trackID: b.id).count, 1)
        try repo.deleteVideoBookmarks(trackID: a.id)
        XCTAssertTrue(try repo.videoBookmarks(trackID: a.id).isEmpty)
        XCTAssertEqual(try repo.videoBookmarks(trackID: b.id).count, 1)
    }

}
