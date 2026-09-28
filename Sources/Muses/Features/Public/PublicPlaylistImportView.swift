import SwiftUI
import MusesCatalog
import MusesNetworking
import MusesDomain

struct PublicPlaylistImportView: View {
    let session: PublicYouTubeSession
    @Environment(\.dismiss) private var dismiss
    @State private var link = ""
    @State private var name = ""
    @State private var selected: String?
    @State private var authorized = false
    @State private var reader = PlaylistImportReader()
    private var draft: PlaylistImportDraft { reader.draft }
    @State private var busy = false
    @State private var error: String?
    @State private var work: Task<Void, Never>?
    @State private var owned = OwnedPlaylistReader()
    @State private var ownedLoading = false
    @State private var ownedError: String?
    @State private var ownedWork: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                if let selected {
                    Section("Read playlist") {
                        Text(reader.metadata?.title ?? "Loading playlist…").font(.headline)
                        Text("\(draft.items.count) entries loaded in playlist order. Repeated videos are retained for playback.")
                        if !draft.complete {
                            if !busy {
                                importButton("Retry loading playlist", icon: "arrow.clockwise") { loadAll() }
                                    .accessibilityIdentifier("playlistImport.retry")
                            }
                            Text("Loading automatically, up to 5,000 entries. Cancel stops without saving.").font(.footnote)
                        } else {
                            Text("All pages loaded. Playback availability may vary for private, deleted or restricted videos.")
                            TextField("Playlist name (optional rename)", text: $name)
                                .accessibilityIdentifier("playlistImport.name")
                            Text("Optional: choose a different name for this device.").font(.footnote)
                            importButton("Import \(draft.items.count) entries to this device", icon: "checkmark.circle") {
                                do { try session.saveImportedPlaylist(name: name, draft: draft, remoteSource: RemotePlaylistSource(playlistID: selected, requiresAuthorization: authorized), originalName: reader.metadata?.title, nameFetchedAt: reader.metadata?.fetchedAt); dismiss() }
                                catch { self.error = error.localizedDescription }
                            }
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("playlistImport.save")
                        }
                        importButton("Choose another playlist", icon: "arrow.uturn.backward") { self.selected = nil; reader = .init(); error = nil; name = "" }
                    }
                } else {
                    Section("From your YouTube account") {
                        Text("Playlists owned by your signed-in account. Some YouTube Music collections may not be available here.").font(.footnote)
                        if session.signedIn {
                            if ownedLoading { ProgressView("Loading playlists… \(owned.items.count) found") }
                            ForEach(owned.items, id: \.rowID) { item in
                                Button(item.title) { select(item.id, authorized: true) }
                                    .accessibilityIdentifier("playlistImport.account.\(item.id)")
                            }
                            if owned.complete && owned.items.isEmpty {
                                Text("No owned playlists were returned. Try a playlist share link below.")
                            }
                            if let ownedError {
                                Text("Showing \(owned.items.count) playlists; this list is incomplete. \(ownedError)")
                                    .foregroundStyle(.red).accessibilityIdentifier("playlistImport.accountError")
                                if owned.pagesRead < 100 {
                                    importButton("Retry loading account playlists", icon: "arrow.clockwise") { loadOwned() }
                                        .accessibilityIdentifier("playlistImport.accountRetry")
                                }
                            }
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
            .disabled(busy || ownedLoading)
            .navigationTitle("Import playlist")
            .toolbar { Button("Cancel", systemImage: "xmark") { work?.cancel(); ownedWork?.cancel(); dismiss() }.labelStyle(.iconOnly) }
        }
        .task(id: session.signedIn) {
            if session.signedIn {
                if !owned.complete { loadOwned() }
            } else {
                ownedWork?.cancel(); owned = .init(); ownedError = nil; ownedLoading = false
                if authorized {
                    work?.cancel(); reader = .init(); selected = nil; name = ""; busy = false
                }
            }
        }
        .onDisappear { work?.cancel(); ownedWork?.cancel() }
    }
    private func importButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).frame(width: 44, height: 44).contentShape(Rectangle())
        }.accessibilityLabel(title).buttonStyle(.borderless)
    }
    private func select(_ id: String, authorized: Bool) {
        selected = id; self.authorized = authorized; reader = .init(); name = ""; error = nil
        loadAll()
    }
    private func run(_ operation: @escaping @MainActor () async -> Void) {
        busy = true
        work = Task { await operation(); busy = false }
    }
    private func importError(_ error: Error) -> String {
        let detail: String
        switch error {
        case PlaylistImportReadError.limit: detail = "This playlist exceeds the 100-page (5,000-entry) limit. Choose a smaller playlist."
        case APIError.unauthorized: detail = "Sign in again, or configure YouTube API access before importing."
        case APIError.unavailable: detail = "The playlist was not found or is unavailable to this account."
        case APIError.forbidden: detail = "YouTube denied access. Use the owning account for private playlists. Automatic Mixes and some music-only collections cannot be read by the official API."
        case APIError.quotaExceeded: detail = "YouTube API quota is exhausted. Try again after the quota resets."
        case APIError.network, APIError.server, APIError.rateLimited: detail = "The request failed temporarily. Retry this page; no partial playlist has been saved."
        default: detail = "The playlist could not be read completely. It may be unsupported by the official API. Choose another playlist or restart the import."
        }
        return "Nothing imported. " + detail
    }
    private func loadOwned() {
        guard !ownedLoading else { return }
        ownedLoading = true; ownedError = nil
        let current = owned
        ownedWork = Task {
            defer { if owned === current { ownedLoading = false } }
            do {
                try await current.readAll { token in try await session.readOwnedPlaylistPage(token: token) }
            } catch is CancellationError { }
            catch {
                guard owned === current else { return }
                if case PlaylistImportReadError.limit = error {
                    ownedError = "The 100-page limit was reached. Use a share link for a playlist not shown."
                } else {
                    ownedError = "Loading stopped. Retry when available, or use a playlist share link. " + importError(error)
                }
            }
        }
    }
    private func loadAll() {
        guard let selected else { return }
        error = nil
        run {
            do {
                try await reader.readAll(playlistID: selected) { contents, token in
                    try await session.readCatalog(.playlist(selected), token: token, contents: contents, authorized: authorized)
                }
                try Task.checkCancellation()
                name = reader.metadata?.title ?? ""
            } catch is CancellationError { }
            catch { self.error = importError(error) }
        }
    }
}
