import SwiftUI
import MediaPlayer
import AVKit

struct PublicMiniPlayer: View {
    let session: PublicYouTubeSession
    var systemAccessory = false
    var body: some View {
        HStack(spacing: 12) {
            Button { session.showPlayer = true } label: {
                HStack(spacing: 12) {
                    PublicPlayerArtwork(videoID: session.currentTrack?.publicVideoID?.rawValue)
                        .frame(width: 46, height: 46).clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.currentTrack?.displayTitle ?? "Up next").font(.subheadline.weight(.semibold)).lineLimit(1)
                        if session.nativePlaybackEnabled { Text(session.currentTrack?.displayArtist ?? "YouTube").font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(session.currentTrack == nil)
                .accessibilityLabel("Open Now Playing").accessibilityIdentifier("player.mini.open")
            if session.nativePlaybackEnabled {
                Button {
                    session.nativePlayback.wantsPlayback ? session.pause() : session.play()
                } label: {
                    Image(systemName: session.state.state == .playing ? "pause.fill" : "play.fill").font(.title3).frame(width: 44, height: 44)
                }.disabled(session.currentTrack == nil).accessibilityLabel(session.state.state == .playing ? "Pause" : "Play")
            }
            PublicQueueControl(session: session)
            Button {
                let openingFirst = session.currentTrack == nil
                session.next()
                if openingFirst, session.currentTrack != nil { session.showPlayer = true }
            } label: { Image(systemName: "forward.end.fill").font(.title3).frame(width: 44, height: 44) }
                .disabled(!session.hasNext).accessibilityLabel(session.currentTrack == nil ? "Open queued video" : "Next")
        }.padding(.horizontal, 12).padding(.vertical, 8)
            .modifier(PublicFloatingPlayerSurface(systemAccessory: systemAccessory))
    }
}

struct PublicNativePlayerView: View {
    let session: PublicYouTubeSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showingQueue = false
    @State private var showingNotebook = false
    @State private var scrubbing = false
    @State private var scrubPosition = 0.0
    @State private var confirmingFavoriteRemoval = false
    private var duration: Double { Double(session.state.durationMilliseconds ?? 0) / 1000 }
    private var position: Double { Double(session.state.positionMilliseconds) / 1000 }
    private var playing: Bool { session.state.state == .playing }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 18) {
                        PublicPlayerArtwork(videoID: session.currentTrack?.publicVideoID?.rawValue)
                            .frame(width: max(0, min(geometry.size.width - 48, geometry.size.height * 0.39, 360)), height: max(0, min(geometry.size.width - 48, geometry.size.height * 0.39, 360)))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
                            .padding(.top, 16)
                            .accessibilityHidden(true)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(session.currentTrack?.displayTitle ?? "Now Playing").font(.title2.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                                Text(session.currentTrack?.displayArtist ?? "YouTube").font(.title3).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                if session.currentTrack?.liked == true { confirmingFavoriteRemoval = true } else { session.toggleFavorite() }
                            } label: { Image(systemName: session.currentTrack?.liked == true ? "star.fill" : "star").font(.title3).frame(width: 44, height: 44) }
                                .accessibilityLabel(session.currentTrack?.liked == true ? "Remove favorite" : "Favorite")
                        }
                        VStack(spacing: 4) {
                            Slider(value: Binding(get: { scrubbing ? scrubPosition : min(position, max(1, duration)) }, set: { scrubPosition = $0 }), in: 0...max(1, duration), onEditingChanged: { editing in
                                if editing { scrubPosition = position; scrubbing = true }
                                else { scrubbing = false; session.seekPlayback(seconds: scrubPosition) }
                            }).disabled(!session.nativePlayback.loaded || duration <= 0).accessibilityLabel("Playback position")
                            HStack {
                                Text(time(scrubbing ? scrubPosition : position)); Spacer(); Text("−" + time(max(0, duration - (scrubbing ? scrubPosition : position))))
                            }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 44) {
                            Button { session.previous() } label: { Image(systemName: "backward.end.fill").font(.system(size: 28)).frame(width: 52, height: 52) }.accessibilityLabel("Previous")
                            Button { session.nativePlayback.wantsPlayback ? session.pause() : session.play() } label: {
                                if session.state.state == .loading || session.state.state == .buffering { ProgressView().frame(width: 64, height: 64) }
                                else { Image(systemName: playing ? "pause.fill" : "play.fill").font(.system(size: 44)).frame(width: 64, height: 64) }
                            }.accessibilityLabel(playing ? "Pause" : "Play").accessibilityIdentifier("player.toggle")
                            Button { session.next() } label: { Image(systemName: "forward.end.fill").font(.system(size: 28)).frame(width: 52, height: 52) }.disabled(!session.hasNext).accessibilityLabel("Next")
                        }.modifier(PublicGlassActions())
                        if let message = session.nativePlayback.loadingMessage {
                            HStack {
                                Text(message).font(.subheadline).foregroundStyle(.secondary)
                                Spacer()
                                Button("Retry", systemImage: "arrow.clockwise") { session.nativePlayback.retry() }
                            }
                        }
                        PublicSystemVolume().frame(height: 40).accessibilityLabel("System volume")
                        HStack {
                            Button { showingNotebook = true } label: { Image(systemName: "text.bubble").font(.title2).frame(width: 52, height: 52) }.accessibilityLabel("Notes and bookmarks")
                            Spacer()
                            PublicAudioRoutePicker().frame(width: 52, height: 52).accessibilityLabel("Audio output")
                            Spacer()
                            Button { showingQueue = true } label: { Image(systemName: "list.bullet").font(.title2).frame(width: 52, height: 52) }.accessibilityLabel("Queue").accessibilityIdentifier("player.queue")
                        }.buttonStyle(.plain)
                        if let error = session.failureMessage {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(error).font(.callout).foregroundStyle(.secondary)
                                Button("Website playback", systemImage: "safari") { openWebsite() }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Text(session.state.state.rawValue.capitalized).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("public.playbackState")
                    }.padding(.horizontal, 24).padding(.bottom, 24).frame(maxWidth: 460)
                        .frame(maxWidth: .infinity)
                }.background(Color(uiColor: .secondarySystemBackground))
            }
            .navigationTitle("Now Playing").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { dismiss() } label: { Image(systemName: "chevron.down").frame(width: 44, height: 44) }.accessibilityLabel("Close player") }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if let track = session.currentTrack { PublicAddToPlaylistMenu(session: session, track: track) }
                        Button("Website playback", systemImage: "safari") { openWebsite() }
                        Button("YouTube video player", systemImage: "play.rectangle") { session.setNativePlayback(false) }
                    } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("Playback actions")
                }
            }
            .sheet(isPresented: $showingQueue) { NavigationStack { PublicQueueView(session: session, onOpenPlayer: { showingQueue = false }).toolbar { ToolbarItem(placement: .topBarLeading) { Button("Done") { showingQueue = false } } } } }
            .sheet(isPresented: $showingNotebook) {
                NavigationStack {
                    ScrollView { if let track = session.currentTrack { PublicNotebookContent(session: session, trackID: track.id).padding(20) } }
                        .navigationTitle("Notes & bookmarks").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showingNotebook = false } } }
                }
            }
            .alert("Remove this favorite?", isPresented: $confirmingFavoriteRemoval) {
            Button("Cancel", role: .cancel) {}
                Button("Remove favorite", role: .destructive) { if session.currentTrack?.liked == true { session.toggleFavorite() } }
            }
        }.tint(PublicStyle.gold)
    }
    private func openWebsite() {
        guard let id = session.currentTrack?.publicVideoID?.rawValue, let url = URL(string: "https://www.youtube.com/watch?v=\(id)") else { return }
        session.pause(); openURL(url)
    }
    private func time(_ value: Double) -> String { let seconds = Int(max(0, value)); return "\(seconds / 60):\(String(format: "%02d", seconds % 60))" }
}

