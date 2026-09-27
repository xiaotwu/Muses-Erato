import Foundation

// Keep the inherited store name for a non-destructive migration check without
// linking the inherited SwiftData schema or any of its playback services.
func musesDefaultStoreURL() -> URL {
    #if DEBUG
    // UI tests get a unique store directory and can relaunch it without touching user data.
    if let raw = ProcessInfo.processInfo.environment["MUSES_UI_TEST_LIBRARY"], let id = UUID(uuidString: raw) {
        return URL.applicationSupportDirectory.appending(path: "MusesUITests/\(id.uuidString)/muses-youtube-native.sqlite")
    }
    #endif
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? URL.documentsDirectory
    return base.appending(path: "Muses/muses-youtube-native.sqlite")
}

/// A partial legacy store is still user data requiring recovery. Do not create a
/// fresh public library while any member of its SQLite file set remains.
func legacyStoreArtifactsPresent(at storeURL: URL, manager: FileManager = .default) -> Bool {
    [storeURL.path, storeURL.path + "-wal", storeURL.path + "-shm"]
        .contains { manager.fileExists(atPath: $0) }
}
