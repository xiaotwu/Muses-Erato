import XCTest
import MusesDomain
import MusesPersistence
import SwiftData
import MusesCatalog
import MusesNetworking
@testable import Muses

final class PublicYouTubeFlowTests: XCTestCase {
    func testLegacyGateBlocksEverySQLiteSidecar() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = directory.appending(path: "muses-youtube-native.sqlite")
        XCTAssertFalse(legacyStoreArtifactsPresent(at: store))
        for suffix in ["", "-wal", "-shm"] {
            let file = URL(fileURLWithPath: store.path + suffix)
            try Data([1]).write(to: file)
            XCTAssertTrue(legacyStoreArtifactsPresent(at: store), suffix)
            try FileManager.default.removeItem(at: file)
        }
    }

    func testKnownVideoLinksRejectOtherHostsAndMalformedIDs() throws {
        let id = "dQw4w9WgXcQ"
        XCTAssertEqual(PublicYouTubeSession.videoID(from: id)?.rawValue, id)
        XCTAssertEqual(PublicYouTubeSession.videoID(from: "https://www.youtube.com/watch?v=\(id)&t=42")?.rawValue, id)
        XCTAssertEqual(PublicYouTubeSession.videoID(from: "https://youtu.be/\(id)")?.rawValue, id)
        XCTAssertNil(PublicYouTubeSession.videoID(from: "https://youtube.com.evil.test/watch?v=\(id)"))
        XCTAssertNil(PublicYouTubeSession.videoID(from: "http://youtube.com/watch?v=\(id)"))
        XCTAssertNil(PublicYouTubeSession.videoID(from: "https://www.youtube.com/watch?v=bad"))
    }

    func testPublicYouTubeCapabilitiesDoNotExposeNativeAudio() throws {
        let source = PlaybackSource.youtubeVideo(try VideoID("dQw4w9WgXcQ"))
        let effective = PlaybackCapabilityPolicy.effective(
            source: source, rights: ContentRights(origin: .youtube),
            distribution: DistributionCapabilities(channel: .appStore),
            adapter: [.videoVisible, .seek, .queueByID, .audioProcessing, .backgroundAudio, .systemRemote],
            runtime: [.videoVisible, .seek, .queueByID, .audioProcessing, .backgroundAudio, .systemRemote])
        XCTAssertEqual(effective, [.videoVisible, .seek, .queueByID])
    }
}

