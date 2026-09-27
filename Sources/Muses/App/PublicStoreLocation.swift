import Foundation

// Keep the inherited store name for a non-destructive migration check without
// linking the inherited SwiftData schema or any of its playback services.
func musesDefaultStoreURL() -> URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? URL.documentsDirectory
    return base.appending(path: "Muses/muses-youtube-native.sqlite")
}
