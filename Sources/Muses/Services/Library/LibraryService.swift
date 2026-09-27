import Foundation
import Observation
import SwiftData

/// YouTube-native 媒体库服务。
/// 统一由 modelContainer.mainContext 驱动，保障 SwiftData 实体图一致性与响应式追踪。
@MainActor
@Observable
final class LibraryService {
    let modelContainer: ModelContainer

    /// 统一使用主线程上下文，避免频繁分配临时 Context 导致的对象图断裂
    private var mainContext: ModelContext {
        modelContainer.mainContext
    }

    @available(*, deprecated, message: "Manual revision tracking is deprecated in favor of SwiftData mainContext reactive dirty tracking.")
    private(set) var likedRevision = 0
    @available(*, deprecated, message: "Manual revision tracking is deprecated in favor of SwiftData mainContext reactive dirty tracking.")
    private(set) var playRevision = 0
    @available(*, deprecated, message: "Manual revision tracking is deprecated in favor of SwiftData mainContext reactive dirty tracking.")
    private(set) var metadataRevision = 0

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func allTracks(search: String? = nil) -> [Track] {
        let query = search?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !query.isEmpty else {
            return (try? mainContext.fetch(FetchDescriptor<Track>(
                sortBy: [SortDescriptor(\.title)]))) ?? []
        }
        let descriptor = FetchDescriptor<Track>(
            predicate: #Predicate {
                $0.title.localizedStandardContains(query)
                    || $0.artist.localizedStandardContains(query)
                    || $0.albumTitle?.localizedStandardContains(query) == true
            },
            sortBy: [SortDescriptor(\.title)])
        return (try? mainContext.fetch(descriptor)) ?? []
    }

    func toggleLike(_ track: Track) {
        track.liked.toggle()
        saveContext()
        likedRevision &+= 1
    }

    func toggleLike(id: UUID) {
        guard let track = try? mainContext.fetch(FetchDescriptor<Track>(
            predicate: #Predicate { $0.id == id })).first else { return }
        track.liked.toggle()
        saveContext()
        likedRevision &+= 1
    }

    func updateTrack(id: UUID, title: String, artist: String,
                     albumTitle: String?, albumArtist: String?,
                     trackNo: Int?, discNo: Int?, year: Int?,
                     genre: String?, lyrics: String?) {
        guard let track = try? mainContext.fetch(FetchDescriptor<Track>(
            predicate: #Predicate { $0.id == id })).first else { return }
        track.title = title
        track.artist = artist
        track.albumTitle = albumTitle
        track.albumArtist = albumArtist
        track.trackNo = trackNo
        track.discNo = discNo
        track.year = year
        track.genre = genre
        track.lyrics = lyrics

        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        if track.artistCatalogID == nil || track.artistCatalogID?.hasPrefix("artist:") == true {
            let resolved = !cleanArtist.isEmpty ? cleanArtist : "Unknown Artist"
            track.artistCatalogID = "artist:\(resolved.lowercased())"
        }
        if track.releaseCatalogID == nil || track.releaseCatalogID?.hasPrefix("album:") == true || track.releaseCatalogID?.hasPrefix("single:") == true {
            let artistKey = (!cleanArtist.isEmpty ? cleanArtist : "Unknown Artist").lowercased()
            if let a = albumTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !a.isEmpty {
                track.releaseCatalogID = "album:\(artistKey):\(a.lowercased())"
            } else {
                track.releaseCatalogID = "single:\(track.youTubeId)"
            }
        }

        saveContext()
        metadataRevision &+= 1
    }

    func isLiked(id: UUID) -> Bool {
        return ((try? mainContext.fetch(FetchDescriptor<Track>(
            predicate: #Predicate { $0.id == id })).first)?.liked) ?? false
    }

    func track(by id: UUID) -> Track? {
        return try? mainContext.fetch(FetchDescriptor<Track>(
            predicate: #Predicate { $0.id == id })).first
    }

    func likedIDs(for ids: [UUID]) -> Set<UUID> {
        guard !ids.isEmpty else { return [] }
        let rows = (try? mainContext.fetch(FetchDescriptor<Track>(
            predicate: #Predicate { ids.contains($0.id) && $0.liked == true }))) ?? []
        return Set(rows.map(\.id))
    }

    func likedTracks() -> [Track] {
        return (try? mainContext.fetch(FetchDescriptor<Track>(
            predicate: #Predicate { $0.liked == true },
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]))) ?? []
    }

    func recordPlay(trackId: UUID) {
        guard let track = try? mainContext.fetch(FetchDescriptor<Track>(
            predicate: #Predicate { $0.id == trackId })).first else {
            AppLog.for("LibraryService").warning(
                "recordPlay missing track \(trackId)")
            return
        }
        track.lastPlayedAt = .init()
        track.playCount += 1
        saveContext()
        playRevision &+= 1
    }

    func recentlyPlayedTracks(limit: Int = 20) -> [TrackSnapshot] {
        let descriptor = FetchDescriptor<Track>(
            predicate: #Predicate { $0.lastPlayedAt != nil },
            sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)])
        guard let tracks = try? mainContext.fetch(descriptor) else { return [] }
        var seen = Set<String>()
        var result: [TrackSnapshot] = []
        for track in tracks where seen.insert(track.youTubeId).inserted {
            result.append(TrackSnapshot(from: track))
            if result.count >= limit { break }
        }
        return result
    }

    func topArtistName() -> String? {
        guard let tracks = try? mainContext.fetch(FetchDescriptor<Track>(
            predicate: #Predicate { $0.playCount > 0 })) else { return nil }
        var totals: [String: Int] = [:]
        for track in tracks {
            totals[track.albumArtist ?? track.artist, default: 0] += track.playCount
        }
        return totals.max { $0.value < $1.value }?.key
    }

    struct DiscoverySignals: Sendable {
        let topArtistNames: [String]
        let recentlyPlayedArtistNames: [String]
        let likedArtistNames: [String]
    }

    func discoverySignalsAsync(limit: Int = 5) async -> DiscoverySignals {
        await Task.detached(priority: .utility) { [modelContainer] in
            let context = ModelContext(modelContainer)
            let tracks = (try? context.fetch(FetchDescriptor<Track>())) ?? []
            var topCounts: [String: Int] = [:]
            for track in tracks where track.playCount > 0 {
                topCounts[track.artist, default: 0] += track.playCount
            }
            let top = topCounts.sorted { $0.value > $1.value }
                .prefix(limit).map(\.key)
            let recent = Self.uniqueNames(
                tracks.compactMap { track in
                    track.lastPlayedAt.map { (track.artist, $0) }
                }.sorted { $0.1 > $1.1 }.map(\.0), limit: limit)
            let liked = Self.uniqueNames(
                tracks.filter(\.liked).sorted { $0.addedAt > $1.addedAt }.map(\.artist),
                limit: limit)
            return DiscoverySignals(
                topArtistNames: top,
                recentlyPlayedArtistNames: recent,
                likedArtistNames: liked)
        }.value
    }

    private nonisolated static func uniqueNames(_ names: [String], limit: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for name in names {
            guard seen.insert(name.lowercased()).inserted else { continue }
            result.append(name)
            if result.count >= limit { break }
        }
        return result
    }

    private func saveContext() {
        do {
            if mainContext.hasChanges {
                try mainContext.save()
            }
        } catch {
            AppLog.for("LibraryService").warning("mainContext save failed: \(error.localizedDescription)")
        }
    }
}
