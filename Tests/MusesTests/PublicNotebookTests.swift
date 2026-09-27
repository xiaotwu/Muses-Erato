import XCTest
import MusesDomain
import MusesPersistence
@testable import Muses

@MainActor final class PublicNotebookTests: XCTestCase {
    private final class Repository: VideoNotebookRepository {
        var notes: [VideoNote] = []
        var bookmarks: [VideoTimeBookmark] = []
        var fail = false
        func videoNotes(trackID: TrackID) throws -> [VideoNote] {
            if fail { throw VideoNotebookError.unavailable }
            return notes.filter { $0.trackID == trackID }
        }
        func videoBookmarks(trackID: TrackID) throws -> [VideoTimeBookmark] {
            if fail { throw VideoNotebookError.unavailable }
            return bookmarks.filter { $0.trackID == trackID }
        }
        func saveVideoNote(_ note: VideoNote) throws {
            if fail { throw VideoNotebookError.unavailable }
            notes.removeAll { $0.id == note.id }; notes.append(note)
        }
        func saveVideoBookmark(_ bookmark: VideoTimeBookmark) throws {
            if fail { throw VideoNotebookError.unavailable }
            bookmarks.removeAll { $0.id == bookmark.id }; bookmarks.append(bookmark)
        }
        func deleteVideoNotes(trackID: TrackID) throws {
            if fail { throw VideoNotebookError.unavailable }
            notes.removeAll { $0.trackID == trackID }
        }
        func deleteVideoBookmarks(trackID: TrackID) throws {
            if fail { throw VideoNotebookError.unavailable }
            bookmarks.removeAll { $0.trackID == trackID }
        }
        func deleteVideoNote(id: UUID, trackID: TrackID) throws {
            if fail { throw VideoNotebookError.unavailable }
            notes.removeAll { $0.id == id }
        }
        func deleteVideoBookmark(id: UUID, trackID: TrackID) throws {
            if fail { throw VideoNotebookError.unavailable }
            bookmarks.removeAll { $0.id == id }
        }
    }
    private func store() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appending(path: "public.sqlite")
    }
    func testFailedSaveDeleteAndReloadDoNotPublishProposedContent() throws {
        let id = try TrackID(UUID().uuidString)
        let repo = Repository()
        let model = PublicNotebookModel(repository: { repo })
        model.load(id)
        XCTAssertTrue(model.saveNote(trackID: id, content: "Original"))
        XCTAssertTrue(model.saveBookmark(trackID: id, milliseconds: 1234, title: "Keep", note: "Detail"))
        let original = model.page(for: id)
        let note = try XCTUnwrap(original.notes.first), bookmark = try XCTUnwrap(original.bookmarks.first)
        repo.fail = true
        XCTAssertFalse(model.saveNote(trackID: id, id: note.id, content: "Lost write"))
        XCTAssertFalse(model.saveBookmark(trackID: id, id: bookmark.id, milliseconds: 3000, title: "Lost title", note: nil))
        XCTAssertFalse(model.deleteNote(note))
        XCTAssertFalse(model.deleteBookmark(bookmark))
        XCTAssertFalse(model.clearNotes(id))
        XCTAssertFalse(model.clearBookmarks(id))
        XCTAssertEqual(model.page(for: id).notes, original.notes)
        XCTAssertEqual(model.page(for: id).bookmarks, original.bookmarks)
        XCTAssertNotNil(model.page(for: id).error)
        model.load(id)
        XCTAssertFalse(model.page(for: id).loaded)
        XCTAssertEqual(model.page(for: id).notes, original.notes)
        XCTAssertEqual(model.page(for: id).bookmarks, original.bookmarks)
        repo.fail = false
        model.load(id)
        XCTAssertNil(model.page(for: id).error)
        XCTAssertTrue(model.saveNote(trackID: id, id: note.id, content: "Retry succeeded"))
        XCTAssertEqual(model.page(for: id).notes.first?.createdAt, note.createdAt)
        XCTAssertFalse(model.saveBookmark(trackID: id, milliseconds: .nan, title: nil, note: nil))
        XCTAssertEqual(model.page(for: id).bookmarks, original.bookmarks)
        XCTAssertTrue(model.clearNotes(id))
        XCTAssertTrue(model.page(for: id).notes.isEmpty)
        XCTAssertEqual(model.page(for: id).bookmarks, original.bookmarks)
        XCTAssertTrue(model.clearBookmarks(id))
        XCTAssertTrue(model.page(for: id).bookmarks.isEmpty)
    }
    func testSeekReadyMatchingOnceRetryAndCancellation() throws {
        let controller = PublicBookmarkSeekController()
        let entry = UUID(), other = UUID()
        let video = try VideoID("dQw4w9WgXcQ"), wrongVideo = try VideoID("M7lc1UVf-VE")
        var seeks: [Double] = []
        try controller.prepare(entryID: entry, videoID: video, milliseconds: 12345.5)
        XCTAssertNil(try controller.ready(entryID: entry, videoID: video, generation: 1) { seeks.append($0) })
        controller.bind(entryID: entry, generation: 2)
        XCTAssertNil(try controller.ready(entryID: entry, videoID: video, generation: 1) { seeks.append($0) })
        XCTAssertNil(try controller.ready(entryID: other, videoID: video, generation: 2) { seeks.append($0) })
        XCTAssertNil(try controller.ready(entryID: entry, videoID: wrongVideo, generation: 2) { seeks.append($0) })
        XCTAssertThrowsError(try controller.ready(entryID: entry, videoID: video, generation: 2) { _ in throw VideoNotebookError.unavailable })
        XCTAssertNotNil(controller.request)
        XCTAssertEqual(try controller.ready(entryID: entry, videoID: video, generation: 2) { seeks.append($0) }, 12345.5)
        XCTAssertEqual(seeks, [12.3455])
        XCTAssertNil(try controller.ready(entryID: entry, videoID: video, generation: 2) { seeks.append($0) })
        try controller.prepare(entryID: other, videoID: video, milliseconds: 9000)
        controller.bind(entryID: other, generation: 3)
        XCTAssertNil(try controller.ready(entryID: entry, videoID: video, generation: 2) { seeks.append($0) })
        controller.cancel()
        XCTAssertNil(try controller.ready(entryID: other, videoID: video, generation: 3) { seeks.append($0) })
        XCTAssertEqual(seeks.count, 1)
        for value in [-1.0, .nan, .infinity] {
            XCTAssertThrowsError(try controller.prepare(entryID: entry, videoID: video, milliseconds: value))
        }
    }
    func testSessionNotebookReopenAndStaleAdapterIsolation() throws {
        let url = try store()
        let session = PublicYouTubeSession(storeURL: url)
        session.open(try VideoID("dQw4w9WgXcQ"), title: "Video")
        let track = try XCTUnwrap(session.currentTrack)
        session.notebook.load(track.id)
        XCTAssertTrue(session.notebook.saveNote(trackID: track.id, content: "My note"))
        XCTAssertTrue(session.notebook.saveBookmark(trackID: track.id, milliseconds: 12345, title: "Moment", note: "Remember"))
        let bookmark = try XCTUnwrap(session.notebook.page(for: track.id).bookmarks.first)
        let old = YouTubeIFrameAdapter()
        session.attach(old)
        let callback = old.onEvent
        session.detach()
        session.openBookmark(bookmark)
        XCTAssertEqual(session.bookmarkCueMilliseconds, 12345)
        XCTAssertTrue(session.showPlayer)
        XCTAssertEqual(session.queue.snapshot.intent, .pause)
        let current = YouTubeIFrameAdapter()
        session.attach(current)
        defer { session.detach() }
        let iframeID = try XCTUnwrap(IFrameVideoID("dQw4w9WgXcQ"))
        callback?(.init(videoID: iframeID, generation: 1, kind: .playing))
        XCTAssertNotEqual(session.state.state, .playing)
        XCTAssertTrue(session.history.isEmpty)
        callback?(.init(videoID: iframeID, generation: 1, kind: .ready))
        XCTAssertNotNil(session.bookmarkSeeking.request)
        current.onEvent?(.init(videoID: iframeID, generation: 1, kind: .cued))
        XCTAssertNotNil(session.bookmarkSeeking.request, "Cued must not consume a ready-only seek")
        XCTAssertFalse(session.hasCurrentPlaybackTime)
        current.onEvent?(.init(videoID: iframeID, generation: 1, kind: .time(position: 4.25, duration: 50)))
        XCTAssertEqual(session.state.positionMilliseconds, 4250)
        XCTAssertTrue(session.hasCurrentPlaybackTime)
        current.onEvent?(.init(videoID: iframeID, generation: 1, kind: .time(position: .infinity, duration: 50)))
        XCTAssertEqual(session.state.positionMilliseconds, 4250)
        session.detach()
        XCTAssertNil(session.bookmarkSeeking.request)
        XCTAssertFalse(session.hasCurrentPlaybackTime)
        let reopened = PublicYouTubeSession(storeURL: url)
        reopened.notebook.load(track.id)
        XCTAssertEqual(reopened.notebook.page(for: track.id).notes.first?.content, "My note")
        XCTAssertEqual(reopened.notebook.page(for: track.id).bookmarks.first, bookmark)
        XCTAssertFalse(reopened.showPlayer)
    }
}
