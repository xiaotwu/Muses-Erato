import XCTest
import SwiftData
@testable import Muses

@MainActor
final class CarPlayCatalogTests: XCTestCase {

    func testEmptyLibraryProducesEmptyCatalog() throws {
        let container = try makeModelContainer(inMemory: true)
        let source = CarPlayLibrarySource(
            library: LibraryService(modelContainer: container),
            playlists: PlaylistService(modelContainer: container)
        )
        let catalog = source.catalog()
        XCTAssertTrue(catalog.recentlyPlayed.isEmpty)
        XCTAssertTrue(catalog.playlists.isEmpty)
        XCTAssertTrue(catalog.favorites.isEmpty)
    }

    func testCatalogReadsRecentlyPlaylistsAndFavorites() throws {
        let container = try makeModelContainer(inMemory: true)
        let ctx = ModelContext(container)
        let recent = Track(
            title: "Recent Song", artist: "A", youTubeId: "recent000001",
            lastPlayedAt: Date()
        )
        let liked = Track(
            title: "Liked Song", artist: "B", youTubeId: "liked0000001", liked: true
        )
        let other = Track(title: "Other", artist: "C", youTubeId: "other0000001")
        ctx.insert(recent)
        ctx.insert(liked)
        ctx.insert(other)
        try ctx.save()

        let playlists = PlaylistService(modelContainer: container)
        let playlist = playlists.create(name: "Road Trip")
        playlists.addTrack(playlist, track: other)

        let source = CarPlayLibrarySource(
            library: LibraryService(modelContainer: container),
            playlists: playlists
        )
        let catalog = source.catalog()
        XCTAssertEqual(catalog.recentlyPlayed.map(\.title), ["Recent Song"])
        XCTAssertEqual(catalog.favorites.map(\.title), ["Liked Song"])
        XCTAssertEqual(catalog.playlists.map(\.title), ["Road Trip"])
        XCTAssertEqual(catalog.playlists.first?.trackCount, 1)
        XCTAssertFalse(catalog.recentlyPlayed.contains(where: { $0.title == "Other" }))
    }

    func testTabListsCapAtTwelve() {
        let tracks = (0..<20).map { index in
            TrackSnapshot(
                id: UUID(),
                title: "Song \(index)",
                artist: "Artist",
                albumTitle: nil,
                durationSeconds: 1,
                youTubeId: String(format: "id%09d", index),
                artworkUrl: nil,
                sampleRate: nil,
                bitDepth: nil,
                codec: nil,
                isLossless: false
            )
        }
        let playlists = (0..<20).map {
            CarPlayPlaylistSummary(id: UUID(), title: "P\($0)", trackCount: 1)
        }
        let catalog = CarPlayBrowseCatalogBuilder.make(
            recentlyPlayed: tracks,
            playlists: playlists,
            favorites: tracks
        )
        XCTAssertEqual(catalog.recentlyPlayed.count, CarPlayBrowseLimits.tabItems)
        XCTAssertEqual(catalog.playlists.count, CarPlayBrowseLimits.tabItems)
        XCTAssertEqual(catalog.favorites.count, CarPlayBrowseLimits.tabItems)
        XCTAssertEqual(CarPlayBrowseLimits.tabItems, 12)
    }

    func testCatalogDropsTracksWithoutYouTubeIdentity() {
        let playable = TrackSnapshot(
            id: UUID(), title: "Playable", artist: "A", albumTitle: nil,
            durationSeconds: 1, youTubeId: "abcdefghijk", artworkUrl: nil,
            sampleRate: nil, bitDepth: nil, codec: nil, isLossless: false
        )
        let missing = TrackSnapshot(
            id: UUID(), title: "Missing", artist: "A", albumTitle: nil,
            durationSeconds: 1, youTubeId: "", artworkUrl: nil,
            sampleRate: nil, bitDepth: nil, codec: nil, isLossless: false
        )
        let catalog = CarPlayBrowseCatalogBuilder.make(
            recentlyPlayed: [missing, playable],
            playlists: [],
            favorites: [missing]
        )
        XCTAssertEqual(catalog.recentlyPlayed.map(\.title), ["Playable"])
        XCTAssertTrue(catalog.favorites.isEmpty)
    }

    func testPlaylistSnapshotsSkipDetachedItemsAndCapLength() throws {
        let container = try makeModelContainer(inMemory: true)
        let playlists = PlaylistService(modelContainer: container)
        let ctx = ModelContext(container)
        var tracks: [Track] = []
        for index in 0..<8 {
            let track = Track(
                title: "T\(index)",
                artist: "A",
                youTubeId: index == 2 ? "" : String(format: "vid%09d", index)
            )
            ctx.insert(track)
            tracks.append(track)
        }
        try ctx.save()
        let playlist = playlists.create(name: "Mix")
        for track in tracks {
            playlists.addTrack(playlist, track: track)
        }

        let snapshots = playlists.snapshots(for: playlist.id, limit: 5)
        XCTAssertEqual(snapshots.count, 5)
        XCTAssertFalse(snapshots.contains(where: { $0.youTubeId.isEmpty }))
        XCTAssertEqual(snapshots.first?.title, "T0")
        XCTAssertEqual(snapshots.map(\.title).contains("T2"), false)
    }

    func testPlaybackRouterUsesCollectionContext() {
        let first = TrackSnapshot(
            id: UUID(), title: "One", artist: "A", albumTitle: nil,
            durationSeconds: 1, youTubeId: "one00000001", artworkUrl: nil,
            sampleRate: nil, bitDepth: nil, codec: nil, isLossless: false
        )
        let second = TrackSnapshot(
            id: UUID(), title: "Two", artist: "A", albumTitle: nil,
            durationSeconds: 1, youTubeId: "two00000001", artworkUrl: nil,
            sampleRate: nil, bitDepth: nil, codec: nil, isLossless: false
        )
        let context = [first, second]
        XCTAssertEqual(
            CarPlayPlaybackRouter.recently(second, in: context),
            .play(start: second, context: context, source: .recently)
        )
        XCTAssertEqual(
            CarPlayPlaybackRouter.playlist(first, in: context),
            .play(start: first, context: context, source: .playlist)
        )
        XCTAssertEqual(
            CarPlayPlaybackRouter.favorites(first, in: context),
            .play(start: first, context: context, source: .songs)
        )
    }
}
