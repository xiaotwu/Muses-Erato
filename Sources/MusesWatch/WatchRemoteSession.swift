import Foundation
import Observation
@preconcurrency import WatchConnectivity
import WatchKit

@Observable
@MainActor
final class WatchRemoteSession {
    var state = WatchRemoteState.empty
    var artworkJPEG: Data?
    var isReachable = false
    var lastError: String?

    fileprivate let transport: WatchRemoteTransport

    init() {
        let transport = WatchRemoteTransport()
        self.transport = transport
        transport.owner = self
        transport.activate()
    }

    func launchCompanion() {
        send(.init(command: .launch))
    }

    func pause() {
        state.isPlaying = false
        send(.init(command: .pause))
        haptic(.stop)
    }

    func play() {
        state.isPlaying = true
        send(.init(command: .play))
        haptic(.start)
    }

    func toggleOrPause() {
        if state.isPlaying {
            pause()
        } else {
            play()
        }
    }

    func next() {
        send(.init(command: .next))
        haptic(.directionUp)
    }

    func previous() {
        send(.init(command: .previous))
        haptic(.directionDown)
    }

    func playIndex(_ index: Int) {
        send(.init(command: .playIndex, index: index))
        haptic(.click)
    }

    func refresh() {
        send(.init(command: .requestState))
    }

    fileprivate func apply(state: WatchRemoteState, artwork: Data?) {
        if state.trackId != self.state.trackId, artwork == nil {
            artworkJPEG = nil
        }
        self.state = state
        if let artwork {
            artworkJPEG = artwork
        }
        lastError = nil
    }

    private func send(_ envelope: WatchRemoteEnvelope) {
        transport.send(envelope)
    }

    private func haptic(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
}

final class WatchRemoteTransport: NSObject, WCSessionDelegate, @unchecked Sendable {
    weak var owner: WatchRemoteSession?
    private var session: WCSession?

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    func send(_ envelope: WatchRemoteEnvelope) {
        let payload = WatchRemoteCodec.encodeCommand(envelope)
        guard let session else { return }
        if session.isReachable {
            session.sendMessage(payload, replyHandler: { [weak self] reply in
                let parsed = WatchRemoteCodec.parseReply(reply)
                Task { @MainActor in
                    if let state = parsed.0 {
                        self?.owner?.apply(state: state, artwork: parsed.1)
                    }
                }
            }, errorHandler: { [weak self] error in
                let text = error.localizedDescription
                session.transferUserInfo(payload)
                Task { @MainActor in
                    self?.owner?.lastError = text
                }
            })
        } else {
            session.transferUserInfo(payload)
            Task { @MainActor in
                self.owner?.isReachable = false
            }
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let reachable = session.isReachable
        let activated = activationState == .activated
        let text = error?.localizedDescription
        Task { @MainActor in
            self.owner?.isReachable = reachable
            self.owner?.lastError = text
            if activated {
                self.owner?.launchCompanion()
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.owner?.isReachable = reachable
            if reachable {
                self.owner?.refresh()
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let data = applicationContext[WatchRemoteCodec.stateKey] as? Data
        let state = data.flatMap(WatchRemoteCodec.decodeState)
        Task { @MainActor in
            if let state {
                self.owner?.apply(state: state, artwork: nil)
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let parsed = WatchRemoteCodec.parseReply(message)
        Task { @MainActor in
            if let state = parsed.0 {
                self.owner?.apply(state: state, artwork: parsed.1)
            }
        }
    }
}
