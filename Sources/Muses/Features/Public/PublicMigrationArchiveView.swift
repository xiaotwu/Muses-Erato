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
                        Label(session.hasMigrationArchive ? "Recovered library · Original records" : "Library recovery options", systemImage: "archivebox")
                            .font(.footnote).frame(maxWidth: .infinity).padding(8)
                    }
                    .background(.regularMaterial)
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
                Section {
                    Text("Your original records remain available here. Repeated playlist entries play in their original order; the library editor groups repeated videos. Unavailable entries stay in this archive.")
                    Text("History for videos no longer in your library remains in original records. Reordering a playlist groups repeated entries; its original order stays recoverable here.")
                    Text("Old settings and account consent were preserved, but were not applied to this version.")
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
                                    Button("Restore as a new local playlist") {
                                        session.restoreOriginalPlaylist(playlist.id)
                                    }
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
                        Button("Export complete original archive") { exporting = true }
                        Text("The export includes personal notes and old settings. Choose where to save it.")
                    }
                }
                Section {
                    if let recovery = session.recoveryMessage { Text(recovery) }
                    Button("Delete library and retained originals", role: .destructive) { deleting = true }
                    Text("If the library cannot be read, this action still removes its retained files after restart. It cannot be undone.")
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Original library")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task {
                do {
                    guard let repo = session.repository else { return }
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
                Text("Automatic reimport will be disabled immediately. Restart Muses to finish removing retained files. This removes local account credentials; it does not delete your YouTube account.")
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
