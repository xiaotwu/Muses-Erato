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

    func testHistoryOnlyRecordsConfirmedCurrentPlaybackAndCanBeCleared() async throws {
        let session = PublicYouTubeSession(storeURL: try store(), catalogOverride: allowedCatalog())
        let video = try VideoID("dQw4w9WgXcQ")
        session.open(video, title: "First")
        let adapter = YouTubeIFrameAdapter()
        session.attach(adapter)
        await waitForCheck(adapter: adapter, session: session)
        XCTAssertTrue(adapter.hasLoadedVideo)
        defer { session.detach() }
        let id = try XCTUnwrap(IFrameVideoID(video.rawValue))
        adapter.onEvent?(.init(videoID: id, generation: 99, kind: .playing))
        XCTAssertTrue(session.history.isEmpty)
        adapter.onEvent?(.init(videoID: id, generation: adapter.currentGeneration, kind: .playing))
        adapter.onEvent?(.init(videoID: id, generation: adapter.currentGeneration, kind: .playing))
        XCTAssertEqual(session.playedIDs.count, 1)
        session.clearHistory()
        XCTAssertTrue(session.history.isEmpty)
        XCTAssertEqual(session.tracks.count, 1)
        XCTAssertTrue(try session.repository!.list(PlaybackHistoryEntry.self, kind: .history).isEmpty)
    }

    func testClearUpNextKeepsPlayingCurrentAndPersistsEmptyQueue() async throws {
        let url = try store()
        let session = PublicYouTubeSession(storeURL: url, catalogOverride: allowedCatalog())
        session.open(try VideoID("dQw4w9WgXcQ"), title: "Current")
        let track = try XCTUnwrap(session.currentTrack)
        session.enqueueTrack(track)
        session.enqueueTrack(track)
        let adapter = YouTubeIFrameAdapter()
        session.attach(adapter)
        await waitForCheck(adapter: adapter, session: session)
        XCTAssertTrue(adapter.hasLoadedVideo)
        defer { session.detach() }
        let id = try XCTUnwrap(IFrameVideoID("dQw4w9WgXcQ"))
        adapter.onEvent?(.init(videoID: id, generation: adapter.currentGeneration, kind: .playing))
        adapter.onEvent?(.init(videoID: id, generation: adapter.currentGeneration, kind: .time(position: 12, duration: 100)))
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

extension PublicLocalLibraryFlowTests {
    func testDeleteCurrentVideoCleansReferencesAndSurvivesRelaunch() throws {
        let url = try store()
        let session = PublicYouTubeSession(storeURL: url)
        session.open(try VideoID("abcdefghijk"), title: "First")
        let first = try XCTUnwrap(session.currentTrack)
        session.open(try VideoID("lmnopqrstuv"), title: "Second")
        let second = try XCTUnwrap(session.currentTrack)
        session.toggleFavorite(second.id)
        session.enqueueTrack(second)
        session.enqueueTrack(first)
        XCTAssertTrue(session.createPlaylist("Keep list", trackIDs: [first.id, second.id]))
        let history = PlaybackHistoryEntry(trackID: second.id)
        try session.repository?.put(history, kind: .history, id: history.id.uuidString)
        XCTAssertTrue(session.deleteSavedTrack(second.id))
        XCTAssertFalse(session.showPlayer)
        XCTAssertNil(session.currentTrack)
        XCTAssertEqual(session.tracks.map(\.id), [first.id])
        let restored = PublicYouTubeSession(storeURL: url)
        XCTAssertNil(restored.recoveryMessage)
        XCTAssertEqual(restored.playlists.first?.trackIDs, [first.id])
        XCTAssertTrue(restored.favorites.isEmpty); XCTAssertTrue(restored.history.isEmpty)
        XCTAssertEqual(restored.queue.snapshot.upcoming.map(\.trackID), [first.id])
        XCTAssertFalse(restored.queue.snapshot.history.contains { $0.trackID == second.id })
    }
    func testFailedDeletionDoesNotPublishSuccessOrDismissCurrent() throws {
        let session = PublicYouTubeSession(storeURL: try store())
        session.open(try VideoID("abcdefghijk"), title: "First")
        let first = try XCTUnwrap(session.currentTrack)
        try session.repository?.put("invalid queue payload", kind: .queue, id: "main")
        XCTAssertFalse(session.deleteSavedTrack(first.id))
        XCTAssertEqual(session.tracks.map(\.id), [first.id])
        XCTAssertEqual(session.currentTrack?.id, first.id)
        XCTAssertTrue(session.showPlayer)
        XCTAssertNotNil(session.failureMessage)
        XCTAssertNotNil(try session.repository?.track(id: first.id))
    }
    func testBatchClearScopeAndRestart() throws {
        let url = try store()
        let session = PublicYouTubeSession(storeURL: url)
        session.open(try VideoID("abcdefghijk"), title: "First")
        let first = try XCTUnwrap(session.currentTrack)
        session.toggleFavorite(first.id)
        XCTAssertTrue(session.createPlaylist("Keep", trackIDs: [first.id]))
        session.clearLibraryItems(.favorites)
        XCTAssertTrue(session.favorites.isEmpty)
        XCTAssertEqual(session.tracks.count, 1)
        XCTAssertEqual(session.playlists.first?.trackIDs, [first.id])
        session.clearLibraryItems(.videos)
        let restored = PublicYouTubeSession(storeURL: url)
        XCTAssertNil(restored.recoveryMessage)
        XCTAssertTrue(restored.tracks.isEmpty)
        XCTAssertEqual(restored.playlists.first?.name, "Keep")
        XCTAssertEqual(restored.playlists.first?.trackIDs, [])
        XCTAssertNil(restored.queue.snapshot.current)
        restored.clearLibraryItems(.playlists)
        XCTAssertTrue(PublicYouTubeSession(storeURL: url).playlists.isEmpty)
    }
}

extension PublicLocalLibraryFlowTests {
    func testClearingCatalogDisplayLeavesLocalCollectionsIntact() async throws {
        let session = PublicYouTubeSession(storeURL: try store())
        session.open(try VideoID("abcdefghijk"), title: "Local reference")
        let id = try XCTUnwrap(session.currentTrack?.id)
        XCTAssertTrue(session.createPlaylist("My list", trackIDs: [id]))
        let item = MusesCatalog.CatalogItem(kind: .channel, id: "UCfixture", title: "Cloud", channelID: nil, thumbnailURL: nil)
        await session.subscriptionPages.load { _ in MusesCatalog.CatalogPage(items: [item], nextPageToken: "next") }
        await session.accountPlaylistPages.load { _ in MusesCatalog.CatalogPage(items: [item], nextPageToken: nil) }
        await session.searchPages.load { _ in MusesCatalog.CatalogPage(items: [item], nextPageToken: nil) }
        session.clearSearchResults()
        XCTAssertTrue(session.searchItems.isEmpty)
        XCTAssertEqual(session.subscriptions.count, 1)
        await session.clearCatalogDisplay()
        XCTAssertTrue(session.subscriptions.isEmpty)
        XCTAssertNil(session.subscriptionPages.nextPageToken)
        XCTAssertTrue(session.accountPlaylistPages.items.isEmpty)
        XCTAssertEqual(session.tracks.map(\.id), [id])
        XCTAssertEqual(session.playlists.first?.trackIDs, [id])
    }
}

extension PublicLocalLibraryFlowTests {
    func testFavoriteAndDeletionDoNotReplaceFreshDisplayWithDiskPlaceholder() throws {
        let session = PublicYouTubeSession(storeURL: try store())
        session.open(try VideoID("abcdefghijk"), title: "Fresh API display", metadataFetchedAt: Date())
        let id = try XCTUnwrap(session.currentTrack?.id)
        session.toggleFavorite(id)
        var persisted = try XCTUnwrap(session.currentTrack)
        persisted.expireYouTubeMetadata(force: true)
        try session.repository?.saveTrack(persisted)
        XCTAssertTrue(session.removeFavorite(id))
        XCTAssertEqual(session.tracks.first?.title, "Fresh API display")
        session.clearLibraryItems(.favorites)
        XCTAssertEqual(session.tracks.first?.title, "Fresh API display")
        session.open(try VideoID("lmnopqrstuv"), title: "Other")
        let other = try XCTUnwrap(session.currentTrack?.id)
        XCTAssertTrue(session.deleteSavedTrack(other))
        XCTAssertEqual(session.tracks.first?.title, "Fresh API display")
    }
}

private struct EmbeddingStatusTransport: HTTPTransport {
    let status: String
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        let id = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "id" }!.value!
        return HTTPResponse(status: 200, body: Data(("{\"items\":[{\"id\":\"" + id + "\",\"snippet\":{\"title\":\"Video\"},\"status\":" + status + "}]}").utf8))
    }
}

