import XCTest
import SwiftData
@testable import Muses

@MainActor
final class DataArchitectureAndCleanlinessTests: XCTestCase {

    private func makeTrackSnapshot(id: UUID = UUID(), title: String, artist: String = "Test Artist", youTubeId: String = "yt_test") -> TrackSnapshot {
        TrackSnapshot(
            id: id,
            title: title,
            artist: artist,
            albumTitle: nil,
            durationSeconds: 180,
            youTubeId: youTubeId,
            artworkUrl: nil,
            sampleRate: nil,
            bitDepth: nil,
            codec: nil,
            isLossless: false
        )
    }

    // MARK: - 1. MainContext Entity Synchronization

    func testMainContextEntitySync() throws {
        let container = try makeModelContainer(inMemory: true)
        let library = LibraryService(modelContainer: container)

        let track = Track(
            title: "Test Symphony",
            artist: "Erato Ensemble",
            youTubeId: "test_erato_001"
        )
        container.mainContext.insert(track)
        try container.mainContext.save()

        XCTAssertFalse(track.liked)
        XCTAssertFalse(library.isLiked(id: track.id))

        // Toggle like via library
        library.toggleLike(track)

        // The entity on mainContext should immediately reflect the change
        XCTAssertTrue(track.liked)
        XCTAssertTrue(library.isLiked(id: track.id))

        // Toggle like again via ID
        library.toggleLike(id: track.id)
        XCTAssertFalse(track.liked)
        XCTAssertFalse(library.isLiked(id: track.id))

        // Update metadata and verify immediate entity reflection
        library.updateTrack(
            id: track.id,
            title: "Updated Symphony",
            artist: "Erato Soloist",
            albumTitle: "Erato Masterpieces",
            albumArtist: "Erato Soloist",
            trackNo: 1,
            discNo: 1,
            year: 2026,
            genre: "Classical",
            lyrics: "Harmonies of the mind"
        )

        XCTAssertEqual(track.title, "Updated Symphony")
        XCTAssertEqual(track.artist, "Erato Soloist")
        XCTAssertEqual(track.albumTitle, "Erato Masterpieces")
        XCTAssertEqual(track.lyrics, "Harmonies of the mind")
    }

    // MARK: - 2. QueueService Debounced Persistence

    func testQueueServiceDebouncePersist() async throws {
        let container = try makeModelContainer(inMemory: true)
        let queue = QueueService()
        queue.modelContext = container.mainContext

        // Verify initial state has no QueueState persisted
        let initialRows = (try? container.mainContext.fetch(FetchDescriptor<QueueState>())) ?? []
        XCTAssertTrue(initialRows.isEmpty)

        // Rapidly push 10 items into the queue (<50ms)
        for i in 1...10 {
            let snapshot = makeTrackSnapshot(title: "Track \(i)", youTubeId: "yt_\(i)")
            queue.addToQueue(snapshot)
        }

        // Immediately check DB: debounce interval is 300ms, so it must not have persisted yet
        let immediateRows = (try? container.mainContext.fetch(FetchDescriptor<QueueState>())) ?? []
        XCTAssertTrue(immediateRows.isEmpty, "Debounced persistence must not write immediately to disk during burst enqueueing")

        // Wait 350ms to allow debounce timer to fire and complete disk write
        try await Task.sleep(for: .milliseconds(350))

        // Now the row must exist and have all 10 tracks
        let persistedRows = (try? container.mainContext.fetch(FetchDescriptor<QueueState>())) ?? []
        XCTAssertEqual(persistedRows.count, 1)

        guard let row = persistedRows.first else {
            XCTFail("Persisted row expected")
            return
        }

        let decoder = JSONDecoder()
        let persistedUpNext = (try? decoder.decode([QueueItem].self, from: Data(row.upNextJSON.utf8))) ?? []
        XCTAssertEqual(persistedUpNext.count, 10, "Debounced persistence should persist all 10 items in a single merged write")
    }

    // MARK: - 3. QueueService Flush Immediate Persistence

    func testQueueServiceFlushImmediatePersist() throws {
        let container = try makeModelContainer(inMemory: true)
        let queue = QueueService()
        queue.modelContext = container.mainContext

        let snapshot = makeTrackSnapshot(title: "Flush Track", youTubeId: "yt_flush")
        queue.addToQueue(snapshot)

        // Immediately flush without sleeping
        queue.flush()

        // Verify immediately that QueueState is written to the database
        let rows = (try? container.mainContext.fetch(FetchDescriptor<QueueState>())) ?? []
        XCTAssertEqual(rows.count, 1, "flush() must immediately persist to disk without waiting for debounce timer")

        guard let row = rows.first else {
            XCTFail("Persisted row expected after flush")
            return
        }

        let decoder = JSONDecoder()
        let persistedUpNext = (try? decoder.decode([QueueItem].self, from: Data(row.upNextJSON.utf8))) ?? []
        XCTAssertEqual(persistedUpNext.count, 1)
        XCTAssertEqual(persistedUpNext.first?.track.title, "Flush Track")
    }
}
