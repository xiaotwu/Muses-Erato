import XCTest
import MediaPlayer
#if canImport(UIKit)
import UIKit
#endif
@testable import Muses

@MainActor
final class PowerAndCacheGovernanceTests: XCTestCase {

    private var fakeEngine: FakePlayerEngine!
    private var queue: QueueService!
    private var playback: PlaybackService!

    override func setUp() async throws {
        try await super.setUp()
        fakeEngine = FakePlayerEngine()
        queue = QueueService()
        playback = PlaybackService(engine: fakeEngine, queue: queue)
    }

    override func tearDown() async throws {
        playback = nil
        queue = nil
        fakeEngine = nil
        MediaFileCache.directoryOverride = nil
        try await super.tearDown()
    }

    // MARK: - 1. NowPlaying 封面与事件测试

    func testNowPlayingArtworkAndEventDriven() async throws {
        var publishedInfo: [String: Any] = [:]
        let manager = NowPlayingManager(
            playback,
            bindsRemoteCommands: false,
            publishInfo: { publishedInfo = $0 }
        )

        let trackId = UUID()
        let artURL = try XCTUnwrap(URL(string: "https://example.com/art_\(UUID().uuidString).jpg"))
        let track = TrackSnapshot(
            id: trackId,
            title: "Governance Track",
            artist: "Governance Artist",
            albumTitle: "Governance Album",
            durationSeconds: 240,
            youTubeId: "gov12345",
            artworkUrl: artURL.absoluteString,
            sampleRate: nil,
            bitDepth: nil,
            codec: nil,
            isLossless: false
        )

        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200))
        let testImage = renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        }
        ImageLoader.shared.setCachedImage(testImage, for: artURL)
        #endif

        // 模拟引擎状态与事件总线发布
        fakeEngine.state.track = track
        fakeEngine.state.duration = 240
        fakeEngine.state.position = 10
        fakeEngine.state.isPlaying = true

        playback.eventBus.post(.trackStarted(track))
        await manager.artworkLoadTask?.value

        // 断言元数据发布
        XCTAssertEqual(publishedInfo[MPMediaItemPropertyTitle] as? String, "Governance Track")
        XCTAssertEqual(publishedInfo[MPMediaItemPropertyArtist] as? String, "Governance Artist")
        XCTAssertEqual(publishedInfo[MPMediaItemPropertyAlbumTitle] as? String, "Governance Album")
        XCTAssertEqual(publishedInfo[MPMediaItemPropertyPlaybackDuration] as? Double, 240)
        XCTAssertEqual(publishedInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double, 10)
        XCTAssertEqual(publishedInfo[MPNowPlayingInfoPropertyPlaybackRate] as? Double, 1.0)

        #if canImport(UIKit)
        // 断言 MPMediaItemPropertyArtwork 成功注入
        let artwork = publishedInfo[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork
        XCTAssertNotNil(artwork, "锁屏封面应被成功加载并注入 MPMediaItemPropertyArtwork")
        #endif

        // 测试暂停事件：playbackRate 切换为 0.0
        fakeEngine.state.isPlaying = false
        playback.eventBus.post(.trackPaused(track))
        XCTAssertEqual(publishedInfo[MPNowPlayingInfoPropertyPlaybackRate] as? Double, 0.0)

        // 测试继续播放事件：playbackRate 切换为 1.0
        fakeEngine.state.isPlaying = true
        fakeEngine.state.position = 25
        playback.eventBus.post(.trackResumed(track))
        XCTAssertEqual(publishedInfo[MPNowPlayingInfoPropertyPlaybackRate] as? Double, 1.0)
        XCTAssertEqual(publishedInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double, 25)

        // 测试 Seek 事件
        fakeEngine.state.position = 80
        playback.eventBus.post(.trackSeeked(trackId: track.id, toMs: 80000))
        XCTAssertEqual(publishedInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double, 80)

        // 测试停止事件：清空歌曲时锁屏重置
        fakeEngine.state.track = nil
        fakeEngine.state.isPlaying = false
        playback.eventBus.post(.trackStopped(track, listenedMs: 80000))
        XCTAssertNil(publishedInfo[MPMediaItemPropertyTitle])
        XCTAssertNil(manager.currentArtwork)
    }

    // MARK: - 2. SleepTimer 挂钟计算测试

    func testSleepTimerWallClockCalculation() {
        let sleepTimer = SleepTimerService(playbackService: playback)

        XCTAssertFalse(sleepTimer.isActive)
        XCTAssertEqual(sleepTimer.remainingSeconds, 0)

        // 启动 30 分钟定时
        sleepTimer.start(minutes: 30)
        XCTAssertTrue(sleepTimer.isActive)
        XCTAssertEqual(sleepTimer.totalSeconds, 1800)
        XCTAssertEqual(sleepTimer.remainingSeconds, 1800, accuracy: 1.0)

        // 模拟系统后台挂起 22.5 分钟后唤醒：直接重置绝对挂钟 targetEndDate
        sleepTimer.targetEndDate = Date().addingTimeInterval(450)
        XCTAssertEqual(sleepTimer.remainingSeconds, 450, accuracy: 1.0)
        XCTAssertEqual(sleepTimer.remainingFormatted, "7:30")

        // 模拟超过 1 小时的格式化
        sleepTimer.targetEndDate = Date().addingTimeInterval(3665)
        XCTAssertEqual(sleepTimer.remainingFormatted, "1:01:05")

        // 模拟后台跨越整个定时周期已超时
        sleepTimer.targetEndDate = Date().addingTimeInterval(-60)
        XCTAssertEqual(sleepTimer.remainingSeconds, 0, "超时后剩余秒数应归零，不可出现负数漂移")

        // 取消定时器
        sleepTimer.cancel()
        XCTAssertFalse(sleepTimer.isActive)
        XCTAssertEqual(sleepTimer.remainingSeconds, 0)
        XCTAssertNil(sleepTimer.targetEndDate)
    }

    // MARK: - 3. MediaFileCache O(1) 命中测试

    func testMediaFileCacheO1Lookup() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MusesMediaCacheTest_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        MediaFileCache.directoryOverride = tempDir

        let videoId = "vid_\(UUID().uuidString.prefix(8))"
        let quality = "bestaudio"

        // 未写入前寻址应为 nil
        XCTAssertNil(MediaFileCache.existing(videoId: videoId, quality: quality))

        // 写入大于 4KB 的 m4a 测试文件
        let targetURL = MediaFileCache.file(videoId: videoId, quality: quality, ext: "m4a")
        let dummyData = Data(repeating: 0x7F, count: 8192)
        try dummyData.write(to: targetURL)

        // 设置较旧的修改时间
        let oldDate = Date().addingTimeInterval(-1000)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: targetURL.path)

        // 精准 O(1) 探测
        let foundURL = MediaFileCache.existing(videoId: videoId, quality: quality)
        XCTAssertNotNil(foundURL)
        XCTAssertEqual(foundURL?.lastPathComponent, targetURL.lastPathComponent)

        // 验证命中后更新了访问时间（修改时间），支撑 LRU
        let attrs = try FileManager.default.attributesOfItem(atPath: targetURL.path)
        if let modDate = attrs[.modificationDate] as? Date {
            XCTAssertTrue(modDate.timeIntervalSince(oldDate) > 500, "Cache 命中时应更新 modificationDate 以支撑 LRU")
        }

        // 验证其他不支持或不存在的 videoId
        XCTAssertNil(MediaFileCache.existing(videoId: "non_existent_id", quality: quality))

        // 验证 remove 方法
        MediaFileCache.remove(videoId: videoId, quality: quality)
        XCTAssertNil(MediaFileCache.existing(videoId: videoId, quality: quality))
    }

    // MARK: - 4. MediaFileCache LRU 剔除测试

    func testMediaFileCacheLRUEviction() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MusesLRUTest_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        MediaFileCache.directoryOverride = tempDir

        let fileA = tempDir.appendingPathComponent("trackA__audio.m4a")
        let fileB = tempDir.appendingPathComponent("trackB__audio.webm")
        let fileC = tempDir.appendingPathComponent("trackC__audio.mp3")

        let chunk400Bytes = Data(repeating: 0xAA, count: 400)
        try chunk400Bytes.write(to: fileA)
        try chunk400Bytes.write(to: fileB)
        try chunk400Bytes.write(to: fileC)

        let fm = FileManager.default
        let now = Date()
        // fileA 最旧 (300s 前)，fileB 居中 (200s 前)，fileC 最新 (100s 前)
        try fm.setAttributes([.modificationDate: now.addingTimeInterval(-300)], ofItemAtPath: fileA.path)
        try fm.setAttributes([.modificationDate: now.addingTimeInterval(-200)], ofItemAtPath: fileB.path)
        try fm.setAttributes([.modificationDate: now.addingTimeInterval(-100)], ofItemAtPath: fileC.path)

        XCTAssertEqual(MediaFileCache.totalBytes(), 1200)

        // 执行容量淘汰：上限 1000 字节，回退水位 80% (800 字节)
        MediaFileCache.pruneIfNeeded(maxBytes: 1000)

        // 断言：最旧的 fileA (400 字节) 被删除，总大小降为 800 字节 (<= 800 字节)
        XCTAssertFalse(fm.fileExists(atPath: fileA.path), "最旧的文件 A 应被优先淘汰")
        XCTAssertTrue(fm.fileExists(atPath: fileB.path), "较新的文件 B 应被保留")
        XCTAssertTrue(fm.fileExists(atPath: fileC.path), "最新的文件 C 应被保留")
        XCTAssertLessThanOrEqual(MediaFileCache.totalBytes(), 800)

        // 清空测试
        MediaFileCache.clearAll()
        XCTAssertEqual(MediaFileCache.totalBytes(), 0)
    }

    // MARK: - 5. NowPlayingSessionCoordinator 指纹防抖测试

    func testCoordinatorFingerprintDebouncing() async throws {
        let suite = "muses.test.debounce.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = NowPlayingSnapshotStore(defaults: defaults, containerURL: nil)
        let coordinator = NowPlayingSessionCoordinator(playback: playback, store: store)

        let trackId = UUID()
        let track = TrackSnapshot(
            id: trackId,
            title: "Debounce Title",
            artist: "Debounce Artist",
            albumTitle: "Album",
            durationSeconds: 100,
            youTubeId: "deb12345",
            artworkUrl: nil,
            sampleRate: nil,
            bitDepth: nil,
            codec: nil,
            isLossless: false
        )
        fakeEngine.state.track = track
        fakeEngine.state.isPlaying = true

        // 第一次触发事件：应当写盘
        playback.eventBus.post(.trackStarted(track))
        // 让 Task 处理完成
        try await Task.sleep(for: .milliseconds(50))

        let signature1 = coordinator.lastWidgetSignature
        XCTAssertNotNil(signature1)
        XCTAssertEqual(store.load()?.trackId, trackId.uuidString)

        // 记录当前保存的 snapshot 时间
        let savedDate1 = store.load()?.updatedAt

        // 再次触发相同状态的播放事件（数据指纹相同）
        playback.eventBus.post(.trackResumed(track))
        try await Task.sleep(for: .milliseconds(50))

        let signature2 = coordinator.lastWidgetSignature
        XCTAssertEqual(signature1, signature2, "状态未变更时指纹应当完全一致")
        let savedDate2 = store.load()?.updatedAt
        XCTAssertEqual(savedDate1, savedDate2, "指纹防抖生效，数据无变更时不应重复写入磁盘")
    }
}
