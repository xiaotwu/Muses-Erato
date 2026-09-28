import SwiftUI
import MusesDomain

private func notebookTime(_ milliseconds: Double) -> String {
    let seconds = Int(milliseconds / 1000)
    return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
}

/// Embedded directly in video details; notebook state is independent of catalog UI.
struct PublicNotebookSections: View {
    let session: PublicYouTubeSession
    let trackID: TrackID
    private var model: PublicNotebookModel { session.notebook }
    private var page: PublicNotebookModel.Page { model.page(for: trackID) }
    var body: some View {
        Section("Notes") {
            if page.notes.isEmpty { Text("No notes yet.").foregroundStyle(.secondary) }
            ForEach(page.notes) { note in PublicNotebookNoteRow(model: model, note: note) }
            PublicNotebookActions(model: model, trackID: trackID, kind: .notes)
        }
        .task(id: trackID) { model.load(trackID) }
        Section("Time bookmarks") {
            if page.bookmarks.isEmpty { Text("No bookmarks yet.").foregroundStyle(.secondary) }
            ForEach(page.bookmarks) { bookmark in
                PublicNotebookBookmarkRow(session: session, bookmark: bookmark)
            }
            PublicNotebookActions(model: model, trackID: trackID, kind: .bookmarks)
            Text("Bookmarks open the player paused. Press Play to watch.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        if let error = page.error {
            Section {
                Text(error).foregroundStyle(.red).accessibilityIdentifier("notebook.error")
                if !page.loaded {
                    Button { model.load(trackID) } label: { PublicIconActionLabel(title: "Reload notebook", symbol: "arrow.clockwise") }
                        .labelStyle(.iconOnly).accessibilityLabel("Reload notebook")
                }
            }
        }
    }
}

private struct PublicNotebookNoteRow: View {
    let model: PublicNotebookModel
    let note: VideoNote
    @State private var editing = false
    @State private var deleting = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(note.content).textSelection(.enabled)
            Text(note.updatedAt, format: .dateTime.year().month().day()).font(.caption).foregroundStyle(.secondary)
            HStack {
                Button { editing = true } label: { PublicIconActionLabel(title: "Edit note", symbol: "pencil") }
                    .accessibilityLabel("Edit note").accessibilityIdentifier("notebook.editNote.\(note.id)")
                Spacer()
                Button(role: .destructive) { deleting = true } label: { PublicIconActionLabel(title: "Delete note", symbol: "trash") }
                    .accessibilityLabel("Delete note").accessibilityIdentifier("notebook.deleteNote.\(note.id)")
            }.buttonStyle(.borderless).labelStyle(.iconOnly).controlSize(.large)
        }
        .sheet(isPresented: $editing) { PublicNoteEditor(model: model, trackID: note.trackID, original: note) }
        .alert("Delete this note?", isPresented: $deleting) {
            Button("Delete note", role: .destructive) { model.deleteNote(note) }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Removes this note from your notebook. Your video and other entries are kept. A retained original may remain until you delete all local Muses data.") }
    }
}

private struct PublicNotebookBookmarkRow: View {
    let session: PublicYouTubeSession
    let bookmark: VideoTimeBookmark
    @State private var editing = false
    @State private var deleting = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { session.openBookmark(bookmark) } label: {
                Label("\(notebookTime(bookmark.timestampMilliseconds)) · \(bookmark.title ?? "Bookmarked moment")", systemImage: "play.rectangle")
                    .frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.borderless).accessibilityIdentifier("notebook.openBookmark.\(bookmark.id)")
            if let note = bookmark.note, !note.isEmpty { Text(note).foregroundStyle(.secondary) }
            HStack {
                Button { editing = true } label: { PublicIconActionLabel(title: "Edit bookmark", symbol: "pencil") }
                    .accessibilityLabel("Edit bookmark").accessibilityIdentifier("notebook.editBookmark.\(bookmark.id)")
                Spacer()
                Button(role: .destructive) { deleting = true } label: { PublicIconActionLabel(title: "Delete bookmark", symbol: "trash") }
                    .accessibilityLabel("Delete bookmark").accessibilityIdentifier("notebook.deleteBookmark.\(bookmark.id)")
            }.buttonStyle(.borderless).labelStyle(.iconOnly).controlSize(.large)
        }
        .sheet(isPresented: $editing) {
            PublicBookmarkEditor(model: session.notebook, trackID: bookmark.trackID, original: bookmark, milliseconds: bookmark.timestampMilliseconds)
        }
        .alert("Delete this bookmark?", isPresented: $deleting) {
            Button("Delete bookmark", role: .destructive) { session.notebook.deleteBookmark(bookmark) }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Removes this bookmark from your notebook. Your video and other entries are kept. A retained original may remain until you delete all local Muses data.") }
    }
}