@MainActor final class PublicLocalLibraryFlowTests: XCTestCase {
    private func store() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appending(path: "muses-public-v1.sqlite")
    }

    func testPlaylistFavoriteQueueAndRelaunch() throws {
        let url = try store()
        let session = PublicYouTubeSession(storeURL: url)
        XCTAssertNil(session.recoveryMessage)
        XCTAssertTrue(session.tracks.isEmpty)
        session.open(try VideoID("dQw4w9WgXcQ"), title: "First")
        let first = try XCTUnwrap(session.currentTrack)
        session.toggleFavorite()
        session.open(try VideoID("M7lc1UVf-VE"), title: "Second")
        let second = try XCTUnwrap(session.currentTrack)
        XCTAssertTrue(session.history.isEmpty, "Opening a page is not a playback event")
        XCTAssertFalse(session.createPlaylist("   "))
        XCTAssertTrue(session.createPlaylist("  Evening  "))
        let id = try XCTUnwrap(session.playlists.first?.id)
        XCTAssertTrue(session.editPlaylist(id) { $0.add(first.id); $0.add(second.id); $0.add(first.id) })
        XCTAssertTrue(session.editPlaylist(id) { try $0.rename("Night"); try $0.reorder([second.id, first.id]) })
        session.enqueuePlaylist(id)
        session.enqueueTrack(first, next: true)
        let entries = session.queue.snapshot.upcoming
        XCTAssertEqual(entries.map(\.trackID), [first.id, second.id, first.id])
        XCTAssertTrue(session.editQueue { try $0.remove(id: entries[1].id); try $0.reorder(id: entries[2].id, to: 0) })
        let reopened = PublicYouTubeSession(storeURL: url)
        XCTAssertNil(reopened.recoveryMessage)
        XCTAssertEqual(reopened.playlists.first?.name, "Night")
        XCTAssertEqual(reopened.playlists.first?.trackIDs, [second.id, first.id])
        XCTAssertEqual(reopened.favorites.map(\.id), [first.id])
        XCTAssertEqual(reopened.queue.snapshot.upcoming.map(\.id), [entries[2].id, entries[0].id])
        XCTAssertEqual(reopened.state.state, .paused)
        XCTAssertFalse(reopened.showPlayer)
        XCTAssertTrue(reopened.editPlaylist(id) { $0.remove(second.id) })
        XCTAssertTrue(reopened.deletePlaylist(id))
        XCTAssertEqual(reopened.tracks.count, 2)
        reopened.clearUpcoming()
        XCTAssertFalse(reopened.hasNext)
    }

    func testHistoryOnlyRecordsConfirmedCurrentPlaybackAndCanBeCleared() throws {
        let session = PublicYouTubeSession(storeURL: try store())
        let video = try VideoID("dQw4w9WgXcQ")
        session.open(video, title: "First")
        let adapter = YouTubeIFrameAdapter()
        session.attach(adapter)
        defer { session.detach() }
        let id = try XCTUnwrap(IFrameVideoID(video.rawValue))
        adapter.onEvent?(.init(videoID: id, generation: 99, kind: .playing))
        XCTAssertTrue(session.history.isEmpty)
        adapter.onEvent?(.init(videoID: id, generation: 1, kind: .playing))
        adapter.onEvent?(.init(videoID: id, generation: 1, kind: .playing))
        XCTAssertEqual(session.playedIDs.count, 1)
        session.clearHistory()
        XCTAssertTrue(session.history.isEmpty)
        XCTAssertEqual(session.tracks.count, 1)
        XCTAssertTrue(try session.repository!.list(PlaybackHistoryEntry.self, kind: .history).isEmpty)
    }

    func testClearUpNextKeepsPlayingCurrentAndPersistsEmptyQueue() throws {
        let url = try store()
        let session = PublicYouTubeSession(storeURL: url)
        session.open(try VideoID("dQw4w9WgXcQ"), title: "Current")
        let track = try XCTUnwrap(session.currentTrack)
        session.enqueueTrack(track)
        session.enqueueTrack(track)
        let adapter = YouTubeIFrameAdapter()
        session.attach(adapter)
        defer { session.detach() }
        let id = try XCTUnwrap(IFrameVideoID("dQw4w9WgXcQ"))
        adapter.onEvent?(.init(videoID: id, generation: 1, kind: .playing))
        adapter.onEvent?(.init(videoID: id, generation: 1, kind: .time(position: 12, duration: 100)))
        let before = session.queue.snapshot
        session.clearUpcoming()
        XCTAssertTrue(session.queue.snapshot.upcoming.isEmpty)
        XCTAssertEqual(session.queue.snapshot.current, before.current)
        XCTAssertEqual(session.queue.snapshot.history, before.history)
        XCTAssertEqual(session.queue.snapshot.positionMilliseconds, before.positionMilliseconds)
        XCTAssertEqual(session.queue.snapshot.intent, .play)
        XCTAssertEqual(session.state.state, .playing)
        XCTAssertTrue(session.isPlayerVisible)
        let cleared = session.queue.snapshot
        session.clearUpcoming()
        XCTAssertEqual(session.queue.snapshot, cleared, "Empty clear is a no-op")
        let reopened = PublicYouTubeSession(storeURL: url)
        XCTAssertNil(reopened.recoveryMessage)
        XCTAssertFalse(reopened.hasNext)
        XCTAssertEqual(reopened.queue.snapshot.current, before.current)
        XCTAssertEqual(reopened.queue.snapshot.positionMilliseconds, 12000)
        XCTAssertEqual(reopened.queue.snapshot.intent, .pause)
    }

    func testLegacyAndCorruptUpgradeNeverCreateReplacement() throws {
        let url = try store()
        let legacy = url.deletingLastPathComponent().appending(path: "muses-youtube-native.sqlite-wal")
        let bytes = Data("keep legacy data".utf8)
        try bytes.write(to: legacy)
        let blocked = PublicYouTubeSession(storeURL: url)
        XCTAssertNotNil(blocked.recoveryMessage)
        XCTAssertNil(blocked.repository)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try Data(contentsOf: legacy), bytes)
        try FileManager.default.removeItem(at: legacy)
        let publicSidecar = URL(fileURLWithPath: url.path + "-wal")
        try bytes.write(to: publicSidecar)
        XCTAssertNotNil(PublicYouTubeSession(storeURL: url).recoveryMessage)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try Data(contentsOf: publicSidecar), bytes)
        try FileManager.default.removeItem(at: publicSidecar)
        try bytes.write(to: url)
        let corrupt = PublicYouTubeSession(storeURL: url)
        XCTAssertNotNil(corrupt.recoveryMessage)
        XCTAssertNil(corrupt.repository)
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }

    func testFailedMutationDoesNotPublishOrOverwriteFutureData() throws {
        let session = PublicYouTubeSession(storeURL: try store())
        session.open(try VideoID("dQw4w9WgXcQ"), title: "Keep")
        let track = try XCTUnwrap(session.currentTrack)
        let repo = try XCTUnwrap(session.repository)
        let rows = try repo.context.fetch(FetchDescriptor<MusesSchemaV1.Record>())
        let row = try XCTUnwrap(rows.first { $0.kindRaw == "track" })
        let original = row.payload
        row.payloadVersion = 99
        try repo.context.save()
        session.toggleFavorite()
        XCTAssertFalse(try XCTUnwrap(session.currentTrack).liked)
        XCTAssertEqual(row.payload, original)
        XCTAssertNotNil(session.failureMessage)
        let before = session.queue.snapshot
        XCTAssertFalse(session.editQueue { try $0.remove(id: UUID()) })
        XCTAssertEqual(session.queue.snapshot, before)
        XCTAssertEqual(session.tracks.first?.id, track.id)
    }
}


