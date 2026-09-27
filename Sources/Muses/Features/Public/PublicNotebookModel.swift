import Foundation
import Observation
import MusesDomain

@MainActor @Observable
final class PublicNotebookModel {
    struct Page {
        var notes: [VideoNote] = []
        var bookmarks: [VideoTimeBookmark] = []
        var loaded = false
        var error: String?
    }
    private var pages: [TrackID: Page] = [:]
    @ObservationIgnored private let repository: () -> (any VideoNotebookRepository)?
    init(repository: @escaping () -> (any VideoNotebookRepository)?) { self.repository = repository }
    func page(for id: TrackID) -> Page { pages[id] ?? Page() }
    func reset() { pages = [:] }
    /// Call only after the owning saved-video deletion transaction commits.
    func forget(_ trackID: TrackID) { pages.removeValue(forKey: trackID) }

    func load(_ trackID: TrackID) {
        do {
            guard let repository = repository() else { throw VideoNotebookError.unavailable }
            let notes = try repository.videoNotes(trackID: trackID)
            let bookmarks = try repository.videoBookmarks(trackID: trackID)
            pages[trackID] = Page(notes: notes, bookmarks: bookmarks, loaded: true)
        } catch {
            var page = page(for: trackID)
            page.loaded = false
            page.error = error.localizedDescription
            pages[trackID] = page
        }
    }
    @discardableResult
    func saveNote(trackID: TrackID, id: UUID? = nil, content: String) -> Bool {
        mutate(trackID) { page, repository in
            let note: VideoNote
            if let id {
                guard let old = page.notes.first(where: { $0.id == id }) else { throw VideoNotebookError.missingEntry }
                note = old.edited(content: content)
            } else { note = VideoNote(trackID: trackID, content: content) }
            try repository.saveVideoNote(note)
            page.notes.removeAll { $0.id == note.id }
            page.notes.append(note)
            page.notes.sort { $0.createdAt < $1.createdAt }
        }
    }
    @discardableResult
    func saveBookmark(trackID: TrackID, id: UUID? = nil, milliseconds: Double, title: String?, note: String?) -> Bool {
        mutate(trackID) { page, repository in
            if let id, !page.bookmarks.contains(where: { $0.id == id }) { throw VideoNotebookError.missingEntry }
            let bookmark = try VideoTimeBookmark(id: id ?? UUID(), trackID: trackID, timestampMilliseconds: milliseconds, title: title, note: note)
            try repository.saveVideoBookmark(bookmark)
            page.bookmarks.removeAll { $0.id == bookmark.id }
            page.bookmarks.append(bookmark)
            page.bookmarks.sort { $0.timestampMilliseconds < $1.timestampMilliseconds }
        }
    }
    @discardableResult
    func deleteNote(_ note: VideoNote) -> Bool {
        mutate(note.trackID) { page, repository in
            try repository.deleteVideoNote(id: note.id, trackID: note.trackID)
            page.notes.removeAll { $0.id == note.id }
        }
    }
    @discardableResult
    func deleteBookmark(_ bookmark: VideoTimeBookmark) -> Bool {
        mutate(bookmark.trackID) { page, repository in
            try repository.deleteVideoBookmark(id: bookmark.id, trackID: bookmark.trackID)
            page.bookmarks.removeAll { $0.id == bookmark.id }
        }
    }
    @discardableResult
    func clearNotes(_ trackID: TrackID) -> Bool {
        mutate(trackID) { page, repository in
            try repository.deleteVideoNotes(trackID: trackID)
            page.notes = []
        }
    }
    @discardableResult
    func clearBookmarks(_ trackID: TrackID) -> Bool {
        mutate(trackID) { page, repository in
            try repository.deleteVideoBookmarks(trackID: trackID)
            page.bookmarks = []
        }
    }
    private func mutate(_ trackID: TrackID, action: (inout Page, any VideoNotebookRepository) throws -> Void) -> Bool {
        do {
            guard let repository = repository(), page(for: trackID).loaded else { throw VideoNotebookError.unavailable }
            var proposed = page(for: trackID)
            try action(&proposed, repository)
            proposed.error = nil
            pages[trackID] = proposed
            return true
        } catch {
            var unchanged = page(for: trackID)
            unchanged.error = error.localizedDescription
            pages[trackID] = unchanged
            return false
        }
    }
}

/// A bookmark request belongs to one queue occurrence AND one adapter instance.
/// A cued event is not ready. Failure leaves the request retryable; stale events
/// and repeated ready notifications cannot seek a different or newer video.
@MainActor final class PublicBookmarkSeekController {
    struct Request: Equatable {
        let entryID: UUID
        let videoID: VideoID
        let milliseconds: Double
        var generation: UInt64?
    }
    private(set) var request: Request?
    func prepare(entryID: UUID, videoID: VideoID, milliseconds: Double) throws {
        try VideoTimeBookmark.validateTime(milliseconds)
        request = Request(entryID: entryID, videoID: videoID, milliseconds: milliseconds)
    }
    func bind(entryID: UUID, generation: UInt64) {
        guard request?.entryID == entryID else { request = nil; return }
        request?.generation = generation
    }
    func cancel() { request = nil }
    func ready(entryID: UUID, videoID: VideoID, generation: UInt64, position: (Double) throws -> Void) throws -> Double? {
        guard let target = request, target.entryID == entryID, target.videoID == videoID,
              target.generation == generation else { return nil }
        try position(target.milliseconds / 1000)
        request = nil
        return target.milliseconds
    }
}