private enum NotebookListKind { case notes, bookmarks }

/// Presentation state lives on an on-screen action, not an off-screen List section.
private struct PublicNotebookActions: View {
    let model: PublicNotebookModel
    let trackID: TrackID
    let kind: NotebookListKind
    @State private var adding = false
    @State private var clearing = false
    private var isNotes: Bool { kind == .notes }
    private var page: PublicNotebookModel.Page { model.page(for: trackID) }
    private var clearTitle: String { isNotes ? "Clear notes" : "Clear bookmarks" }
    var body: some View {
        PublicActionGroup {
            Button { adding = true } label: {
                PublicIconActionLabel(title: isNotes ? "Add note" : "Add time bookmark", symbol: isNotes ? "square.and.pencil" : "bookmark")
            }
                .disabled(!page.loaded)
                .accessibilityLabel(isNotes ? "Add note" : "Add time bookmark")
                .accessibilityIdentifier(isNotes ? "notebook.addNote" : "notebook.addBookmark")
            Button(role: .destructive) { clearing = true } label: {
                PublicTextActionLabel(title: isNotes ? "Clear notes" : "Clear bookmarks", symbol: "xmark.circle")
            }
                .disabled(!page.loaded || (isNotes ? page.notes.isEmpty : page.bookmarks.isEmpty))
                .accessibilityLabel(isNotes ? "Clear notes for this video" : "Clear bookmarks for this video")
                .accessibilityIdentifier(isNotes ? "notebook.clearNotes" : "notebook.clearBookmarks")
        }
        .buttonStyle(.borderless).labelStyle(.iconOnly).controlSize(.large)
        .sheet(isPresented: $adding) {
            if isNotes { PublicNoteEditor(model: model, trackID: trackID, original: nil) }
            else { PublicBookmarkEditor(model: model, trackID: trackID, original: nil, milliseconds: 0) }
        }
        .alert(isNotes ? "Clear all notes for this video?" : "Clear all bookmarks for this video?", isPresented: $clearing) {
            Button(clearTitle, role: .destructive) {
                if isNotes { model.clearNotes(trackID) } else { model.clearBookmarks(trackID) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text((isNotes ? "Deletes only this video's local notes. Bookmarks and other videos are kept." : "Deletes only this video's local time bookmarks. Notes and other videos are kept.") + " Retained originals remain until you delete all local Muses data.")
        }
    }
}

private struct BookmarkDraft: Identifiable {
    let id = UUID()
    var original: VideoTimeBookmark? = nil
    let milliseconds: Double
}

private struct PublicNoteEditor: View {
    let model: PublicNotebookModel
    let trackID: TrackID
    let original: VideoNote?
    @Environment(\.dismiss) private var dismiss
    @State private var content: String
    init(model: PublicNotebookModel, trackID: TrackID, original: VideoNote?) {
        self.model = model; self.trackID = trackID; self.original = original
        // An editor intentionally owns a draft until save or cancel.
        _content = State(initialValue: original?.content ?? "")
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    TextEditor(text: $content).frame(minHeight: 160)
                        .accessibilityLabel("Note text").accessibilityIdentifier("notebook.noteText")
                }
                if let error = model.page(for: trackID).error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle(original == nil ? "Add note" : "Edit note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { PublicIconActionLabel(title: "Cancel", symbol: "xmark") }.labelStyle(.iconOnly).accessibilityLabel("Cancel") }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if model.saveNote(trackID: trackID, id: original?.id, content: content) { dismiss() }
                    } label: { PublicIconActionLabel(title: "Save", symbol: "checkmark") }.disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .labelStyle(.iconOnly).accessibilityLabel("Save note").accessibilityIdentifier("notebook.saveNote")
                }
            }
        }.interactiveDismissDisabled()
    }
}