struct PublicPlayerArtwork: View {
    let videoID: String?
    @State private var artwork: UIImage?
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(uiColor: .tertiarySystemFill)
                if let artwork {
                    Image(uiImage: artwork).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else { Image(systemName: "music.note").font(.largeTitle).foregroundStyle(.secondary) }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.task(id: videoID) {
            artwork = nil
            guard let videoID else { return }
            // Both are 16:9; hqdefault contains baked letterboxing in many videos.
            for size in ["maxresdefault", "mqdefault"] {
                guard !Task.isCancelled, let url = URL(string: "https://i.ytimg.com/vi/\(videoID)/\(size).jpg") else { return }
                do {
                    let (data, response) = try await URLSession.shared.data(from: url)
                    guard !Task.isCancelled else { return }
                    if (response as? HTTPURLResponse)?.statusCode == 200, data.count < 4_000_000, let image = UIImage(data: data) {
                        artwork = PublicArtworkCrop.removingLetterbox(image); return
                    }
                } catch { if Task.isCancelled { return } }
            }
        }
    }
}
private struct PublicSystemVolume: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView { let view = MPVolumeView(); view.showsRouteButton = false; view.tintColor = UIColor(PublicStyle.gold); return view }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
private struct PublicAudioRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView { let view = AVRoutePickerView(); view.prioritizesVideoDevices = false; view.tintColor = UIColor(PublicStyle.gold); return view }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

