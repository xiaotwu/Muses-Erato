import Foundation
import AVFoundation

/// 统一管理 iOS AVAudioSession 生命周期、音频打断、路由变更以及系统音频服务崩溃自愈。
@MainActor
final class AudioSessionCoordinator {
    private weak var playbackService: PlaybackService?
    private weak var engine: (any PlayerEngine)?
    private nonisolated(unsafe) var observerTokens: [any NSObjectProtocol] = []

    /// 打断发生前，用户是否处于播放状态
    private(set) var wasPlayingBeforeInterruption: Bool = false

    init(playbackService: PlaybackService, engine: any PlayerEngine, configureAudioSession: Bool = true) {
        self.playbackService = playbackService
        self.engine = engine
        if configureAudioSession {
            setupAudioSession()
        }
        registerNotifications()
    }

    deinit {
        observerTokens.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Audio Session 配置

    func setupAudioSession() {
        #if os(iOS)
        // 跳过测试环境
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              ProcessInfo.processInfo.environment["XCTestBundlePath"] == nil,
              ProcessInfo.processInfo.environment["XCInjectBundleInto"] == nil,
              NSClassFromString("XCTestCase") == nil else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            // 启用后台播放，允许与 AirPlay / 蓝牙耳机协同
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            AppLog.for("AudioSessionCoordinator").error("AVAudioSession 激活失败: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - 系统通知注册与处理

    private func registerNotifications() {
        #if os(iOS)
        let nc = NotificationCenter.default

        // 1. 监听音频打断 (电话、FaceTime、Siri、闹钟等)
        let interruptionToken = nc.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            nonisolated(unsafe) let note = note
            MainActor.assumeIsolated {
                self?.handleInterruption(notification: note)
            }
        }

        // 2. 监听音频输出路由变更 (耳机断开、AirPods 没电/入盒)
        let routeChangeToken = nc.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            nonisolated(unsafe) let note = note
            MainActor.assumeIsolated {
                self?.handleRouteChange(notification: note)
            }
        }

        // 3. 监听系统底层音频守护进程 (mediaserverd) 崩溃重置
        let resetToken = nc.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            nonisolated(unsafe) let note = note
            MainActor.assumeIsolated {
                self?.handleMediaServicesWereReset(notification: note)
            }
        }

        observerTokens = [interruptionToken, routeChangeToken, resetToken]
        #endif
    }

    // MARK: - 业务逻辑处理器

    /// 处理音频打断
    func handleInterruption(notification: Notification) {
        #if os(iOS)
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            // 打断开始：记录被打断前的状态并暂停
            wasPlayingBeforeInterruption = playbackService?.state.isPlaying ?? false
            playbackService?.pause()
            AppLog.for("AudioSessionCoordinator").info("音频被打断，已记录恢复标志并执行暂停")

        case .ended:
            // 打断结束：检查系统建议与之前的状态
            guard wasPlayingBeforeInterruption else { return }
            wasPlayingBeforeInterruption = false

            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // 非测试环境下重新激活会话
                    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil &&
                       NSClassFromString("XCTestCase") == nil {
                        do {
                            try AVAudioSession.sharedInstance().setActive(true)
                        } catch {
                            AppLog.for("AudioSessionCoordinator").error("打断结束后重新激活 Session 失败: \(error)")
                        }
                    }
                    playbackService?.play()
                    AppLog.for("AudioSessionCoordinator").info("音频打断结束，Session 已恢复并继续播放")
                }
            }
        @unknown default:
            break
        }
        #endif
    }

    /// 处理输出路由变化（防外放保护）
    func handleRouteChange(notification: Notification) {
        #if os(iOS)
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        // 当旧设备失效（如耳机拔出、AirPods 断开）时必须暂停
        if reason == .oldDeviceUnavailable {
            if let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                let hasHeadphone = previousRoute.outputs.contains { desc in
                    desc.portType == .headphones ||
                    desc.portType == .bluetoothA2DP ||
                    desc.portType == .bluetoothLE ||
                    desc.portType == .bluetoothHFP ||
                    desc.portType == .usbAudio
                }
                if hasHeadphone {
                    playbackService?.pause()
                    AppLog.for("AudioSessionCoordinator").info("检测到耳机断开连接，已自动暂停播放以防止外放")
                }
            }
        }
        #endif
    }

    /// 处理系统音频服务重置 (mediaserverd 崩溃自愈)
    func handleMediaServicesWereReset(notification: Notification) {
        AppLog.for("AudioSessionCoordinator").warning("检测到系统 mediaserverd 重置，开始执行自愈重构...")
        setupAudioSession()
        if let recoverable = engine as? AudioGraphRecoverable {
            recoverable.rebuildAudioGraph()
        }
    }
}

/// 支持音频图在 mediaserverd 崩溃后自愈重建的协议
@MainActor
protocol AudioGraphRecoverable: AnyObject {
    func rebuildAudioGraph()
}
