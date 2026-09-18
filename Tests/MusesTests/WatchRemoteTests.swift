import XCTest
@testable import Muses

final class WatchRemoteTests: XCTestCase {

    func testCommandRoundTripIncludesPlayIndex() {
        let encoded = WatchRemoteCodec.encodeCommand(.init(command: .playIndex, index: 3))
        let decoded = WatchRemoteCodec.decodeCommand(encoded)
        XCTAssertEqual(decoded?.command, .playIndex)
        XCTAssertEqual(decoded?.index, 3)
        XCTAssertNil(WatchRemoteCodec.decodeCommand(["cmd": "not-a-command"]))
    }

    func testLaunchAndPauseCommandsHaveNoIndex() {
        for command in [WatchRemoteCommand.launch, .pause, .play, .next, .previous] {
            let decoded = WatchRemoteCodec.decodeCommand(WatchRemoteCodec.encodeCommand(.init(command: command)))
            XCTAssertEqual(decoded?.command, command)
            XCTAssertNil(decoded?.index)
        }
    }

    func testValidatedPlayIndexRejectsOutOfRange() {
        XCTAssertEqual(WatchRemoteCodec.validatedPlayIndex(0, queueCount: 2), 0)
        XCTAssertEqual(WatchRemoteCodec.validatedPlayIndex(1, queueCount: 2), 1)
        XCTAssertNil(WatchRemoteCodec.validatedPlayIndex(-1, queueCount: 2))
        XCTAssertNil(WatchRemoteCodec.validatedPlayIndex(2, queueCount: 2))
        XCTAssertNil(WatchRemoteCodec.validatedPlayIndex(0, queueCount: 0))
    }

    func testStatePeekingNeighbors() {
        let queue = [
            WatchQueueItemSnapshot(id: "a", title: "One", artist: "A"),
            WatchQueueItemSnapshot(id: "b", title: "Two", artist: "B"),
            WatchQueueItemSnapshot(id: "c", title: "Three", artist: "C")
        ]
        var state = WatchRemoteState(
            trackId: "b",
            title: "Two",
            artist: "B",
            isPlaying: true,
            position: 12,
            duration: 180,
            currentIndex: 1,
            queue: queue,
            companionRunning: true,
            updatedAt: Date()
        )
        XCTAssertEqual(state.previousItem?.id, "a")
        XCTAssertEqual(state.nextItem?.id, "c")
        XCTAssertTrue(state.hasTrack)

        state.currentIndex = 0
        XCTAssertNil(state.previousItem)
        XCTAssertEqual(state.nextItem?.id, "b")

        state.currentIndex = 2
        XCTAssertEqual(state.previousItem?.id, "b")
        XCTAssertNil(state.nextItem)
    }

    func testReplyRoundTripKeepsArtwork() throws {
        let state = WatchRemoteState(
            trackId: "id",
            title: "Song",
            artist: "Artist",
            isPlaying: false,
            position: 0,
            duration: 1,
            currentIndex: 0,
            queue: [WatchQueueItemSnapshot(id: "id", title: "Song", artist: "Artist")],
            companionRunning: true,
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        let art = Data([0xFF, 0xD8, 0xFF])
        let reply = WatchRemoteCodec.reply(state: state, artwork: art)
        let parsed = WatchRemoteCodec.parseReply(reply)
        XCTAssertEqual(parsed.0?.title, "Song")
        XCTAssertEqual(parsed.0?.isPlaying, false)
        XCTAssertEqual(parsed.1, art)
    }

    @MainActor
    func testPhoneWatchLaunchReportsCompanionQueue() async {
        let playback = PlaybackService(engine: FakePlayerEngine(), queue: QueueService())
        let first = WatchRemoteTests.track("First")
        let second = WatchRemoteTests.track("Second")
        playback.playTrack(first, context: [first, second], from: .songs)
        try? await Task.sleep(nanoseconds: 40_000_000)
        playback.pause()

        let session = PhoneWatchSession(playback: playback)
        let reply = session.handle(WatchRemoteCodec.encodeCommand(.init(command: .launch)))
        let state = WatchRemoteCodec.parseReply(reply).0
        XCTAssertEqual(state?.title, "First")
        XCTAssertEqual(state?.queue.count, 2)
        XCTAssertEqual(state?.companionRunning, true)
        XCTAssertFalse(state?.isPlaying ?? true)
    }

    @MainActor
    func testPhoneWatchPauseAndSkipStayOnPhoneQueue() async {
        let playback = PlaybackService(engine: FakePlayerEngine(), queue: QueueService())
        let first = WatchRemoteTests.track("First")
        let second = WatchRemoteTests.track("Second")
        playback.playTrack(first, context: [first, second], from: .songs)
        try? await Task.sleep(nanoseconds: 40_000_000)
        let session = PhoneWatchSession(playback: playback)

        _ = session.handle(WatchRemoteCodec.encodeCommand(.init(command: .pause)))
        XCTAssertFalse(playback.state.isPlaying)

        _ = session.handle(WatchRemoteCodec.encodeCommand(.init(command: .next)))
        try? await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertEqual(playback.queue.current()?.track.title, "Second")

        _ = session.handle(WatchRemoteCodec.encodeCommand(.init(command: .playIndex, index: 0)))
        try? await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertEqual(playback.queue.currentIndex, 0)
        XCTAssertNil(WatchRemoteCodec.validatedPlayIndex(9, queueCount: playback.queue.items.count))
    }

    private static func track(_ title: String) -> TrackSnapshot {
        TrackSnapshot(
            id: UUID(),
            title: title,
            artist: "Artist",
            albumTitle: nil,
            durationSeconds: 180,
            youTubeId: "abcdefghijk",
            artworkUrl: nil,
            sampleRate: nil,
            bitDepth: nil,
            codec: nil,
            isLossless: false
        )
    }
}
