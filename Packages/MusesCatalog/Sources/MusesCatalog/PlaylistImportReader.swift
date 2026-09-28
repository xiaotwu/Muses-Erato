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
