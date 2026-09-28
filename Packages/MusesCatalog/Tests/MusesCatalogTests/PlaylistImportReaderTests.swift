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
