import Foundation
import AVFoundation
import MediaPlayer
import UIKit
#if MUSES_NATIVE_PLAYBACK
@preconcurrency import YouTubeKit
#endif

/// IPA/Debug composition only. No OAuth credentials, remote extractor, or media downloads.
@MainActor @Observable
final class ExperimentalNativePlayback {
    enum Event { case playing, paused, buffering, time(Double, Double), ended, failed(String) }
    static var available: Bool {
        #if MUSES_NATIVE_PLAYBACK
        true
        #else
        false
        #endif
    }
    @ObservationIgnored let player = AVPlayer()
    @ObservationIgnored private let resolveStream: @MainActor (String) async throws -> URL
    private var hasNext = false
    @ObservationIgnored var onEvent: ((Event) -> Void)?
    @ObservationIgnored var onNext: (() -> Void)?
    @ObservationIgnored var onPrevious: (() -> Void)?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var deadline: Task<Void, Never>?
    @ObservationIgnored private var artworkTask: Task<Void, Never>?
    @ObservationIgnored private var timeToken: Any?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var itemObservation: NSKeyValueObservation?
    @ObservationIgnored private var notifications: [NSObjectProtocol] = []
    @ObservationIgnored private var commandTokens: [(MPRemoteCommand, Any)] = []
    private var generation = UUID()
    private var resumeAfterInterruption = false
    private(set) var loaded = false
    private(set) var wantsPlayback = false
    private var metadata: [String: Any] = [:]

