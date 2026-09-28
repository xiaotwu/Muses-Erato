import SwiftUI
import MusesCatalog
import MusesNetworking

struct PublicPlaylistImportView: View {
    let session: PublicYouTubeSession
    @Environment(\.dismiss) private var dismiss
    @State private var link = ""
    @State private var name = ""
    @State private var selected: String?
    @State private var authorized = false
    @State private var draft = PlaylistImportDraft()
    @State private var busy = false
    @State private var error: String?
    @State private var work: Task<Void, Never>?
    @State private var pagesRead = 0

    var body: some View {
        NavigationStack {
            Form {
                if let selected {
                    Section("Read playlist") {
                        Text(selected).font(.caption).textSelection(.enabled)
                        Text("\(draft.items.count) entries loaded in playlist order. Repeated videos are retained for playback.")
                        if !draft.complete {
                            importButton("Read all remaining entries (up to 100 pages)", icon: "arrow.down.to.line") { loadPage(all: true) }
                                .accessibilityIdentifier("playlistImport.loadAll")
                            Text("One tap reads the remaining pages, up to 100 pages (5,000 entries) per import. Cancel stops without saving.").font(.footnote)
                            importButton(draft.loaded ? "Load next 50 entries" : "Read first 50 entries", icon: "chevron.down") { loadPage() }
                                .accessibilityIdentifier("playlistImport.loadPage")
                        } else {
                            Text("All pages loaded. Playback availability may vary for private, deleted or restricted videos.")
                            TextField("Your local playlist name", text: $name)
                                .accessibilityIdentifier("playlistImport.name")
                            Text("Choose your own name. YouTube titles are temporary display data and are not saved.").font(.footnote)
                            importButton("Import \(draft.items.count) entries to this device", icon: "checkmark.circle") {
                                do { try session.saveImportedPlaylist(name: name, draft: draft); dismiss() }
                                catch { self.error = error.localizedDescription }
                            }
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("playlistImport.save")
                        }
                        importButton("Choose another playlist", icon: "arrow.uturn.backward") { self.selected = nil; draft = .init(); error = nil; name = "" }
                    }
                } else {
                    Section("From your YouTube account") {
                        Text("Playlists owned by your signed-in account and readable by the YouTube Data API. This does not include your entire YouTube Music library.").font(.footnote)
                        if session.signedIn {
                            ForEach(session.accountPlaylistPages.items, id: \.rowID) { item in
                                Button(item.title) { select(item.id, authorized: true) }
                                    .accessibilityIdentifier("playlistImport.account.\(item.id)")
                            }
                            if !session.accountPlaylistPages.loaded || session.accountPlaylistPages.nextPageToken != nil {
                                importButton(session.accountPlaylistPages.loaded ? "Load more account playlists" : "Load account playlists", icon: "arrow.down.circle") {
                                    run { await session.loadAccountPlaylists() }
                                }.accessibilityIdentifier("playlistImport.accountLoad")
                            }
                            if session.accountPlaylistPages.loaded && session.accountPlaylistPages.items.isEmpty {
                                Text("No owned playlists were returned. Try a playlist share link below.")
                            }
                            if let message = session.accountPlaylistPages.error { Text(message).foregroundStyle(.red) }
                        } else {
                            importButton("Sign in to choose account playlists", icon: "person.crop.circle.badge.plus") { run { await session.signIn() } }
                                .accessibilityIdentifier("playlistImport.signIn")
                            if let message = session.failureMessage { Text(message).foregroundStyle(.red) }
                        }
                    }
                    Section("From a playlist share link") {
                        TextField("YouTube Music or YouTube playlist link", text: $link)
                            .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                            .accessibilityIdentifier("playlistImport.link")
                        importButton("Read playlist link", icon: "link") {
                            guard case .playlist(let id) = YouTubeCatalogLink.parse(link) else {
                                error = "Paste a playlist share link such as https://music.youtube.com/playlist?list=…"; return
                            }
                            select(id, authorized: session.signedIn)
                        }.accessibilityIdentifier("playlistImport.readLink")
                        Text("For playlists missing from the account list, paste their share link. Automatic Mixes and music-only collections may not be supported. Private playlists require the owning account.").font(.footnote)
                    }
                }
                if busy { ProgressView("Reading…") }
                if let error { Text(error).foregroundStyle(.red).accessibilityIdentifier("playlistImport.error") }
                Text("No account playlists are changed. Nothing is saved until every page has loaded and you confirm import. You can delete the local playlist from Library.").font(.footnote)
            }
            .disabled(busy)
            .navigationTitle("Import playlist")
            .toolbar { Button("Cancel", systemImage: "xmark") { work?.cancel(); dismiss() }.labelStyle(.iconOnly) }
        }
        .onDisappear { work?.cancel() }
    }
    private func importButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).frame(width: 44, height: 44).contentShape(Rectangle())
        }.accessibilityLabel(title).buttonStyle(.borderless)
    }
    private func select(_ id: String, authorized: Bool) {
        selected = id; self.authorized = authorized; draft = .init(); pagesRead = 0; name = ""; error = nil
        loadPage()
    }
    private func run(_ operation: @escaping @MainActor () async -> Void) {
        busy = true
        work = Task { await operation(); busy = false }
    }
    private func importError(_ error: Error) -> String {
        let detail: String
        switch error {
        case APIError.unauthorized: detail = "Sign in again, or configure YouTube API access before importing."
        case APIError.unavailable: detail = "The playlist was not found or is unavailable to this account."
        case APIError.forbidden: detail = "YouTube denied access. Use the owning account for private playlists. Automatic Mixes and some music-only collections cannot be read by the official API."
        case APIError.quotaExceeded: detail = "YouTube API quota is exhausted. Try again after the quota resets."
        case APIError.network, APIError.server, APIError.rateLimited: detail = "The request failed temporarily. Retry this page; no partial playlist has been saved."
        default: detail = "The playlist could not be read completely. It may be unsupported by the official API. Choose another playlist or restart the import."
        }
        return "Nothing imported. " + detail
    }
    private func loadPage(all: Bool = false) {
        guard let selected else { return }
        error = nil
        run {
            do {
                if !draft.loaded {
                    let metadata = try await session.readCatalog(.playlist(selected), authorized: authorized)
                    guard metadata.items.contains(where: { $0.kind == .playlist && $0.id == selected }) else { throw PlaylistImportError.incomplete }
                }
                repeat {
                    guard pagesRead < 100 else {
                        self.error = "Nothing imported. This playlist exceeds the 100-page (5,000-entry) limit. Choose a smaller playlist."
                        return
                    }
                    let page = try await session.readCatalog(.playlist(selected), token: draft.nextPageToken, contents: true, authorized: authorized)
                    try Task.checkCancellation()
                    try draft.append(page)
                    pagesRead += 1
                } while all && !draft.complete
            } catch is CancellationError { }
            catch { self.error = importError(error) }
        }
    }
}
