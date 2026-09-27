import Foundation
import MediaPlayer
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import UserNotifications

/// Manages MPNowPlayingInfoCenter (lock screen/Control Center metadata) and
/// MPRemoteCommandCenter (media keys). Syncs PlaybackService.state → nowPlayingInfo
/// over a single lifecycle; bound remote commands forward back into PlaybackService.
/// Optional: posts a local notification on track change (opt-in via @AppStorage
/// PrefKey.notificationsTrackChange).
@MainActor
final class NowPlayingManager {
    let playback: PlaybackService
    /// `likeCommand` needs the library; `changeRepeatMode/changeShuffleMode` need the queue.
    /// Both optional: nil in tests or when unwired, in which case the corresponding remote
    /// commands are simply not bound (never fabricated).
    private let library: LibraryService?
    private let queue: QueueService?
    private let publishInfo: ([String: Any]) -> Void
    private(set) var observationLifecycleStartCount = 0
    private var lastNotifiedTrackId: UUID?
    private var eventSubscription: UUID?
    private(set) var artworkLoadTask: Task<Void, Never>?
    private(set) var currentArtwork: MPMediaItemArtwork?

    init(_ playback: PlaybackService,
         library: LibraryService? = nil,
         queue: QueueService? = nil,
         bindsRemoteCommands: Bool = true,
         publishInfo: @escaping ([String: Any]) -> Void = {
             MPNowPlayingInfoCenter.default().nowPlayingInfo = $0
         }) {
        self.playback = playback
        self.library = library
        self.queue = queue
        self.publishInfo = publishInfo
        if bindsRemoteCommands {
            bindCommands()
        }
        startObserving()
    }

    deinit {
        if let sub = eventSubscription {
            let bus = playback.eventBus
            Task { @MainActor in
                bus.unsubscribe(sub)
            }
        }
        artworkLoadTask?.cancel()
    }

    // MARK: - 纯事件驱动监听 (彻底消灭 250ms Polling Loop)

    func startObserving() {
        guard eventSubscription == nil else { return }
        observationLifecycleStartCount += 1
        eventSubscription = playback.eventBus.subscribe { [weak self] event in
            self?.handlePlaybackEvent(event)
        }
        if let track = playback.state.track {
            loadArtwork(for: track)
        }
        updateNowPlayingInfo()
    }

    private func handlePlaybackEvent(_ event: PlaybackEvent) {
        switch event {
        case .trackStarted(let track):
            currentArtwork = nil
            loadArtwork(for: track)
            updateNowPlayingInfo()
            sendTrackChangeNotificationIfNeeded(for: track)
        case .trackPaused, .trackResumed, .trackSeeked, .trackSkipped:
            updateNowPlayingInfo()
        case .trackStopped, .trackCompleted:
            if playback.state.track == nil {
                artworkLoadTask?.cancel()
                currentArtwork = nil
            }
            updateNowPlayingInfo()
        default:
            break
        }
    }

    // MARK: - 锁屏信息构造 (依赖系统硬件插值，无需定时刷新)

    func updateNowPlayingInfo() {
        var info: [String: Any] = [:]
        let state = playback.state

        if let track = state.track {
            info[MPMediaItemPropertyTitle] = track.title
            info[MPMediaItemPropertyArtist] = track.artist
            if let album = track.albumTitle {
                info[MPMediaItemPropertyAlbumTitle] = album
            }
            info[MPMediaItemPropertyPlaybackDuration] = state.duration
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = state.position
            // playbackRate: 1.0 (播放时系统自动向前插值走针) 或 0.0 (暂停)
            info[MPNowPlayingInfoPropertyPlaybackRate] = state.isPlaying ? 1.0 : 0.0

            if let artwork = currentArtwork {
                info[MPMediaItemPropertyArtwork] = artwork
            }
        }

        publishInfo(info)
    }

    /// Alias for backwards compatibility
    func updateInfo() {
        updateNowPlayingInfo()
    }

    // MARK: - 锁屏高清封面异步加载