private actor MetadataBatchHTTP: HTTPTransport {
    var batchSizes: [Int] = []
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
        let ids = query.first { $0.name == "id" }!.value!.split(separator: ",").map(String.init)
        batchSizes.append(ids.count)
        let items: [[String: Any]] = ids.map { ["id": $0, "snippet": ["title": "Updated \($0)"]] }
        return HTTPResponse(status: 200, body: try JSONSerialization.data(withJSONObject: ["items": items]))
    }
}

extension PublicLocalLibraryFlowTests {
    func testExpiredAPITitleIsRemovedWithoutLosingFavoritePlaylistOrQueue() throws {
        let url = try store()
        let session = PublicYouTubeSession(storeURL: url)
        session.open(try VideoID("abcdefghijk"), title: "API title", metadataFetchedAt: Date().addingTimeInterval(-30 * 86400))
        let id = try XCTUnwrap(session.currentTrack?.id)
        session.toggleFavorite(id)
        XCTAssertTrue(session.createPlaylist("User playlist", trackIDs: [id]))
        let reopened = PublicYouTubeSession(storeURL: url)
        XCTAssertEqual(reopened.currentTrack?.title, "YouTube video abcdefghijk")
        XCTAssertEqual(reopened.currentTrack?.metadataOrigin, .placeholder)
        XCTAssertEqual(reopened.favorites.map(\.id), [id])
        XCTAssertEqual(reopened.playlists.first?.trackIDs, [id])
        XCTAssertEqual(reopened.playlists.first?.name, "User playlist")
        XCTAssertEqual(reopened.queue.snapshot.current?.trackID, id)
    }
    func testSavedMetadataRefreshUsesBatchesAndPreservesUserTitles() async throws {
        let transport = MetadataBatchHTTP()
        let catalog = YouTubeDataCatalog(apiKey: "fixture", transport: transport)
        let session = PublicYouTubeSession(storeURL: try store(), catalogOverride: catalog)
        for index in 0..<51 {
            let raw = String(format: "%011d", index)
            session.enqueue(try VideoID(raw), title: "YouTube video \(raw)")
        }
        session.enqueue(try VideoID("abcdefghijk"), title: "My custom title")
        await session.refreshSavedMetadata()
        let batches = await transport.batchSizes
        XCTAssertEqual(batches, [50, 1])
        XCTAssertEqual(session.tracks.filter { $0.metadataOrigin == .youtubeDataAPI }.count, 51)
        XCTAssertEqual(session.tracks.last?.title, "My custom title")
        XCTAssertEqual(session.queue.snapshot.upcoming.count, 52)
        XCTAssertTrue(session.tracks.dropLast().allSatisfy { $0.metadataFetchedAt != nil })
    }
}
