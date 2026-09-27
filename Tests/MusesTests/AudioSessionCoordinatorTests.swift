import XCTest
import AVFoundation
@testable import Muses

#if os(iOS)
private final class MockPortDescription: AVAudioSessionPortDescription {
    private let mockPortType: AVAudioSession.Port

    init(portType: AVAudioSession.Port) {
        self.mockPortType = portType
        super.init()
    }

    override var portType: AVAudioSession.Port {
        mockPortType
    }
}

private final class MockRouteDescription: AVAudioSessionRouteDescription {
    private let mockOutputs: [AVAudioSessionPortDescription]

    init(outputs: [AVAudioSessionPortDescription]) {
        self.mockOutputs = outputs
        super.init()
    }

    override var outputs: [AVAudioSessionPortDescription] {
        mockOutputs
    }
}
#endif

private final class RecoverableFakeEngine: PlayerEngine, AudioGraphRecoverable {
    let state = PlayerState()
    var onCompletion: (@MainActor () -> Void)?
    var rebuildCallCount = 0

    func load(_ track: TrackSnapshot) async throws {
        state.buffering = false
        state.isPlaying = true
    }
    func prepare(_ track: TrackSnapshot) async {}
    func playPrepared() -> Bool { false }
    func play() { state.isPlaying = true }
    func pause() { state.isPlaying = false }
    func toggle() { state.isPlaying.toggle() }
    func seek(to time: Double) { state.position = time }
    func setVolume(_ v: Float) {}
    func setEQ(_ bands: [EQBand]) {}
    var isEQAvailable: Bool { true }
    func installSpectrumTap(_ handler: @escaping (SpectrumFrame) -> Void) {}
    func removeSpectrumTap() {}

    func rebuildAudioGraph() {
        rebuildCallCount += 1
    }
}

@MainActor
final class AudioSessionCoordinatorTests: XCTestCase {

