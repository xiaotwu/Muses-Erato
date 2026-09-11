import SwiftUI
import WebKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// YouTube watch/embed helpers.
enum YouTubeEmbed {
    static func isVideo(_ track: TrackSnapshot?) -> Bool {
        guard let id = track?.youTubeId, !id.isEmpty else { return false }
        return true
    }

    static func thumbnailURL(videoId: String) -> URL? {
        YouTubeThumbnail.url(videoId: videoId)
    }

    static func watchURL(videoId: String) -> URL? {
        URL(string: "https://www.youtube.com/watch?v=\(videoId)")
    }

    static func pageHTML(videoId: String) -> String {
        let id = videoId.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        return """
        <!DOCTYPE html><html><head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
        <style>
        html,body{margin:0;background:#000;height:100%;overflow:hidden}
        iframe{position:absolute;inset:0;width:100%;height:100%;border:0}
        </style></head><body>
        <iframe src="https://www.youtube-nocookie.com/embed/\(id)?autoplay=1&rel=0&modestbranding=1&playsinline=1&enablejsapi=1"
                allow="autoplay; encrypted-media; picture-in-picture" allowfullscreen></iframe>
        </body></html>
        """
    }
}

/// Compact 16:9 peek below the transport. Tap expands the embed.
struct YouTubeVideoWell: View {
    let videoId: String
    var onExpand: () -> Void

    init(videoId: String, onExpand: @escaping () -> Void) {
        self.videoId = videoId
        self.onExpand = onExpand
    }

    var body: some View {
        Button(action: onExpand) {
            ZStack {
                CachedAsyncImage(
                    url: YouTubeEmbed.thumbnailURL(videoId: videoId),
                    content: { $0.resizable().scaledToFill() },
                    placeholder: {
                        Rectangle().fill(BrandColors.surface)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                YouTubeMark(size: 22)
                    .shadow(radius: 6)
                    .accessibilityHidden(true)
            }
            .frame(height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(BrandColors.textPrimary.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tr("Open YouTube video", "打开 YouTube 视频"))
    }
}

/// Full-screen or modal YouTube iframe. Pauses native audio while open so
/// picture and sound come from one player.
struct YouTubeVideoOverlay: View {
    let videoId: String
    @Binding var isPresented: Bool
    @Environment(PlaybackService.self) private var playback
    @State private var playbackSuspension: UUID?

    init(videoId: String, isPresented: Binding<Bool>) {
        self.videoId = videoId
        self._isPresented = isPresented
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                YouTubeWKEmbed(videoId: videoId)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding()
            }
            .navigationTitle(tr("Music Video", "音乐视频"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .onAppear {
            if playbackSuspension == nil {
                playbackSuspension = playback.beginNativePlaybackSuspension()
            }
        }
        .onDisappear {
            if let token = playbackSuspension {
                playbackSuspension = nil
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(150))
                    playback.endNativePlaybackSuspension(token, resume: true)
                }
            }
        }
    }
}

#if canImport(UIKit)
struct YouTubeWKEmbed: UIViewRepresentable {
    let videoId: String

    init(videoId: String) {
        self.videoId = videoId
    }

    final class Coordinator {
        var videoId: String?
        var navigationGeneration: UInt64 = 0

        func beginNavigation(to nextVideoId: String) -> UInt64? {
            guard videoId != nextVideoId else { return nil }
            videoId = nextVideoId
            navigationGeneration &+= 1
            return navigationGeneration
        }

        func invalidate() {
            navigationGeneration &+= 1
            videoId = nil
        }

        func owns(videoId: String, generation: UInt64) -> Bool {
            self.videoId == videoId && navigationGeneration == generation
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .black
        view.scrollView.isScrollEnabled = false
        _ = context.coordinator.beginNavigation(to: videoId)
        view.loadHTMLString(YouTubeEmbed.pageHTML(videoId: videoId),
                            baseURL: URL(string: "https://www.youtube-nocookie.com"))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let generation = context.coordinator.beginNavigation(to: videoId) else { return }
        Self.pauseIframe(in: uiView) {
            guard context.coordinator.owns(videoId: videoId, generation: generation) else { return }
            uiView.loadHTMLString(
                YouTubeEmbed.pageHTML(videoId: videoId),
                baseURL: URL(string: "https://www.youtube-nocookie.com")
            )
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.invalidate()
        pauseIframe(in: uiView) {
            uiView.stopLoading()
            uiView.loadHTMLString(
                "<!doctype html><html><body style='margin:0;background:#000'></body></html>",
                baseURL: nil
            )
        }
    }

    private static func pauseIframe(in webView: WKWebView, completion: @escaping () -> Void) {
        let script = """
        (() => {
          const frame = document.querySelector('iframe');
          if (frame && frame.contentWindow) {
            frame.contentWindow.postMessage(JSON.stringify({
              event: 'command', func: 'pauseVideo', args: []
            }), '*');
          }
          document.querySelectorAll('video, audio').forEach(media => media.pause());
        })();
        """
        webView.evaluateJavaScript(script) { _, _ in completion() }
    }
}
#else
struct YouTubeWKEmbed: NSViewRepresentable {
    let videoId: String

    init(videoId: String) {
        self.videoId = videoId
    }

    final class Coordinator {
        var videoId: String?
        var navigationGeneration: UInt64 = 0

        func beginNavigation(to nextVideoId: String) -> UInt64? {
            guard videoId != nextVideoId else { return nil }
            videoId = nextVideoId
            navigationGeneration &+= 1
            return navigationGeneration
        }

        func invalidate() {
            navigationGeneration &+= 1
            videoId = nil
        }

        func owns(videoId: String, generation: UInt64) -> Bool {
            self.videoId == videoId && navigationGeneration == generation
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        let view = WKWebView(frame: .zero, configuration: config)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        _ = context.coordinator.beginNavigation(to: videoId)
        view.loadHTMLString(YouTubeEmbed.pageHTML(videoId: videoId),
                            baseURL: URL(string: "https://www.youtube-nocookie.com"))
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard let generation = context.coordinator.beginNavigation(to: videoId) else { return }
        Self.pauseIframe(in: nsView) {
            guard context.coordinator.owns(videoId: videoId, generation: generation) else { return }
            nsView.loadHTMLString(
                YouTubeEmbed.pageHTML(videoId: videoId),
                baseURL: URL(string: "https://www.youtube-nocookie.com")
            )
        }
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        coordinator.invalidate()
        pauseIframe(in: nsView) {
            nsView.stopLoading()
            nsView.loadHTMLString(
                "<!doctype html><html><body style='margin:0;background:#000'></body></html>",
                baseURL: nil
            )
        }
    }

    private static func pauseIframe(in webView: WKWebView, completion: @escaping () -> Void) {
        let script = """
        (() => {
          const frame = document.querySelector('iframe');
          if (frame && frame.contentWindow) {
            frame.contentWindow.postMessage(JSON.stringify({
              event: 'command', func: 'pauseVideo', args: []
            }), '*');
          }
          document.querySelectorAll('video, audio').forEach(media => media.pause());
        })();
        """
        webView.evaluateJavaScript(script) { _, _ in completion() }
    }
}
#endif
