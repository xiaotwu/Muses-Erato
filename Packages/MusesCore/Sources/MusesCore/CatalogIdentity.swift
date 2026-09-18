import Foundation

/// Stable catalog identity helpers. Never invent identity from display title alone
/// when a channel / browse / playlist id is available.
public enum CatalogIdentity: Sendable {
    public static func artist(channelID: String?, browseID: String?) -> String? {
        if let channelID, !channelID.isEmpty {
            return "channel:\(channelID)"
        }
        if let browseID, !browseID.isEmpty {
            return "browse:\(browseID)"
        }
        return nil
    }

    public static func release(playlistID: String?, albumTitle: String?, artistKey: String?) -> String? {
        if let playlistID, !playlistID.isEmpty {
            return "playlist:\(playlistID)"
        }
        if let albumTitle, !albumTitle.isEmpty, let artistKey, !artistKey.isEmpty {
            return "album:\(artistKey.lowercased()):\(albumTitle.lowercased())"
        }
        return nil
    }
}
