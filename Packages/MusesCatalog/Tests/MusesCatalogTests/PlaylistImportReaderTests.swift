import XCTest
@testable import MusesCatalog

@MainActor final class PlaylistImportReaderTests: XCTestCase {
    private func metadata() -> CatalogPage {
        .init(items: [.init(kind: .playlist, id: "PLremote", title: "Original playlist name", channelID: nil, thumbnailURL: nil)], nextPageToken: nil)
    }
    private func page(_ second: Bool) -> CatalogPage {
        .init(items: [.init(kind: .video, id: second ? "M7lc1UVf-VE" : "dQw4w9WgXcQ", title: "Temporary", channelID: nil, thumbnailURL: nil, listEntryID: second ? "two" : "one")], nextPageToken: second ? nil : "next")
    }
    func testOneCallReadsMetadataAndAllPages() async throws {
        let reader = PlaylistImportReader()
        var requests: [String] = []
        try await reader.readAll(playlistID: "PLremote") { contents, token in
            requests.append(contents ? token ?? "first" : "metadata")
            return contents ? self.page(token != nil) : self.metadata()
        }
        XCTAssertEqual(requests, ["metadata", "first", "next"])
        XCTAssertTrue(reader.draft.complete)
        XCTAssertEqual(reader.draft.items.count, 2)
        XCTAssertEqual(reader.metadata?.title, "Original playlist name")
    }
    func testFailureRetainsCursorButCannotCompleteUntilRetry() async throws {
        let reader = PlaylistImportReader()
        do {
            try await reader.readAll(playlistID: "PLremote") { contents, token in
                if token != nil { throw URLError(.notConnectedToInternet) }
                return contents ? self.page(false) : self.metadata()
            }
            XCTFail("Expected failure")
        } catch { }
        XCTAssertFalse(reader.draft.complete)
        XCTAssertEqual(reader.draft.items.count, 1)
        var requests = 0
        try await reader.readAll(playlistID: "PLremote") { contents, token in
            requests += 1
            XCTAssertTrue(contents); XCTAssertEqual(token, "next")
            return self.page(true)
        }
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(reader.draft.items.count, 2)
        XCTAssertTrue(reader.draft.complete)
    }
    func testCancelledFinalResponseCannotBecomeImportable() async {
        let reader = PlaylistImportReader()
        let task = Task { @MainActor in
            try await reader.readAll(playlistID: "PLremote") { contents, token in
                if token != nil { withUnsafeCurrentTask { $0?.cancel() } }
                return contents ? self.page(token != nil) : self.metadata()
            }
        }
        do { try await task.value; XCTFail("Expected cancellation") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertFalse(reader.draft.complete)
        XCTAssertEqual(reader.draft.items.count, 1)
    }
}

extension PlaylistImportReaderTests {
    private func ownedPage(_ id: String, next: String?) -> CatalogPage {
        .init(items: [.init(kind: .playlist, id: id, title: id, channelID: nil, thumbnailURL: nil)], nextPageToken: next)
    }
    func testOwnedListLoadsEveryPageWithoutAnotherAction() async throws {
        let reader = OwnedPlaylistReader()
        var calls = 0
        try await reader.readAll { token in
            calls += 1
            return self.ownedPage(token == nil ? "PLfirst" : "PLsecond", next: token == nil ? "next" : nil)
        }
        XCTAssertEqual(calls, 2)
        XCTAssertTrue(reader.complete)
        XCTAssertEqual(reader.items.map(\.id), ["PLfirst", "PLsecond"])
    }
    func testOwnedListFailureIsPartialAndRetryResumesCursor() async throws {
        let reader = OwnedPlaylistReader()
        do {
            try await reader.readAll { token in
                if token != nil { throw URLError(.notConnectedToInternet) }
                return self.ownedPage("PLfirst", next: "next")
            }
            XCTFail("Expected failure")
        } catch { }
        XCTAssertFalse(reader.complete)
        XCTAssertEqual(reader.items.count, 1)
        try await reader.readAll { token in
            XCTAssertEqual(token, "next")
            return self.ownedPage("PLsecond", next: nil)
        }
        XCTAssertTrue(reader.complete)
        XCTAssertEqual(reader.items.count, 2)
    }
    func testOwnedListCyclesAndPageLimitNeverClaimComplete() async {
        let cycle = OwnedPlaylistReader()
        do {
            try await cycle.readAll { token in self.ownedPage(token == nil ? "PLfirst" : "PLsecond", next: "cycle") }
            XCTFail("Expected cursor cycle failure")
        } catch { }
        XCTAssertFalse(cycle.complete)
        XCTAssertEqual(cycle.items.count, 1)
        let bounded = OwnedPlaylistReader()
        var calls = 0
        do {
            try await bounded.readAll { _ in
                calls += 1
                return self.ownedPage("PL\(calls)", next: "page\(calls)")
            }
            XCTFail("Expected limit")
        } catch { XCTAssertTrue(error is PlaylistImportReadError) }
        XCTAssertEqual(calls, 100)
        XCTAssertFalse(bounded.complete)
        XCTAssertEqual(bounded.items.count, 100)
    }
    func testOwnedListCancellationDiscardsInFlightResponse() async {
        let reader = OwnedPlaylistReader()
        let task = Task { @MainActor in
            try await reader.readAll { _ in
                withUnsafeCurrentTask { $0?.cancel() }
                return self.ownedPage("PLcancelled", next: nil)
            }
        }
        do { try await task.value; XCTFail("Expected cancellation") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertFalse(reader.complete)
        XCTAssertTrue(reader.items.isEmpty)
    }
}