    init(resolveStream: @escaping @MainActor (String) async throws -> URL = ExperimentalNativePlayback.resolveLocalStream) {
        self.resolveStream = resolveStream
        statusObservation = Self.observePlayer(player) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.loaded else { return }
                switch self.player.timeControlStatus {
                case .playing: self.onEvent?(.playing)
                case .paused: self.onEvent?(.paused)
                case .waitingToPlayAtSpecifiedRate: self.onEvent?(.buffering)
                @unknown default: break
                }
                self.publish()
            }
        }
        timeToken = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.loaded else { return }
                let position = self.player.currentTime().seconds
                let duration = self.player.currentItem?.duration.seconds ?? 0
                guard position.isFinite else { return }
                self.onEvent?(.time(max(0, position), duration.isFinite ? max(0, duration) : 0))
                self.publish()
            }
        }
        let center = NotificationCenter.default
        notifications.append(center.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] notice in
            let item = notice.object as? AVPlayerItem
            Task { @MainActor [weak self] in
                guard let self, item === self.player.currentItem else { return }
                self.wantsPlayback = false; self.publish(); self.onEvent?(.ended)
            }
        })
        notifications.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notice in
            let type = notice.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = notice.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor [weak self] in
                guard let self else { return }
                if type == AVAudioSession.InterruptionType.began.rawValue {
                    self.resumeAfterInterruption = self.wantsPlayback; self.pause()
                } else if self.resumeAfterInterruption && options & AVAudioSession.InterruptionOptions.shouldResume.rawValue != 0 {
                    self.resumeAfterInterruption = false; self.play()
                }
            }
        })
        notifications.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notice in
            let reason = notice.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor [weak self] in
                if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { self?.pause() }
            }
        })
    }

    func load(videoID: String, title: String, artist: String, start: Double = 0, autoplay: Bool = true) {
        stop()
        let ticket = generation
        wantsPlayback = autoplay
        metadata = [MPMediaItemPropertyTitle: title, MPMediaItemPropertyArtist: artist]
        deadline = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(25)) } catch { return }
            guard let self, self.generation == ticket, !self.loaded else { return }
            self.fail("Audio loading timed out. Retry or use website playback.")
        }
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let url = try await self.resolveStream(videoID)
                guard !Task.isCancelled, self.generation == ticket else { return }
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .longFormAudio)
                let item = AVPlayerItem(url: url)
                self.itemObservation = Self.observeItem(item) { [weak self] item in
                    let failed = item.status == .failed
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == ticket, item === self.player.currentItem, failed else { return }
                        self.fail("Audio stream could not be played. Use website playback.")
                    }
                }
                self.player.replaceCurrentItem(with: item)
                self.loaded = true; self.deadline?.cancel(); self.deadline = nil
                self.registerCommands()
                self.loadArtwork(videoID: videoID, ticket: ticket)
                if start > 0 { self.seek(start) }
                if self.wantsPlayback { self.play() } else { self.onEvent?(.paused); self.publish() }
            } catch {
                guard !Task.isCancelled, self.generation == ticket else { return }
                self.fail("Native playback unavailable: \(error.localizedDescription). Open website playback or switch to the YouTube player.")
            }
        }
    }

    static func resolveLocalStream(_ videoID: String) async throws -> URL {
        #if MUSES_NATIVE_PLAYBACK
        let streams = try await YouTube(videoID: videoID, useOAuth: false, allowOAuthCache: false, methods: [.local]).streams
        guard let stream = streams.filterAudioOnly().filter({ $0.fileExtension == .m4a && $0.isNativelyPlayable }).highestAudioBitrateStream()
            ?? streams.filterVideoAndAudio().filter({ $0.isNativelyPlayable }).highestAudioBitrateStream() else {
            throw NSError(domain: "MusesNative", code: 1, userInfo: [NSLocalizedDescriptionKey: "No compatible audio stream"])
        }
        return stream.url
        #else
        throw NSError(domain: "MusesNative", code: 2, userInfo: [NSLocalizedDescriptionKey: "Native playback requires an experimental IPA build"])
        #endif
    }
    func updateDisplayInfo(title: String, artist: String) {
        metadata[MPMediaItemPropertyTitle] = title; metadata[MPMediaItemPropertyArtist] = artist; publish()
    }
    func updateQueueAvailability(hasNext: Bool) {
        self.hasNext = hasNext
        if loaded { MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = hasNext }
    }

    func play() {
        wantsPlayback = true
        guard loaded else { return }
        do { try AVAudioSession.sharedInstance().setActive(true); player.play(); publish() }
        catch { fail("Audio session could not start: \(error.localizedDescription)") }
    }
    func pause() { wantsPlayback = false; player.pause(); onEvent?(.paused); publish() }
    func seek(_ seconds: Double) {
        guard loaded, seconds.isFinite, seconds >= 0 else { return }
        let duration = player.currentItem?.duration.seconds ?? .infinity
        let target = duration.isFinite ? min(seconds, duration) : seconds
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }
    func stop() {
        generation = UUID(); deadline?.cancel(); deadline = nil; task?.cancel(); task = nil; artworkTask?.cancel(); artworkTask = nil
        loaded = false; wantsPlayback = false; resumeAfterInterruption = false; itemObservation = nil
        player.pause(); player.replaceCurrentItem(with: nil)
        for (command, token) in commandTokens { command.removeTarget(token); command.isEnabled = false }
        commandTokens = []; metadata = [:]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    private func fail(_ message: String) { stop(); onEvent?(.failed(message)) }
    private func publish() {
        guard loaded else { return }
        let position = player.currentTime().seconds
        let duration = player.currentItem?.duration.seconds ?? 0
        metadata[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position.isFinite ? max(0, position) : 0
        metadata[MPMediaItemPropertyPlaybackDuration] = duration.isFinite ? max(0, duration) : 0
        metadata[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = metadata
    }
    private func registerCommands() {
        let center = MPRemoteCommandCenter.shared()
        func register(_ command: MPRemoteCommand, _ action: @escaping @MainActor @Sendable () -> Void) {
            command.isEnabled = true
            let token = Self.remoteTarget(command, action: action)
            commandTokens.append((command, token))
        }
        register(center.playCommand) { [weak self] in self?.play() }
        register(center.pauseCommand) { [weak self] in self?.pause() }
        register(center.togglePlayPauseCommand) { [weak self] in guard let self else { return }; self.wantsPlayback ? self.pause() : self.play() }
        register(center.nextTrackCommand) { [weak self] in guard let self, self.loaded else { return }; self.onNext?() }
        register(center.previousTrackCommand) { [weak self] in guard let self, self.loaded else { return }; self.onPrevious?() }
        center.nextTrackCommand.isEnabled = hasNext
        center.changePlaybackPositionCommand.isEnabled = true
        let token = Self.positionTarget(center.changePlaybackPositionCommand) { [weak self] seconds in self?.seek(seconds) }

        commandTokens.append((center.changePlaybackPositionCommand, token))
    }
    // MediaPlayer and KVO callbacks can run on system queues. Construct the callbacks
    // outside MainActor so Swift 6 does not infer a main-executor precondition.
    nonisolated private static func observePlayer(_ player: AVPlayer, action: @escaping @MainActor @Sendable () -> Void) -> NSKeyValueObservation {
        player.observe(\.timeControlStatus, options: [.new]) { _, _ in Task { @MainActor in action() } }
    }
    nonisolated private static func observeItem(_ item: AVPlayerItem, action: @escaping @MainActor @Sendable (AVPlayerItem) -> Void) -> NSKeyValueObservation {
        item.observe(\.status, options: [.new]) { item, _ in Task { @MainActor in action(item) } }
    }
    nonisolated private static func remoteTarget(_ command: MPRemoteCommand, action: @escaping @MainActor @Sendable () -> Void) -> Any {
        command.addTarget { _ in Task { @MainActor in action() }; return .success }
    }
    nonisolated private static func positionTarget(_ command: MPChangePlaybackPositionCommand, action: @escaping @MainActor @Sendable (Double) -> Void) -> Any {
        command.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let seconds = event.positionTime
            Task { @MainActor in action(seconds) }; return .success
        }
    }
    nonisolated private static func mediaArtwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    private func loadArtwork(videoID: String, ticket: UUID) {
        artworkTask = Task { @MainActor [weak self] in
            guard let url = URL(string: "https://i.ytimg.com/vi/\(videoID)/mqdefault.jpg"),
                  let (data, _) = try? await URLSession.shared.data(from: url), data.count < 2_000_000,
                  let image = UIImage(data: data), let self, self.generation == ticket, !Task.isCancelled else { return }
            self.metadata[MPMediaItemPropertyArtwork] = Self.mediaArtwork(image)
            self.publish()
        }
    }
}
