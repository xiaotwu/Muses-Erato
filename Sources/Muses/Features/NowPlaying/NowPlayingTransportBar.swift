import MediaPlayer
import SwiftUI
import UIKit

struct NowPlayingTransportBar: View {
    @Bindable var playback: PlaybackService
    var onWatchVideo: () -> Void

    private var canWatchVideo: Bool {
        !(playback.state.track?.youTubeId ?? "").isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            transportButton(
                systemName: "backward.fill",
                label: tr("Previous", "上一首", zhHant: "上一首"),
                action: { playback.previous() }
            )
            Button {
                playback.toggle()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 56, height: 56)
                    Image(systemName: playback.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.black)
                }
            }
            .frame(width: 56, height: 56)
            .accessibilityLabel(
                playback.state.isPlaying
                    ? tr("Pause", "暂停", zhHant: "暫停")
                    : tr("Play", "播放", zhHant: "播放")
            )

            transportButton(
                systemName: "forward.fill",
                label: tr("Next", "下一首", zhHant: "下一首"),
                action: { playback.next() }
            )

            transportButton(
                systemName: "play.rectangle.fill",
                label: tr("Watch Video", "观看视频", zhHant: "觀看影片"),
                enabled: canWatchVideo,
                action: onWatchVideo
            )

            SystemVolumeSlider()
                .frame(width: 88, height: 44)
                .accessibilityLabel(tr("Volume", "音量", zhHant: "音量"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func transportButton(
        systemName: String,
        label: String,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3)
                .foregroundStyle(.white.opacity(enabled ? 0.95 : 0.35))
                .frame(width: 44, height: 44)
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.tintColor = .white
        view.setVolumeThumbImage(thumbImage(), for: .normal)
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}

    private func thumbImage() -> UIImage {
        let size = CGSize(width: 14, height: 14)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
        }
    }
}