private struct PublicBookmarkEditor: View {
    let model: PublicNotebookModel
    let trackID: TrackID
    let original: VideoTimeBookmark?
    let initialMilliseconds: Double
    @Environment(\.dismiss) private var dismiss
    @State private var seconds: String
    @State private var title: String
    @State private var note: String
    init(model: PublicNotebookModel, trackID: TrackID, original: VideoTimeBookmark?, milliseconds: Double) {
        self.model = model; self.trackID = trackID; self.original = original; initialMilliseconds = milliseconds
        _seconds = State(initialValue: String(milliseconds / 1000))
        _title = State(initialValue: original?.title ?? "")
        _note = State(initialValue: original?.note ?? "")
    }
    private var milliseconds: Double? {
        if seconds == String(initialMilliseconds / 1000) { return initialMilliseconds }
        guard let value = Double(seconds.trimmingCharacters(in: .whitespacesAndNewlines)),
              (try? VideoTimeBookmark.validateTime(value * 1000)) != nil else { return nil }
        return value * 1000
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Moment in the video") {
                    TextField("Time in seconds", text: $seconds).keyboardType(.decimalPad)
                        .accessibilityIdentifier("notebook.bookmarkSeconds")
                    TextField("Title (optional)", text: $title).accessibilityIdentifier("notebook.bookmarkTitle")
                    TextField("Note (optional)", text: $note, axis: .vertical).lineLimit(3...8)
                        .accessibilityIdentifier("notebook.bookmarkNote")
                    if milliseconds == nil { Text(VideoNotebookError.invalidTime.localizedDescription).foregroundStyle(.red) }
                }
                if let error = model.page(for: trackID).error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle(original == nil ? "Add bookmark" : "Edit bookmark")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { PublicIconActionLabel(title: "Cancel", symbol: "xmark") }.labelStyle(.iconOnly).accessibilityLabel("Cancel") }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        guard let milliseconds else { return }
                        // Preserve optional nil versus empty values when an unchanged legacy field is edited.
                        let savedTitle = title == (original?.title ?? "") ? original?.title : (title.isEmpty ? nil : title)
                        let savedNote = note == (original?.note ?? "") ? original?.note : (note.isEmpty ? nil : note)
                        if model.saveBookmark(trackID: trackID, id: original?.id, milliseconds: milliseconds, title: savedTitle, note: savedNote) { dismiss() }
                    } label: { PublicIconActionLabel(title: "Save", symbol: "checkmark") }.disabled(milliseconds == nil).labelStyle(.iconOnly).accessibilityLabel("Save bookmark").accessibilityIdentifier("notebook.saveBookmark")
                }
            }
        }.interactiveDismissDisabled()
    }
}

/// Captures the latest accepted current-video clock before pausing for the editor.
struct PublicCurrentBookmarkButton: View {
    let session: PublicYouTubeSession
    let trackID: TrackID
    @State private var draft: BookmarkDraft?
    var body: some View {
        Button {
            let milliseconds = Double(session.state.positionMilliseconds)
            session.pause()
            session.notebook.load(trackID)
            draft = BookmarkDraft(milliseconds: milliseconds)
        } label: { PublicIconActionLabel(title: "Bookmark current time", symbol: "bookmark") }
        .disabled(!session.hasCurrentPlaybackTime)
        .labelStyle(.iconOnly).accessibilityLabel("Bookmark current time")
        .accessibilityIdentifier("notebook.bookmarkCurrent")
        .sheet(item: $draft) { draft in
            PublicBookmarkEditor(model: session.notebook, trackID: trackID, original: nil, milliseconds: draft.milliseconds)
        }
        if let milliseconds = session.bookmarkCueMilliseconds {
            Text("Bookmark at \(notebookTime(milliseconds)). Press Play to watch.")
                .font(.footnote).foregroundStyle(.secondary)
                .accessibilityIdentifier("notebook.bookmarkTarget")
        }
    }
}
