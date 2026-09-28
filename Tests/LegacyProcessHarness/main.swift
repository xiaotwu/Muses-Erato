import Foundation
import SwiftData
import Darwin
import MusesPersistence
import MusesDomain
@testable import Muses

@main
struct LegacyProcessHarness {
    @MainActor static func main() throws {
        let args = CommandLine.arguments
        guard args.count >= 3 else { fatalError("usage: LegacyProcessHarness root route|delete|edit [kill-checkpoint]") }
        let root = URL(fileURLWithPath: args[1])
        let destination = root.appendingPathComponent("muses-public-v1.sqlite")
        let legacy = root.appendingPathComponent("muses-youtube-native.sqlite")
        let domain = "muses.process-proof." + root.lastPathComponent
        let defaults = UserDefaults.standard
        defer { defaults.removePersistentDomain(forName: domain) }
        let checkpoint: (LegacyUpgradeCheckpoint) throws -> Void = { stage in
            if args.count > 3, args[3] == stage.rawValue { kill(getpid(), SIGKILL) }
        }
        let target: URL
        if args[2] == "finish-external" {
            try PublicStoreRouter.completeExternalDeletion(destinationURL: destination)
        }
        if args[2] == "delete" || args[2] == "delete-external" {
            target = try PublicStoreRouter.requestDeletion(legacyURL: legacy, destinationURL: destination,
                defaults: defaults, domainName: domain, externalCleanupRequired: args[2] == "delete-external", checkpoint: checkpoint)
        } else {
            target = try PublicStoreRouter.resolve(legacyURL: legacy, destinationURL: destination,
                defaults: defaults, domainName: domain, checkpoint: checkpoint)
        }
        let container = try SwiftDataSnapshotRepository.container(url: target)
        let repo = SwiftDataSnapshotRepository(context: ModelContext(container))
        if args[2] == "new-track" {
            try repo.saveTrack(MusesDomain.Track(id: TrackID(UUID().uuidString), title: "New data after deletion",
                artist: "User", source: .youtubeVideo(VideoID("abcdefghijk")),
                provenance: Provenance(provider: ProviderID("youtube"), originalID: "abcdefghijk")))
        }
        if args[2] == "edit", var track = try PublicLibrarySnapshot(repository: repo).tracks.first {
            track.title = "Public edit survives restart"
            try repo.saveTrack(track)
        }
        let library = try PublicLibrarySnapshot(repository: repo)
        let result: [String: Any] = ["target": target.path, "tracks": library.tracks.count,
            "history": library.history.count, "playlists": library.playlists.count,
            "occurrences": library.playlists.first?.occurrences?.count ?? 0,
            "playbackEntries": library.playlists.first?.playbackTrackIDs.count ?? 0,
            "title": library.tracks.first?.title ?? "",
            "archiveTracks": try repo.legacyArchive().tracks.count,
            "cleanupPending": PublicStoreRouter.deletionNeedsRestart(destinationURL: destination)]
        print(String(decoding: try JSONSerialization.data(withJSONObject: result, options: .sortedKeys), as: UTF8.self))
    }
}
