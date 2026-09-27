import AVKit
import MediaPlayer
import SwiftUI
import UIKit

/// Centered Now Playing transport: authentic Liquid Glass dock, balanced tactile controls,
/// and an Audio button for volume + route (AirPlay / device).
struct NowPlayingTransportBar: View {
    @Bindable var playback: PlaybackService
    var onWatchVideo: () -> Void

    @State private var showAudioSheet = false

    private var canWatchVideo: Bool {
        !(playback.state.track?.youTubeId ?? "").isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sideButton(
                    systemName: "speaker.wave.2.fill",
                    label: tr("Audio", "音频", zhHant: "音訊"),
                    enabled: true
                ) {
                    showAudioSheet = true
                }

                Spacer(minLength: 4)

                HStack(spacing: 28) {
                    sideButton(
                        systemName: "backward.fill",
                        label: tr("Previous", "上一首", zhHant: "上一首")
                    ) {
                        playback.previous()
                    }

                    playPauseButton

                    sideButton(
                        systemName: "forward.fill",
                        label: tr("Next", "下一首", zhHant: "下一首")
                    ) {
                        playback.next()
                    }
                }

                Spacer(minLength: 4)

                if canWatchVideo {
                    sideButton(
                        systemName: "play.rectangle.fill",
                        label: tr("Watch Video", "观看视频", zhHant: "觀看影片"),
                        enabled: true,
                        action: onWatchVideo
                    )
                } else {
                    sideButton(
                        systemName: "shuffle",
                        label: tr("Shuffle", "随机播放", zhHant: "隨機播放"),
                        enabled: true,
                        active: playback.queue.shuffle
                    ) {
                        playback.queue.toggleShuffle()
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: 520)
        .sheet(isPresented: $showAudioSheet) {
            AudioOutputSheet()
                .presentationDetents([.height(260), .medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
    }

    private var playPauseButton: some View {
        Button {
            playback.toggle()
        } label: {
            Image(systemName: playback.state.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.92))
                .offset(x: playback.state.isPlaying ? 0 : 1.5)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Color.white))
                .shadow(color: .black.opacity(0.28), radius: 10, y: 4)
                .contentShape(Circle())
        }
        .buttonStyle(MusesPressStyle(scale: MusesMotion.pressScale))
        .accessibilityLabel(
            playback.state.isPlaying
                ? tr("Pause", "暂停", zhHant: "暫停")
                : tr("Play", "播放", zhHant: "播放")
        )
    }

    private func sideButton(
        systemName: String,
        label: String,
        enabled: Bool = true,
        active: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(
                    active ? BrandColors.laurelGold : .white.opacity(enabled ? 0.92 : 0.32)
                )
                .frame(width: 44, height: 44)
                .frame(minWidth: AppleMusicSpacing.hitTarget, minHeight: AppleMusicSpacing.hitTarget)
                .contentShape(Circle())
        }
        .buttonStyle(MusesPressStyle(scale: MusesMotion.pressScale))
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

/// Volume slider + AirPlay / device route — same glass language as transport.
private struct AudioOutputSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(tr("Audio", "音频", zhHant: "音訊"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(BrandColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 10) {
                Label(
                    tr("Volume", "音量", zhHant: "音量"),
                    systemImage: "speaker.wave.2.fill"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(BrandColors.textSecondary)

                SystemVolumeSlider()
                    .frame(height: AppleMusicSpacing.hitTarget)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(BrandColors.glassRimGradient, lineWidth: 0.6)
                    }
                    .accessibilityLabel(tr("Volume", "音量", zhHant: "音量"))
            }

            HStack(spacing: 14) {
                Label(
                    tr("Output", "输出设备", zhHant: "輸出裝置"),
                    systemImage: "airplayaudio"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(BrandColors.textSecondary)

                Spacer(minLength: 8)

                AirPlayRouteButton(
                    tint: .white,
                    activeTint: UIColor.white
                )
                .frame(width: 44, height: 44)
                .musesGlass(in: Circle(), role: .compactControl)
                .overlay {
                    Circle().stroke(BrandColors.glassRimGradient, lineWidth: 0.65)
                }
                .accessibilityLabel(tr("Choose Device", "选择设备", zhHant: "選擇裝置"))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 16)
        .frame(maxWidth: 480)
    }
}

struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.tintColor = .white
        view.showsRouteButton = false
        view.setVolumeThumbImage(thumbImage(), for: .normal)
        // Hide the built-in route button; we expose AirPlay separately.
        for sub in view.subviews where sub is UIButton {
            sub.isHidden = true
        }
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}

    private func thumbImage() -> UIImage {
        let size = CGSize(width: 16, height: 16)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
        }
    }
}