@MainActor func allowedCatalog() -> YouTubeDataCatalog {
    YouTubeDataCatalog(apiKey: "fake", transport: EmbeddingStatusTransport(status: #"{"madeForKids":false,"embeddable":true}"#))
}

@MainActor func waitForCheck(adapter: YouTubeIFrameAdapter, session: PublicYouTubeSession) async {
    for _ in 0..<200 {
        if adapter.hasLoadedVideo || session.state.state == .failed { return }
        try? await Task.sleep(for: .milliseconds(5))
    }
}

extension PublicLocalLibraryFlowTests {
    func testRestrictedUnknownAndDeniedContentNeverLoadsRemotePlayer() async throws {
        for status in [#"{"madeForKids":true,"embeddable":true}"#, #"{"embeddable":true}"#, #"{"madeForKids":false,"embeddable":false}"#] {
            let session = PublicYouTubeSession(storeURL: try store(), catalogOverride:
                YouTubeDataCatalog(apiKey: "fake", transport: EmbeddingStatusTransport(status: status)))
            session.open(try VideoID("abcdefghijk"), title: "Restricted")
            let adapter = YouTubeIFrameAdapter()
            session.attach(adapter)
            await waitForCheck(adapter: adapter, session: session)
            XCTAssertFalse(adapter.hasLoadedVideo)
            XCTAssertEqual(session.state.state, .failed)
            XCTAssertTrue(session.state.capabilities.isEmpty)
            XCTAssertNotNil(session.failureMessage)
            // Even a forged event cannot record playback while status is blocked.
            adapter.onEvent?(.init(videoID: IFrameVideoID("abcdefghijk")!, generation: 0, kind: .playing))
            XCTAssertTrue(session.history.isEmpty)
            session.detach()
        }
    }
}

private actor DelayedEmbeddingStatusTransport: HTTPTransport {
    var pending: CheckedContinuation<HTTPResponse, Never>?
    var started: CheckedContinuation<Void, Never>?
    func waitUntilStarted() async {
        if pending != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func release() {
        pending?.resume(returning: HTTPResponse(status: 200, body: Data(#"{"items":[{"id":"abcdefghijk","snippet":{"title":"Old"},"status":{"madeForKids":false,"embeddable":true}}]}"#.utf8)))
        pending = nil
    }
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        if request.url!.absoluteString.contains("abcdefghijk") {
            return await withCheckedContinuation {
                pending = $0
                started?.resume(); started = nil
            }
        }
        return HTTPResponse(status: 200, body: Data(#"{"items":[{"id":"lmnopqrstuv","snippet":{"title":"New"},"status":{"madeForKids":true,"embeddable":true}}]}"#.utf8))
    }
}

extension PublicLocalLibraryFlowTests {
    func testLateAllowedResponseCannotLoadRestrictedNextOrDetachedPlayer() async throws {
        for detach in [false, true] {
            let transport = DelayedEmbeddingStatusTransport()
            let session = PublicYouTubeSession(storeURL: try store(), catalogOverride: YouTubeDataCatalog(apiKey: "fake", transport: transport))
            session.open(try VideoID("abcdefghijk"), title: "Old")
            let adapter = YouTubeIFrameAdapter()
            session.attach(adapter)
            await transport.waitUntilStarted()
            XCTAssertFalse(adapter.hasLoadedVideo)
            if detach { session.detach() }
            else {
                session.open(try VideoID("lmnopqrstuv"), title: "New")
                await waitForCheck(adapter: adapter, session: session)
                XCTAssertEqual(session.state.state, .failed)
            }
            await transport.release()
            for _ in 0..<20 { await Task.yield() }
            XCTAssertFalse(adapter.hasLoadedVideo)
            XCTAssertTrue(session.history.isEmpty)
            session.detach()
        }
    }

    func testCollectionNextAndRestartMustRecheckContentStatus() async throws {
        let url = try store()
        let session = PublicYouTubeSession(storeURL: url, catalogOverride: allowedCatalog())
        session.open(try VideoID("abcdefghijk"), title: "First")
        session.open(try VideoID("lmnopqrstuv"), title: "Second")
        XCTAssertTrue(session.playTracks(session.tracks, startingAt: 0, context: "test"))
        let adapter = YouTubeIFrameAdapter()
        session.attach(adapter)
        await waitForCheck(adapter: adapter, session: session)
        XCTAssertTrue(adapter.hasLoadedVideo)
        let initialGeneration = adapter.currentGeneration
        session.next()
        XCTAssertFalse(adapter.hasLoadedVideo, "The old player is removed during the next status check")
        await waitForCheck(adapter: adapter, session: session)
        XCTAssertTrue(adapter.hasLoadedVideo)
        XCTAssertGreaterThan(adapter.currentGeneration, initialGeneration)
        session.detach()
        let reopened = PublicYouTubeSession(storeURL: url, catalogOverride: YouTubeDataCatalog(apiKey: "fake", transport: EmbeddingStatusTransport(status: #"{"madeForKids":true,"embeddable":true}"#)))
        XCTAssertFalse(reopened.showPlayer)
        let afterRestart = YouTubeIFrameAdapter()
        reopened.attach(afterRestart)
        await waitForCheck(adapter: afterRestart, session: reopened)
        XCTAssertFalse(afterRestart.hasLoadedVideo)
        XCTAssertEqual(reopened.state.state, .failed)
        reopened.detach()
    }
}


extension PublicLocalLibraryFlowTests {
    func testLibraryIsPlaylistUnionAndClearingPlaylistsHidesCachedVideos() throws {
        let url = try store()
        let session = PublicYouTubeSession(storeURL: url)
        session.open(try VideoID("abcdefghijk"), title: "Playlist member")
        let member = try XCTUnwrap(session.currentTrack)
        session.toggleFavorite(member.id)
        session.open(try VideoID("lmnopqrstuv"), title: "Saved cache only")
        let orphan = try XCTUnwrap(session.currentTrack)
        session.toggleFavorite(orphan.id)
        XCTAssertTrue(session.createPlaylist("First", trackIDs: [member.id]))
        XCTAssertTrue(session.createPlaylist("Second", trackIDs: [member.id]))
        XCTAssertEqual(session.libraryTracks.map(\.id), [member.id], "Duplicate membership must not duplicate Library rows")
        XCTAssertEqual(session.libraryFavorites.map(\.id), [member.id])
        session.clearLibraryItems(.favorites)
        XCTAssertTrue(session.libraryFavorites.isEmpty)
        XCTAssertTrue(session.favorites.contains { $0.id == orphan.id }, "Scoped clear keeps cached nonmembers")
        session.clearLibraryItems(.playlists)
        XCTAssertTrue(session.libraryTracks.isEmpty)
        XCTAssertTrue(session.libraryFavorites.isEmpty)
        XCTAssertTrue(session.libraryHistory.isEmpty)
        XCTAssertEqual(session.tracks.count, 2, "Playlist clear hides metadata without silently deleting it")
        let restored = PublicYouTubeSession(storeURL: url)
        XCTAssertTrue(restored.libraryTracks.isEmpty)
        XCTAssertEqual(restored.tracks.count, 2)
    }
}

extension PublicYouTubeFlowTests {
    func testMusicHomeContinuationIgnoresCarouselTokensAndFindsPageToken() {
        let carousel: [String: Any] = ["musicCarouselShelfRenderer": ["continuations": [["nextContinuationData": ["continuation": "carousel-only"]]]]]
        XCTAssertNil(PublicMusicHomeService.pageContinuation(carousel))
        let page: [String: Any] = ["contents": ["sectionListRenderer": ["contents": [carousel], "continuations": [["nextContinuationData": ["continuation": "page-two"]]]]]]
        XCTAssertEqual(PublicMusicHomeService.pageContinuation(page), "page-two")
        let next: [String: Any] = ["continuationContents": ["sectionListContinuation": ["continuations": [["nextContinuationData": ["continuation": "page-three"]]]]]]
        XCTAssertEqual(PublicMusicHomeService.pageContinuation(next), "page-three")
    }
    func testMusicHomeNormalizesRealEndpointsAndRequiresLoginEvidence() {
        let json: [String: Any] = ["contents": [["musicCarouselShelfRenderer": [
            "header": ["musicCarouselShelfBasicHeaderRenderer": ["title": ["runs": [["text": "Personal shelf"]]]]],
            "contents": [["musicTwoRowItemRenderer": ["title": ["runs": [["text": "A song"]]], "navigationEndpoint": ["watchEndpoint": ["videoId": "abcdefghijk"]]]],
                         ["musicTwoRowItemRenderer": ["title": ["runs": [["text": "A playlist"]]], "navigationEndpoint": ["watchPlaylistEndpoint": ["playlistId": "PLfixture"]]]]]
        ]]]]
        let sections = PublicMusicHomeService.parse(json)
        XCTAssertEqual(sections.map(\.title), ["Personal shelf"])
        XCTAssertEqual(sections.first?.cards.first?.videoID, "abcdefghijk")
        XCTAssertEqual(sections.first?.cards.last?.destination.absoluteString, "https://music.youtube.com/playlist?list=PLfixture")
        XCTAssertNil(sections.first?.cards.last?.videoID)
        XCTAssertFalse(PublicMusicHomeService.confirmsSignedIn(json), "An OAuth request alone is not proof of account recommendations")
        XCTAssertTrue(PublicMusicHomeService.confirmsSignedIn(["responseContext": ["serviceTrackingParams": [["params": [["key": "logged_in", "value": "1"]]]]]]))
    }
}

private struct SongMetadataTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        HTTPResponse(status: 200, body: Data(#"{"items":[{"id":"dQw4w9WgXcQ","snippet":{"title":"Never Gonna Give You Up","channelTitle":"Rick Astley - Topic"}}]}"#.utf8))
    }
}
@MainActor final class PublicSongMetadataTests: XCTestCase {
    func testColdQueueAndHistoryReferencesHydrateSongNameAndCreatorWithoutChangingMembership() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("library.sqlite")
        let first = PublicYouTubeSession(storeURL: url)
        first.open(try VideoID("dQw4w9WgXcQ"), title: "Never Gonna Give You Up", metadataFetchedAt: Date(), artist: "Rick Astley")
        let track = try XCTUnwrap(first.currentTrack)
        first.createPlaylist("My playlist", trackIDs: [track.id])
        let catalog = YouTubeDataCatalog(apiKey: "test", transport: SongMetadataTransport())
        let restored = PublicYouTubeSession(storeURL: url, catalogOverride: catalog)
        XCTAssertEqual(restored.currentTrack?.displayTitle, "Song details unavailable")
        await restored.hydrateDisplayMetadata()
        XCTAssertEqual(restored.currentTrack?.displayTitle, "Never Gonna Give You Up")
        XCTAssertEqual(restored.currentTrack?.displayArtist, "Rick Astley")
        XCTAssertEqual(restored.playlists.first?.trackIDs, [track.id])
        XCTAssertEqual(restored.queue.snapshot.current?.trackID, track.id)
    }
}
