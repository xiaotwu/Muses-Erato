#if os(iOS)
import Foundation
import UIKit
import WebKit

/// Owns one visible WKWebView. Keep this instance alive only while its video surface is on screen.
@MainActor
final class YouTubeIFrameAdapter: NSObject {
    let view: WKWebView
    var hasLoadedVideo: Bool { gate.videoID != nil }
    var currentGeneration: UInt64 { gate.generation }
    var onEvent: ((IFrameEvent) -> Void)?

    private var gate: IFrameEventGate
    private let clientOrigin: URL
    private var documentID = UUID().uuidString
    private var apiLoaded = false
    private var playerReady = false
    private var pausedByHost = false
    private var backgroundObserver: NSObjectProtocol?

    override init() {
        let appID = (Bundle.main.bundleIdentifier ?? "com.xiaotwu.muses.erato").lowercased()
        clientOrigin = URL(string: "https://\(appID)")!
        gate = IFrameEventGate(expectedOriginHost: appID)
        let controller = WKUserContentController()
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = [.audio, .video]
        view = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        controller.add(self, name: "eratoPlayer")
        view.navigationDelegate = self
        view.uiDelegate = self
        view.isOpaque = false
        view.backgroundColor = .black
        view.scrollView.isScrollEnabled = false
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
        }
    }

    /// Cue a validated video ID. A new player instance in the same WebView isolates old callbacks.
    @discardableResult
    func load(_ id: IFrameVideoID) -> UInt64 {
        let generation = gate.load(id)
        playerReady = false
        pausedByHost = false
        onEvent?(IFrameEvent(videoID: id, generation: generation, kind: .loading))
        if apiLoaded {
            send(["action": "switch", "videoID": id.rawValue,
                  "generation": String(generation)])
        } else {
            documentID = UUID().uuidString
            let documentJSON = String(data: try! JSONEncoder().encode(documentID), encoding: .utf8)!
            let originJSON = String(data: try! JSONEncoder().encode(clientOrigin.absoluteString), encoding: .utf8)!
            view.loadHTMLString(Self.html.replacingOccurrences(of: "__ERATO_ORIGIN__", with: originJSON)
                    .replacingOccurrences(of: "__ERATO_DOCUMENT__", with: documentJSON),
                                baseURL: clientOrigin)
        }
        return generation
    }

    /// Remove the previous player before an asynchronous content-status check.
    /// No remote player resources are loaded until the session grants a new load.
    func clear() {
        gate.clear()
        documentID = UUID().uuidString
        apiLoaded = false
        playerReady = false
        pausedByHost = true
        send(["action": "destroy"])
        view.stopLoading()
        view.loadHTMLString("<!doctype html><html><body style='background:black'></body></html>", baseURL: nil)
    }

    /// Call from an explicit user action; the IFrame's own controls also remain available.
    func play() throws {
        guard gate.isAlive, gate.videoID != nil, playerReady else {
            throw CommandError.notReady
        }
        pausedByHost = false
        send(["action": "play", "generation": String(gate.generation)])
    }

    func pause() {
        pausedByHost = true
        guard gate.isAlive, gate.videoID != nil else { return }
        send(["action": "pause", "generation": String(gate.generation)])
    }

    func seek(to seconds: Double) throws {
        guard seconds.isFinite, seconds >= 0 else { throw CommandError.invalidPosition }
        guard gate.isAlive, gate.videoID != nil, playerReady else {
            throw CommandError.notReady
        }
        send(["action": "seek", "position": seconds,
              "generation": String(gate.generation)])
    }

    /// Ready-only bookmark positioning must not turn a cued video into autoplay.
    func prepareBookmark(at seconds: Double) throws {
        guard seconds.isFinite, seconds >= 0 else { throw CommandError.invalidPosition }
        guard gate.isAlive, gate.videoID != nil, playerReady else { throw CommandError.notReady }
        send(["action": "bookmark", "position": seconds, "generation": String(gate.generation)])
    }

    /// Called before removing the visible surface. The instance cannot be loaded again.
    func teardown() {
        guard gate.isAlive else { return }
        gate.teardown()
        playerReady = false
        pausedByHost = true
        send(["action": "destroy"])
        view.stopLoading()
        view.loadHTMLString("<!doctype html><html><body style='background:black'></body></html>",
                            baseURL: nil)
        view.configuration.userContentController.removeScriptMessageHandler(forName: "eratoPlayer")
        if let backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
            self.backgroundObserver = nil
        }
        view.navigationDelegate = nil
        view.uiDelegate = nil
    }

    enum CommandError: Error { case notReady, invalidPosition }

    private func send(_ command: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: command),
              let json = String(data: data, encoding: .utf8) else { return }
        view.evaluateJavaScript("window.eratoCommand(\(json))", completionHandler: nil)
    }

    private func receive(_ message: WKScriptMessage) {
        guard gate.isAlive, message.frameInfo.isMainFrame,
              message.frameInfo.securityOrigin.protocol == "https",
              message.frameInfo.securityOrigin.host == clientOrigin.host,
              let body = message.body as? [String: Any] else { return }
        if body["kind"] as? String == "apiReady" {
            guard gate.videoID != nil, body["documentID"] as? String == documentID else { return }
            apiLoaded = true
            if let id = gate.videoID {
                send(["action": "switch", "videoID": id.rawValue,
                      "generation": String(gate.generation)])
            }
            return
        }
        guard let event = gate.accept(body, isMainFrame: true,
                                      originScheme: message.frameInfo.securityOrigin.protocol,
                                      originHost: message.frameInfo.securityOrigin.host) else { return }
        if case .ready = event.kind { playerReady = true }
        if case .playing = event.kind, pausedByHost {
            // Native pause during buffering remains the final intent.
            pause()
            return
        }
        onEvent?(event)
    }

    private static let html = #"""
    <!doctype html><html><head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="referrer" content="strict-origin-when-cross-origin">
    <style>html,body,#player{width:100%;height:100%;margin:0;background:#000;overflow:hidden}
    iframe{width:100%;height:100%;border:0}</style></head><body>
    <div id="player"></div>
    <script>
    let player = null, active = null;
    function emit(kind, extra, token) {
      const current = token || active;
      if (!current) return;
      window.webkit.messageHandlers.eratoPlayer.postMessage(
        Object.assign({kind:kind, videoID:current.videoID,
                       generation:current.generation}, extra || {}));
    }
    function onYouTubeIframeAPIReady() {
      window.webkit.messageHandlers.eratoPlayer.postMessage({kind:'apiReady', documentID:__ERATO_DOCUMENT__});
    }
    window.eratoCommand = function(command) {
      if (command.action === 'destroy') {
        if (player) { player.stopVideo(); player.destroy(); player = null; }
        active = null;
        return;
      }
      if (command.action === 'switch') {
        if (!/^[A-Za-z0-9_-]{11}$/.test(command.videoID)) return;
        if (player) { player.stopVideo(); player.destroy(); player = null; }
        const container = document.createElement('div');
        container.id = 'player';
        document.getElementById('player')?.remove();
        document.body.appendChild(container);
        const token = {videoID:command.videoID, generation:command.generation};
        active = token;
        player = new YT.Player('player', {
          videoId:token.videoID,
          playerVars:{playsinline:1, controls:1, origin:__ERATO_ORIGIN__},
          events:{
            onReady:function(){emit('ready',null,token)},
            onStateChange:function(e){
              const states = {'-1':'cued','0':'ended','1':'playing',
                              '2':'paused','3':'buffering','5':'cued'};
              const kind = states[String(e.data)];
              if (kind) emit(kind,null,token);
            },
            onError:function(e){emit('error',{code:e.data},token)}
          }
        });
        return;
      }
      if (!active || command.generation !== active.generation || !player) return;
      if (command.action === 'play') player.playVideo();
      if (command.action === 'pause') player.pauseVideo();
      if (command.action === 'bookmark' && Number.isFinite(command.position) && command.position >= 0) {
        // seekTo starts playback from a cued/unstarted state. Cue at startSeconds
        // instead; only use seekTo when the player is already paused.
        if (player.getPlayerState() === 2) player.seekTo(command.position, true);
        else player.cueVideoById({videoId:active.videoID, startSeconds:command.position});
      }
      if (command.action === 'seek' && Number.isFinite(command.position))
        player.seekTo(command.position, true);
    };
    setInterval(function(){
      if (!player || !active || typeof player.getCurrentTime !== 'function') return;
      const position = player.getCurrentTime(), duration = player.getDuration();
      if (Number.isFinite(position) && Number.isFinite(duration))
        emit('time',{position:position,duration:duration});
    },1000);
    </script><script src="https://www.youtube.com/iframe_api"></script>
    </body></html>
    """#
}

extension YouTubeIFrameAdapter: WKScriptMessageHandler {
    nonisolated func userContentController(_ userContentController: WKUserContentController,
                                           didReceive message: WKScriptMessage) {
        Task { @MainActor [weak self] in self?.receive(message) }
    }
}

extension YouTubeIFrameAdapter: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        guard let id = gate.videoID else { return }
        onEvent?(IFrameEvent(videoID: id, generation: gate.generation,
                            kind: .failed(.network)))
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard navigationAction.targetFrame?.isMainFrame == true,
              let url = navigationAction.request.url,
              url.scheme != "about" else { return .allow }
        if navigationAction.navigationType == .other,
           url.scheme == clientOrigin.scheme, url.host == clientOrigin.host {
            return .allow
        }
        return .cancel
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url, url.scheme == "https",
           let host = url.host, host == "youtube.com" || host.hasSuffix(".youtube.com") {
            UIApplication.shared.open(url)
        }
        return nil
    }
}
#endif