    private var fakeEngine: RecoverableFakeEngine!
    private var playbackService: PlaybackService!
    private var coordinator: AudioSessionCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        fakeEngine = RecoverableFakeEngine()
        let track = TrackSnapshot(
            id: UUID(),
            title: "Test Track",
            artist: "Test Artist",
            albumTitle: nil,
            durationSeconds: 180,
            youTubeId: "test12345",
            artworkUrl: nil,
            sampleRate: nil,
            bitDepth: nil,
            codec: nil,
            isLossless: false
        )
        fakeEngine.state.track = track
        let queue = QueueService()
        playbackService = PlaybackService(engine: fakeEngine, queue: queue)
        coordinator = AudioSessionCoordinator(
            playbackService: playbackService,
            engine: fakeEngine,
            configureAudioSession: false
        )
    }

    override func tearDown() async throws {
        coordinator = nil
        playbackService = nil
        fakeEngine = nil
        try await super.tearDown()
    }

    // MARK: - Audio Interruption Tests

    func testInterruptionBeganPausesPlayback() {
        #if os(iOS)
        playbackService.play()
        XCTAssertTrue(playbackService.state.isPlaying)

        let notification = Notification(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
            ]
        )
        NotificationCenter.default.post(notification)

        XCTAssertFalse(playbackService.state.isPlaying)
        XCTAssertTrue(coordinator.wasPlayingBeforeInterruption)
        #endif
    }

    func testInterruptionEndedWithShouldResumeRestoresPlayback() {
        #if os(iOS)
        playbackService.play()
        XCTAssertTrue(playbackService.state.isPlaying)

        // 1. 打断开始
        let beganNote = Notification(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
            ]
        )
        NotificationCenter.default.post(beganNote)
        XCTAssertFalse(playbackService.state.isPlaying)

        // 2. 打断结束并建议恢复
        let endedNote = Notification(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue
            ]
        )
        NotificationCenter.default.post(endedNote)

        XCTAssertTrue(playbackService.state.isPlaying)
        XCTAssertFalse(coordinator.wasPlayingBeforeInterruption)
        #endif
    }

    func testInterruptionEndedWithoutShouldResumeDoesNotResume() {
        #if os(iOS)
        playbackService.play()
        XCTAssertTrue(playbackService.state.isPlaying)

        // 1. 打断开始
        let beganNote = Notification(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
            ]
        )
        NotificationCenter.default.post(beganNote)
        XCTAssertFalse(playbackService.state.isPlaying)

        // 2. 打断结束但无恢复选项
        let endedNote = Notification(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                AVAudioSessionInterruptionOptionKey: UInt(0)
            ]
        )
        NotificationCenter.default.post(endedNote)

        XCTAssertFalse(playbackService.state.isPlaying)
        XCTAssertFalse(coordinator.wasPlayingBeforeInterruption)
        #endif
    }

    func testInterruptionEndedWhenNotPlayingBeforeInterruptionDoesNotPlay() {
        #if os(iOS)
        playbackService.pause()
        XCTAssertFalse(playbackService.state.isPlaying)

        // 1. 打断开始（此时原本就没在播放）
        let beganNote = Notification(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
            ]
        )
        NotificationCenter.default.post(beganNote)
        XCTAssertFalse(coordinator.wasPlayingBeforeInterruption)

        // 2. 打断结束
        let endedNote = Notification(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue
            ]
        )
        NotificationCenter.default.post(endedNote)

        XCTAssertFalse(playbackService.state.isPlaying)
        #endif
    }

    // MARK: - Route Change Tests (防外放熔断)

    func testRouteChangeOldDeviceUnavailablePausesPlayback() {
        #if os(iOS)
        playbackService.play()
        XCTAssertTrue(playbackService.state.isPlaying)

        let mockPort = MockPortDescription(portType: .headphones)
        let mockRoute = MockRouteDescription(outputs: [mockPort])

        let notification = Notification(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue,
                AVAudioSessionRouteChangePreviousRouteKey: mockRoute
            ]
        )
        NotificationCenter.default.post(notification)

        XCTAssertFalse(playbackService.state.isPlaying, "拔出耳机应触发防外放暂停")
        #endif
    }

    func testRouteChangeBluetoothDisconnectPausesPlayback() {
        #if os(iOS)
        playbackService.play()
        XCTAssertTrue(playbackService.state.isPlaying)

        let mockPort = MockPortDescription(portType: .bluetoothA2DP)
        let mockRoute = MockRouteDescription(outputs: [mockPort])

        let notification = Notification(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue,
                AVAudioSessionRouteChangePreviousRouteKey: mockRoute
            ]
        )
        NotificationCenter.default.post(notification)

        XCTAssertFalse(playbackService.state.isPlaying, "蓝牙耳机断开应触发防外放暂停")
        #endif
    }

    func testRouteChangeOtherReasonDoesNotPausePlayback() {
        #if os(iOS)
        playbackService.play()
        XCTAssertTrue(playbackService.state.isPlaying)

        let notification = Notification(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.categoryChange.rawValue
            ]
        )
        NotificationCenter.default.post(notification)

        XCTAssertTrue(playbackService.state.isPlaying, "普通路由或类别变化不应暂停播放")
        #endif
    }

    // MARK: - Media Services Were Reset Tests (mediaserverd 崩溃自愈)

    func testMediaServicesWereResetTriggersEngineRebuild() {
        #if os(iOS)
        XCTAssertEqual(fakeEngine.rebuildCallCount, 0)

        let notification = Notification(
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance()
        )
        NotificationCenter.default.post(notification)

        XCTAssertEqual(fakeEngine.rebuildCallCount, 1, "mediaserverd 重置必须触发音频图重建")
        #endif
    }

    func testYouTubeStreamEngineRebuildAudioGraphDoesNotCrash() {
        let realEngine = YouTubeStreamEngine()
        realEngine.rebuildAudioGraph()
        XCTAssertFalse(realEngine.state.isPlaying)
    }
}
