import SwiftUI
import UniformTypeIdentifiers
import MusesPersistence
import MusesDomain

struct PublicMigrationArchivePresentation: ViewModifier {
    @Bindable var session: PublicYouTubeSession
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if session.hasMigrationArchive || session.recoveryMessage != nil {
                    Button { session.showMigrationArchive = true } label: {
                        Label(session.successorIdentity != nil ? "Reviewed library · Retained originals" : (session.hasMigrationArchive ? "Recovered library · Original records" : "Library recovery options"), systemImage: "archivebox")
                            .font(.footnote).frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                    }
                    .labelStyle(.iconOnly)
                    .frame(minHeight: 44)
                    .background(.regularMaterial)
                    .accessibilityLabel(session.successorIdentity != nil ? "Reviewed library and retained originals" : (session.hasMigrationArchive ? "Recovered library and original records" : "Library recovery options"))
                    .accessibilityIdentifier("migrationArchive")
                }
            }
            .sheet(isPresented: $session.showMigrationArchive) {
                PublicMigrationArchiveView(session: session)
            }
    }
}

private struct ArchiveDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private struct PublicMigrationArchiveView: View {
    @Bindable var session: PublicYouTubeSession
    @Environment(\.dismiss) private var dismiss
    @State private var archive: LegacyLibraryArchive?
    @State private var playlists: [LocalPlaylist] = []
    @State private var document = ArchiveDocument(data: Data())
    @State private var exporting = false
    @State private var deleting = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if let successor = session.successorIdentity {
                    Section("Reviewed library") {
                        Text("Your notes, bookmarks and playlist entries are in this library. Original files and recovery copies are still retained separately; they have not been deleted.")
                        Text("Earlier records cannot replace your current edits. Some playlist names need review and appear as “Recovered playlist”.")
                        NavigationLink("Preservation record") { recordText((try? JSONEncoder().encode(successor)) ?? Data()) }
                    }
                } else {
                    Section {
                        Text("Your original records remain available here. Repeated playlist entries retain their own positions and can be edited individually. Unavailable entries are preserved.")
                        Text("History for videos no longer in your library remains in original records. Editing your current library does not change these original copies.")
                        Text("Old settings and account consent were preserved, but were not applied to this version.")
                    }
                }
                if let archive {
                    Section("Original playlists") {
                        ForEach(playlists) { playlist in
                            NavigationLink(playlist.name) {
                                List {
                                    Text("\(playlist.occurrences?.count ?? 0) original entries")
                                    ForEach(playlist.occurrences ?? []) { entry in
                                        Text(entry.trackID.flatMap { id in session.tracks.first { $0.id == id }?.title }
                                            ?? "Unavailable original entry")
                                    }
                                    Button {
                                        session.restoreOriginalPlaylist(playlist.id)
                                    } label: { PublicIconActionLabel(title: "Restore as a new local playlist", symbol: "arrow.counterclockwise") }
                                    .labelStyle(.iconOnly)
                                    Text("Restoring keeps repetitions and leaves current playlists unchanged.")
                                }.navigationTitle(playlist.name)
                            }
                        }
                    }
                    Section("Complete original records") {
                        ForEach(archive.tracks, id: \.id) { track in
                            NavigationLink(track.title) { recordText((try? JSONEncoder().encode(track)) ?? Data()) }
                        }
                        ForEach(archive.models.keys.sorted(), id: \.self) { kind in
                            NavigationLink("\(kind) · \(archive.models[kind]?.count ?? 0)") {
                                List(archive.models[kind] ?? [], id: \.id) { row in
                                    NavigationLink(row.id.uuidString) { recordText(row.fields) }
                                }.navigationTitle(kind)
                            }
                        }
                        NavigationLink("Original queue and settings") { recordText(document.data) }
                    }
                    Section {
                        Button { exporting = true } label: { PublicIconActionLabel(title: "Export complete original archive", symbol: "square.and.arrow.up") }
                            .labelStyle(.iconOnly)
                        Text("The export includes personal notes and old settings. Choose where to save it.")
                    }
                }
                Section {
                    if let recovery = session.recoveryMessage { Text(recovery) }
                    Button(role: .destructive) { deleting = true } label: { PublicIconActionLabel(title: "Delete library and retained originals", symbol: "trash") }
                        .labelStyle(.iconOnly)
                    Text("If the library cannot be read, this action still removes its retained files after restart. It cannot be undone.")
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle(session.successorIdentity == nil ? "Original library" : "Library preservation")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button { dismiss() } label: { PublicIconActionLabel(title: "Done", symbol: "xmark") }.labelStyle(.iconOnly) } }
            .task {
                do {
                    guard session.successorIdentity == nil, let repo = session.repository else { return }
                    archive = try repo.legacyArchive()
                    playlists = try repo.originalPlaylists()
                    document = ArchiveDocument(data: try JSONEncoder().encode(archive))
                } catch { self.error = error.localizedDescription }
            }
            .fileExporter(isPresented: $exporting, document: document, contentType: .json,
                          defaultFilename: "Muses-original-library") { result in
                if case .failure(let failure) = result { error = failure.localizedDescription }
            }
            .confirmationDialog("Delete current data, original library and migration backups?", isPresented: $deleting) {
                Button("Delete all local library data", role: .destructive) { Task { await session.deleteLocalData() } }
            } message: {
                Text("Deleted items will not be restored automatically. Restart Muses to finish removing retained files. This removes local account credentials; it does not delete your YouTube account.")
            }
        }
    }
    private func recordText(_ data: Data) -> some View {
        let pretty = (try? JSONSerialization.jsonObject(with: data)).flatMap {
            try? JSONSerialization.data(withJSONObject: $0, options: [.prettyPrinted, .sortedKeys])
        } ?? data
        return ScrollView { Text(String(decoding: pretty, as: UTF8.self)).font(.caption.monospaced()).textSelection(.enabled).padding() }
    }
}
