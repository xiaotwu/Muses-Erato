import Foundation
import Observation

/// Transient read state only; persistence is a separate explicit confirmation.
@MainActor @Observable public final class PlaylistImportReader {
    public private(set) var draft = PlaylistImportDraft()
    public private(set) var metadata: CatalogItem?
    public private(set) var pagesRead = 0
    public init() {}

    /// A retry resumes the failed cursor. Cancellation never publishes its in-flight response.
    public func readAll(playlistID: String, fetch: (Bool, String?) async throws -> CatalogPage) async throws {
        try Task.checkCancellation()
        if metadata == nil {
            let page = try await fetch(false, nil)
            try Task.checkCancellation()
            guard let item = page.items.first(where: { $0.kind == .playlist && $0.id == playlistID }) else { throw PlaylistImportError.incomplete }
            metadata = item
        }
        while !draft.complete {
            try Task.checkCancellation()
            guard pagesRead < 100 else { throw PlaylistImportReadError.limit }
            let page = try await fetch(true, draft.nextPageToken)
            try Task.checkCancellation()
            try draft.append(page)
            pagesRead += 1
        }
    }
}
public enum PlaylistImportReadError: Error { case limit }

/// Account selection results are memory-only. Partial results remain explicitly incomplete.
@MainActor @Observable public final class OwnedPlaylistReader {
    public private(set) var items: [CatalogItem] = []
    public private(set) var complete = false
    public private(set) var pagesRead = 0
    public private(set) var nextPageToken: String?
    private var seenTokens = Set<String>()
    public init() {}
    public func readAll(fetch: (String?) async throws -> CatalogPage) async throws {
        while !complete {
            try Task.checkCancellation()
            guard pagesRead < 100 else { throw PlaylistImportReadError.limit }
            let page = try await fetch(nextPageToken)
            try Task.checkCancellation()
            guard page.items.allSatisfy({ $0.kind == .playlist }),
                  page.nextPageToken.map({ !$0.isEmpty && !seenTokens.contains($0) }) ?? true else { throw PlaylistImportError.incomplete }
            let existing = Set(items.map(\.id))
            let incoming = page.items.map(\.id)
            guard Set(incoming).count == incoming.count, existing.isDisjoint(with: incoming) else { throw PlaylistImportError.incomplete }
            items += page.items
            nextPageToken = page.nextPageToken
            if let token = nextPageToken { seenTokens.insert(token) }
            pagesRead += 1
            complete = nextPageToken == nil
        }
    }
}
