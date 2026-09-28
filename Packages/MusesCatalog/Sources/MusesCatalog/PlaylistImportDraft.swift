import Foundation

/// No persistent writes until the last explicitly requested page has succeeded.
public struct PlaylistImportDraft: Sendable {
    public private(set) var items: [CatalogItem] = []
    public private(set) var nextPageToken: String?
    public private(set) var loaded = false
    private var tokens = Set<String>()
    public var complete: Bool { loaded && nextPageToken == nil }
    public init() {}
    public mutating func append(_ page: CatalogPage) throws {
        guard !complete, page.items.allSatisfy({ $0.kind == .video && $0.id.count == 11 && $0.listEntryID?.isEmpty == false }),
              page.nextPageToken.map({ !$0.isEmpty && !tokens.contains($0) }) ?? true else {
            throw PlaylistImportError.incomplete
        }
        // A repeated resource ID across pages indicates a changed/inconsistent snapshot.
        let old = Set(items.compactMap(\.listEntryID))
        let incoming = page.items.compactMap(\.listEntryID)
        guard Set(incoming).count == incoming.count, old.isDisjoint(with: incoming) else { throw PlaylistImportError.incomplete }
        if let next = page.nextPageToken { tokens.insert(next) }
        items += page.items; nextPageToken = page.nextPageToken; loaded = true
    }
}
public enum PlaylistImportError: LocalizedError {
    case incomplete
    public var errorDescription: String? { "This playlist could not be read completely. Nothing was imported. Restart the import; automatic Mixes and some music-only playlists are not available through the YouTube Data API." }
}