    private func loadArtwork(for track: TrackSnapshot) {
        artworkLoadTask?.cancel()
        guard let urlString = track.artworkUrl, let url = URL(string: urlString) else { return }

        artworkLoadTask = Task { [weak self] in
            #if canImport(UIKit)
            let image: UIImage?
            if let cached = ImageLoader.shared.cachedImage(for: url) {
                image = cached
            } else {
                let task = ImageLoader.shared.load(url)
                image = await task.value
            }

            guard !Task.isCancelled, let finalImage = image else { return }
            let artwork = MPMediaItemArtwork(boundsSize: finalImage.size) { _ in finalImage }
            self?.currentArtwork = artwork
            self?.updateNowPlayingInfo()
            #endif
        }
    }

    // MARK: - Track-change notifications

    private func sendTrackChangeNotificationIfNeeded(for track: TrackSnapshot) {
        guard track.id != lastNotifiedTrackId else { return }
        lastNotifiedTrackId = track.id
        let enabled = UserDefaults.standard.bool(forKey: PrefKey.notificationsTrackChange)
        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = track.title
        content.body = track.artist
        content.sound = nil
        let request = UNNotificationRequest(
            identifier: "muses.track.\(UUID().uuidString)",
            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func sendTrackChangeNotification(title: String, body: String) {
        let enabled = UserDefaults.standard.bool(forKey: PrefKey.notificationsTrackChange)
        guard enabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil
        let request = UNNotificationRequest(
            identifier: "muses.track.\(UUID().uuidString)",
            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Requests notification authorization (called when the user first enables notifications).
    func requestNotificationAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert])) ?? false
        return granted
    }

    // MARK: - Remote command wiring

    private func bindCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.handleRemotePlay() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.handleRemotePause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.handleRemoteToggle() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playback.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playback.previous() }
            return .success
        }

        // Scrubber drag
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in self?.playback.seek(to: posEvent.positionTime) }
            return .success
        }

        // Skip forward/backward ±15s
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.playback.seek(to: min(self.playback.state.duration,
                                           self.playback.state.position + 15))
            }
            return .success
        }
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.playback.seek(to: max(0, self.playback.state.position - 15))
            }
            return .success
        }

        // Complete the like / repeat / shuffle remote commands.
        // Wire them only when library/queue are attached; skip otherwise — never fabricate.
        if library != nil {
            center.likeCommand.addTarget { [weak self] _ in
                Task { @MainActor in self?.handleLike() }
                return .success
            }
        }
        if queue != nil {
            center.changeRepeatModeCommand.addTarget { [weak self] event in
                guard let self,
                      let ev = event as? MPChangeRepeatModeCommandEvent else {
                    return .commandFailed
                }
                Task { @MainActor in self.handleChangeRepeat(ev.repeatType) }
                return .success
            }
            center.changeShuffleModeCommand.addTarget { [weak self] event in
                guard let self,
                      let ev = event as? MPChangeShuffleModeCommandEvent else {
                    return .commandFailed
                }
                Task { @MainActor in self.queue?.toggleShuffle() }
                _ = ev   // consume the event; shuffle state is owned by the queue
                return .success
            }
        }
    }

    /// Explicit remote actions are deliberately separate from toggle. Media
    /// services may repeat play/pause commands, and both must remain idempotent.
    func handleRemotePlay() {
        playback.play()
    }

    func handleRemotePause() {
        playback.pause()
    }

    func handleRemoteToggle() {
        playback.toggle()
    }

    // MARK: - Remote command handling

    private func handleLike() {
        guard let library, let id = playback.state.track?.id else { return }
        library.toggleLike(id: id)
    }

    private func handleChangeRepeat(_ type: MPRepeatType) {
        guard let queue else { return }
        queue.setRepeat(Self.repeatMode(from: type, current: queue.repeatMode))
    }

    /// MPRepeatType → RepeatMode: direct mapping of off/all/one. The system has no `.default`; keep the mapping deterministic.
    static func repeatMode(from type: MPRepeatType, current: RepeatMode) -> RepeatMode {
        switch type {
        case .off:        return .off
        case .all:        return .all
        case .one:        return .one
        @unknown default: return current
        }
    }
}
