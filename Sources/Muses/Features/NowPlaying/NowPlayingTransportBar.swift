import AVKit
import MediaPlayer
import SwiftUI
import UIKit

/// Centered Now Playing transport: glass laser dock, balanced controls,
/// and a single Audio button for volume + route (AirPlay / device).
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

                HStack(spacing: 20) {
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

                sideButton(
                    systemName: "play.rectangle.fill",
                    label: tr("Watch Video", "观看视频", zhHant: "觀看影片"),
                    enabled: canWatchVideo,
                    action: onWatchVideo
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(BrandColors.hairline.opacity(0.55), lineWidth: 0.6)
                    .allowsHitTesting(false)
            }
            .laserStrokeCapsule(lineWidth: 0.95, opacity: 0.68)
            .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showAudioSheet) {
            AudioOutputSheet()
                .presentationDetents([.height(240)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
    }

    private var playPauseButton: some View {
        Button {
            playback.toggle()
        } label: {
            Image(systemName: playback.state.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.92))
                .offset(x: playback.state.isPlaying ? 0 : 1)
                .frame(width: 58, height: 58)
                .background(Circle().fill(Color.white))
                .laserStrokeCircle(lineWidth: 1.15, opacity: 0.78)
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
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(enabled ? 0.95 : 0.32))
                .frame(width: 44, height: 44)
                .musesGlass(in: Circle(), tint: Color.white.opacity(0.12), role: .compactControl)
                .laserStrokeCircle(lineWidth: 0.85, opacity: enabled ? 0.58 : 0.28)
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
                    .laserStroke(cornerRadius: 14, lineWidth: 0.8, opacity: 0.55)
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
                .musesGlass(in: Circle(), tint: Color.white.opacity(0.12), role: .compactControl)
                .laserStrokeCircle(lineWidth: 0.85, opacity: 0.58)
                .accessibilityLabel(tr("Choose Device", "选择设备", zhHant: "選擇裝置"))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 16)
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
