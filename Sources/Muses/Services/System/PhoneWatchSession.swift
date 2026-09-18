import Foundation
import UIKit
@preconcurrency import WatchConnectivity

/// iPhone half of the Watch remote. WatchConnectivity is the only sync path:
/// App Groups are not shared with watchOS.
@MainActor
final class PhoneWatchSession: NSObject, WCSessionDelegate {
    static weak var shared: PhoneWatchSession?

    private weak var playback: PlaybackService?
    private let store: NowPlayingSnapshotStore
    private var lastSignature = ""
    private var session: WCSession?

    init(playback: PlaybackService, store: NowPlayingSnapshotStore = .shared) {
        self.playback = playback
        self.store = store
        super.init()
        Self.shared = self
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    func publishIfNeeded() {
        guard let playback, let session, session.activationState == .activated else { return }
        let state = capture(playback)
        guard state.signature != lastSignature else { return }
        lastSignature = state.signature
        if let data = WatchRemoteCodec.encodeState(state) {
            try? session.updateApplicationContext([WatchRemoteCodec.stateKey: data])
        }
    }

    // MARK: WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.publishIfNeeded()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let envelope = WatchRemoteCodec.decodeCommand(message)
        let reply = WatchReplyBox(replyHandler)
        Task { @MainActor in
            reply.send(self.handle(envelope))
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let envelope = WatchRemoteCodec.decodeCommand(message)
        Task { @MainActor in
            _ = self.handle(envelope)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let envelope = WatchRemoteCodec.decodeCommand(userInfo)
        Task { @MainActor in
            _ = self.handle(envelope)
        }
    }

    // MARK: Commands

    @discardableResult
    func handle(_ message: [String: Any]) -> [String: Any] {
        handle(WatchRemoteCodec.decodeCommand(message))
    }

    @discardableResult
    func handle(_ envelope: WatchRemoteEnvelope?) -> [String: Any] {
        guard let envelope, let playback else {
            return WatchRemoteCodec.reply(state: .empty, artwork: nil)
        }
        apply(envelope, to: playback)
        let state = capture(playback)
        lastSignature = state.signature
        return WatchRemoteCodec.reply(state: state, artwork: currentArtwork())
    }

    private func apply(_ envelope: WatchRemoteEnvelope, to playback: PlaybackService) {
        switch envelope.command {
        case .launch, .requestState:
            prepareCompanion(playback)
        case .pause:
            playback.pause()
        case .play:
            prepareCompanion(playback)
            playback.play()
        case .toggle:
            if playback.state.isPlaying || playbackRequested(playback) {
                playback.pause()
            } else {
                prepareCompanion(playback)
                playback.play()
            }
        case .next:
            playback.next()
        case .previous:
            playback.previous()
        case .playIndex:
            if let index = envelope.index.flatMap({
                WatchRemoteCodec.validatedPlayIndex($0, queueCount: playback.queue.items.count)
            }) {
                playback.playQueueIndex(index)
            }
        }
    }

    private func playbackRequested(_ playback: PlaybackService) -> Bool {
        playback.state.isPlaying
    }

    /// Waking from Watch always restores the last queue so the two devices
    /// show the same track. Audio only resumes through an explicit play command.
    private func prepareCompanion(_ playback: PlaybackService) {
        if playback.queue.items.isEmpty {
            playback.queue.restore()
        }
        if playback.state.track == nil, playback.queue.current() != nil {
            playback.restoreCurrentPaused(atMs: playback.queue.lastPositionMs)
        }
    }

    private func capture(_ playback: PlaybackService) -> WatchRemoteState {
        let items = playback.queue.items.prefix(40).map {
            WatchQueueItemSnapshot(
                id: $0.track.id.uuidString,
                title: $0.track.title,
                artist: $0.track.artist
            )
        }
        let track = playback.state.track
        return WatchRemoteState(
            trackId: track?.id.uuidString,
            title: track?.title ?? "",
            artist: track?.artist ?? "",
            isPlaying: playback.state.isPlaying,
            position: playback.state.position,
            duration: playback.state.duration,
            currentIndex: playback.queue.currentIndex,
            queue: Array(items),
            companionRunning: true,
            updatedAt: Date()
        )
    }

    private func currentArtwork() -> Data? {
        guard let snapshot = store.load(),
              let data = store.artworkData(fileName: snapshot.artworkFileName) else { return nil }
        return WatchArtworkCodec.jpeg(data)
    }
}

private final class WatchReplyBox: @unchecked Sendable {
    private let handler: ([String: Any]) -> Void

    init(_ handler: @escaping ([String: Any]) -> Void) {
        self.handler = handler
    }

    func send(_ payload: [String: Any]) {
        handler(payload)
    }
}

enum WatchArtworkCodec {
    static func jpeg(_ data: Data, maxPixel: CGFloat = 200) -> Data? {
        guard let image = UIImage(data: data) else { return data }
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return data }
        let scale = min(1, maxPixel / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.jpegData(compressionQuality: 0.62)
    }
}
