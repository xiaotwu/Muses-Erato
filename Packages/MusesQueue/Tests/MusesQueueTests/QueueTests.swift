import XCTest
import MusesDomain
@testable import MusesQueue

final class QueueTests: XCTestCase {
    private func entry(_ value: Int, instance: Int) throws -> QueueEntry {
        try QueueEntry(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", instance))!, trackID: TrackID("00000000-0000-0000-0000-000000000001"), source: .youtubeVideo(VideoID("dQw4w9WgXcQ")))
    }
    func testRepeatedTrackIsAllowedButEntryIdentityIsUnique() throws {
        let a = try entry(1, instance: 1), b = try entry(1, instance: 2)
        var queue = try PlaybackQueue()
        try queue.playNow(a); try queue.append(b)
        XCTAssertEqual(queue.snapshot.current?.trackID, queue.snapshot.upcoming.first?.trackID)
        XCTAssertThrowsError(try queue.append(b))
        XCTAssertEqual(try queue.next()?.id, b.id)
        XCTAssertEqual(try queue.previous()?.id, a.id)
    }
    func testShuffleRoundTripAndRestoreNeverAutoPlays() throws {
        var queue = try PlaybackQueue()
        for i in 1...6 { try queue.append(entry(i, instance: i)) }
        try queue.setShuffle(true, seed: 42)
        let order = queue.snapshot.upcoming.map(\.id)
        let persisted = try JSONEncoder().encode(queue.snapshot)
        let restored = try PlaybackQueue(snapshot: JSONDecoder().decode(QueueSnapshot.self, from: persisted))
        XCTAssertEqual(restored.snapshot.upcoming.map(\.id), order)
        XCTAssertEqual(restored.snapshot.intent, .pause)
        XCTAssertEqual(restored.snapshot.shuffleSeed, 42)
        var second = try PlaybackQueue()
        for i in 1...6 { try second.append(entry(i, instance: i)) }
        try second.setShuffle(true, seed: 42)
        XCTAssertEqual(second.snapshot.upcoming.map(\.id), order)
    }
    func testGenerationChangesOnTransitionsAndRejectsDuplicateSnapshotIDs() throws {
        let a = try entry(1, instance: 1)
        var queue = try PlaybackQueue()
        try queue.playNow(a)
        let generation = queue.snapshot.generation
        try queue.setRepeat(.one)
        XCTAssertGreaterThan(queue.snapshot.generation, generation)
        XCTAssertEqual(try queue.next()?.id, a.id)
        XCTAssertThrowsError(try PlaybackQueue(snapshot: QueueSnapshot(current: a, upcoming: [a])))
    }
}