/// Remove uniform black bars that are already baked into Google's thumbnail pixels.
/// Paired edges only; bounded trimming avoids removing dark subjects or entire covers.
enum PublicArtworkCrop {
    static func removingLetterbox(_ image: UIImage) -> UIImage {
        guard let source = image.cgImage, source.width >= 64, source.height >= 36 else { return image }
        let width = 64, height = 36
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let rendered = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height)); return true
        }
        guard rendered else { return image }
        func black(_ x: Int, _ y: Int) -> Bool {
            let i = (y * width + x) * 4
            return Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2]) < 48
        }
        // A uniformly dark photograph is content, not letterboxing.
        guard (12..<24).contains(where: { y in (20..<44).contains(where: { x in !black(x, y) }) }) else { return image }
        func row(_ y: Int) -> Bool { (0..<width).filter { black($0, y) }.count >= (width * 97 + 99) / 100 }
        func column(_ x: Int) -> Bool { (0..<height).filter { black(x, $0) }.count >= (height * 97 + 99) / 100 }
        var top = 0, bottom = 0, left = 0, right = 0
        while top < 5 && row(top) { top += 1 }
        while bottom < 5 && row(height - 1 - bottom) { bottom += 1 }
        while left < 9 && column(left) { left += 1 }
        while right < 9 && column(width - 1 - right) { right += 1 }
        if top == 0 || bottom == 0 { top = 0; bottom = 0 }
        if left == 0 || right == 0 { left = 0; right = 0 }
        guard top + bottom + left + right > 0 else { return image }
        let x = CGFloat(source.width) * CGFloat(left) / CGFloat(width)
        let y = CGFloat(source.height) * CGFloat(top) / CGFloat(height)
        let crop = CGRect(x: x, y: y, width: CGFloat(source.width) * CGFloat(width - left - right) / CGFloat(width), height: CGFloat(source.height) * CGFloat(height - top - bottom) / CGFloat(height)).integral
        guard let cropped = source.cropping(to: crop) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
}

private struct PublicFloatingPlayerSurface: ViewModifier {
    let systemAccessory: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if systemAccessory { content }
        else if #available(iOS 26, *), !reduceTransparency {
            content.glassEffect(.regular, in: .rect(cornerRadius: 24))
                .padding(.horizontal, 12).padding(.vertical, 6)
        } else {
            content.background(reduceTransparency ? AnyShapeStyle(PublicStyle.surface) : AnyShapeStyle(.regularMaterial), in: RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 12).padding(.vertical, 6)
        }
    }
}
