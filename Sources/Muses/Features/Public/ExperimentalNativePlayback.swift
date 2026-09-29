import Foundation
#if MUSES_NATIVE_PLAYBACK
import AVFoundation
import MediaPlayer
import UIKit
@preconcurrency import YouTubeKit

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
    private(set) var loadingMessage: String?
    private var retryCount = 0
    private var playbackStarted = false
    private var lastProgressPosition = 0.0
    private var lastRequest: (id: String, title: String, artist: String, start: Double)?
    private var loadingBackgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let startupTimeout: Duration
    private static var streamCache: [String: (urls: [URL], expires: Date)] = [:]
    private static var rejectedFormats: [String: Set<String>] = [:]
    private static func formatKey(_ url: URL) -> String {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "itag" })?.value ?? url.absoluteString
    }

    init(startupTimeout: Duration = .seconds(15), resolveStream: @escaping @MainActor (String) async throws -> URL = ExperimentalNativePlayback.resolveLocalStream) {
        self.startupTimeout = startupTimeout
        player.automaticallyWaitsToMinimizeStalling = false
        self.resolveStream = resolveStream
        statusObservation = Self.observePlayer(player) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.loaded else { return }
                switch self.player.timeControlStatus {
                case .playing:
                    // timeControlStatus alone can become playing before a byte is decoded.
                    if self.playbackStarted { self.onEvent?(.playing) }
                case .paused: self.onEvent?(.paused)
                case .waitingToPlayAtSpecifiedRate:
                    self.onEvent?(.buffering)
                    if self.deadline == nil { self.watchStartup(ticket: self.generation) }
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
                if self.wantsPlayback && position > self.lastProgressPosition + 0.05 {
                    self.lastProgressPosition = position
                    self.deadline?.cancel(); self.deadline = nil; self.loadingMessage = nil
                    self.endLoadingBackgroundTask()
                    if !self.playbackStarted { self.playbackStarted = true; self.onEvent?(.playing) }
                }
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
        beginLoad(videoID: videoID, title: title, artist: artist, start: start, autoplay: autoplay, attempt: 0)
    }

    private func beginLoad(videoID: String, title: String, artist: String, start: Double, autoplay: Bool, attempt: Int) {
        // Keep the established audio session across queue transitions while locked.
        stop(deactivateSession: false)
        retryCount = attempt; playbackStarted = false; lastProgressPosition = start
        lastRequest = (videoID, title, artist, start)
        loadingMessage = attempt == 0 ? "Preparing audio…" : "Retrying audio…"
        let ticket = generation
        wantsPlayback = autoplay
        loadingBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Muses audio startup") { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.generation == ticket else { return }
                self.fail("Audio preparation exceeded background time. Open Muses and retry.")
            }
        }
        metadata = [MPMediaItemPropertyTitle: title, MPMediaItemPropertyArtist: artist]
        deadline = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(25)) } catch { return }
            guard let self, self.generation == ticket, !self.loaded else { return }
            self.fail("Audio loading timed out. Retry or use website playback.")
        }
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .longFormAudio)
                if autoplay { try AVAudioSession.sharedInstance().setActive(true) }
                let url = try await self.resolveStream(videoID)
                guard !Task.isCancelled, self.generation == ticket else { return }
                let asset = AVURLAsset(url: url, options: [AVURLAssetHTTPUserAgentKey: "Mozilla/5.0"])
                let item = AVPlayerItem(asset: asset)
                self.itemObservation = Self.observeItem(item) { [weak self] item in
                    let failed = item.status == .failed
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == ticket, item === self.player.currentItem else { return }
                        if failed {
                            let error = item.error as NSError?
                            let status = item.errorLog()?.events.last?.errorStatusCode ?? 0
                            let diagnostic = Self.errorCodes(error)
                            self.retryOrFail("Audio stream could not be played (\(diagnostic), status \(status)). Retry or use website playback.")
                        } else if item.status == .readyToPlay && !self.wantsPlayback {
                            self.deadline?.cancel(); self.deadline = nil; self.loadingMessage = nil
                            self.endLoadingBackgroundTask()
                        }
                    }
                }
                // Small startup buffer: begin decoding promptly rather than waiting for
                // AVPlayer's conservative entire-network-stall prediction.
                item.preferredForwardBufferDuration = 2
                self.player.replaceCurrentItem(with: item)
                self.loaded = true
                self.watchStartup(ticket: ticket)
                self.registerCommands()
                self.loadArtwork(videoID: videoID, ticket: ticket)
                if start > 0 { self.seek(start) }
                if self.wantsPlayback { self.play() } else { self.onEvent?(.paused); self.publish() }
            } catch {
                guard !Task.isCancelled, self.generation == ticket else { return }
                let detail = error as NSError
                self.fail("Native playback unavailable: \(detail.localizedDescription) (\(detail.domain), \(detail.code)). Retry or use website playback.")
            }
        }
    }

    static func resolveLocalStream(_ videoID: String) async throws -> URL {
        #if MUSES_NATIVE_PLAYBACK
        if let cached = streamCache[videoID], cached.expires > Date(),
           let url = cached.urls.first(where: { !(rejectedFormats[videoID] ?? []).contains(formatKey($0)) }) { return url }
        if streamCache[videoID]?.expires ?? .distantPast <= Date() { rejectedFormats.removeValue(forKey: videoID) }
        let streams = try await YouTube(videoID: videoID, useOAuth: false, allowOAuthCache: false, methods: [.local]).streams
        let audio = streams.filterAudioOnly().filter { $0.fileExtension == .m4a && $0.isNativelyPlayable }
            .sorted { ($0.averageBitrate ?? $0.bitrate ?? 0) > ($1.averageBitrate ?? $1.bitrate ?? 0) }
        // If an audio-only format is rejected by the CDN/player, retry a different
        // compatible representation, preferring the smallest progressive stream.
        let progressive = streams.filterVideoAndAudio().filter { $0.isNativelyPlayable }
            .sorted { ($0.videoResolution ?? Int.max) < ($1.videoResolution ?? Int.max) }
        let urls = (audio + progressive).map(\.url)
        guard let url = urls.first(where: { !(rejectedFormats[videoID] ?? []).contains(formatKey($0)) }) else {
            throw NSError(domain: "MusesNative", code: 1, userInfo: [NSLocalizedDescriptionKey: "No compatible audio stream"])
        }
        if streamCache.count >= 32 { streamCache.removeAll(); rejectedFormats.removeAll() }
        streamCache[videoID] = (urls, Date().addingTimeInterval(300))
        return url
        #else
        throw NSError(domain: "MusesNative", code: 2, userInfo: [NSLocalizedDescriptionKey: "Native playback requires an experimental IPA build"])
        #endif
    }
    private static func errorCodes(_ error: NSError?) -> String {
        var codes: [String] = []
        var current = error
        for _ in 0..<5 {
            guard let value = current else { break }
            codes.append("\(value.domain) \(value.code)")
            current = value.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return codes.isEmpty ? "AVPlayer" : codes.joined(separator: "/")
    }
    func updateDisplayInfo(title: String, artist: String) {
        metadata[MPMediaItemPropertyTitle] = title; metadata[MPMediaItemPropertyArtist] = artist
        if let request = lastRequest { lastRequest = (request.id, title, artist, request.start) }
        publish()
    }
    func updateQueueAvailability(hasNext: Bool) {
        self.hasNext = hasNext
        if loaded { MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = hasNext }
    }

    func play() {
        wantsPlayback = true
        guard loaded else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            if deadline == nil {
                let position = player.currentTime().seconds
                lastProgressPosition = position.isFinite ? position : 0
                watchStartup(ticket: generation)
            }
            player.playImmediately(atRate: 1); publish()
        }
        catch {
            let detail = error as NSError
            fail("Audio session could not start (\(detail.domain), \(detail.code)). Open Muses and retry.")
        }
    }
    func pause() {
        wantsPlayback = false; player.pause()
        if player.currentItem?.status == .readyToPlay { deadline?.cancel(); deadline = nil; loadingMessage = nil; endLoadingBackgroundTask() }
        onEvent?(.paused); publish()
    }
    func retry() {
        guard let request = lastRequest else { return }
        Self.streamCache.removeValue(forKey: request.id)
        Self.rejectedFormats.removeValue(forKey: request.id)
        beginLoad(videoID: request.id, title: request.title, artist: request.artist, start: request.start, autoplay: true, attempt: 0)
    }
    private func watchStartup(ticket: UUID) {
        deadline?.cancel()
        deadline = Task { @MainActor [weak self] in
            guard let self else { return }
            do { try await Task.sleep(for: self.startupTimeout) } catch { return }
            guard self.generation == ticket else { return }
            self.retryOrFail("Audio loading timed out. Retry or use website playback.")
        }
    }
    private func retryOrFail(_ message: String) {
        guard retryCount == 0, let request = lastRequest else { fail(message); return }
        let current = player.currentTime().seconds
        let position = current.isFinite ? max(request.start, current) : request.start
        if let asset = player.currentItem?.asset as? AVURLAsset {
            Self.rejectedFormats[request.id, default: []].insert(Self.formatKey(asset.url))
        }
        let autoplay = wantsPlayback
        beginLoad(videoID: request.id, title: request.title, artist: request.artist, start: position, autoplay: autoplay, attempt: 1)
        onEvent?(.buffering)
    }
    func seek(_ seconds: Double) {
        guard loaded, seconds.isFinite, seconds >= 0 else { return }
        let duration = player.currentItem?.duration.seconds ?? .infinity
        let target = duration.isFinite ? min(seconds, duration) : seconds
        lastProgressPosition = target
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }
    func stop(deactivateSession: Bool = true) {
        endLoadingBackgroundTask()
        generation = UUID(); deadline?.cancel(); deadline = nil; task?.cancel(); task = nil; artworkTask?.cancel(); artworkTask = nil
        loaded = false; wantsPlayback = false; resumeAfterInterruption = false; itemObservation = nil; loadingMessage = nil
        player.pause(); player.replaceCurrentItem(with: nil)
        for (command, token) in commandTokens { command.removeTarget(token); command.isEnabled = false }
        commandTokens = []; metadata = [:]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        if deactivateSession { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    }
    private func endLoadingBackgroundTask() {
        guard loadingBackgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(loadingBackgroundTask); loadingBackgroundTask = .invalid
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

#else
/// Public composition has no native media engine or lock-screen commands.
@MainActor @Observable final class ExperimentalNativePlayback {
    enum Event { case playing, paused, buffering, time(Double, Double), ended, failed(String) }
    static let available = false
    let loaded = false
    let wantsPlayback = false
    let loadingMessage: String? = nil
    var onEvent: ((Event) -> Void)?
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?
    func load(videoID: String, title: String, artist: String, start: Double = 0, autoplay: Bool = true) {}
    func updateDisplayInfo(title: String, artist: String) {}
    func updateQueueAvailability(hasNext: Bool) {}
    func play() {}
    func pause() {}
    func retry() {}
    func seek(_ seconds: Double) {}
    func stop(deactivateSession: Bool = true) {}
}
#endif
