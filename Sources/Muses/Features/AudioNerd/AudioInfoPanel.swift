import SwiftUI

/// Audio Nerd technical stream and audio graph inspector for iOS.
struct AudioInfoPanel: View {
    @Bindable var playback: PlaybackService
    @Environment(\.dismiss) private var dismiss

    init(playback: PlaybackService) {
        self.playback = playback
    }

    public var body: some View {
        NavigationStack {
            List {
                Section(header: Text(tr("STREAM SOURCE", "流媒体源"))) {
                    statRow(title: tr("YouTube ID", "YouTube ID"), value: playback.state.track?.youTubeId ?? "N/A")
                    statRow(title: tr("Title", "曲目标题"), value: playback.state.track?.title ?? "N/A")
                    statRow(title: tr("Artist", "艺人"), value: playback.state.track?.artist ?? "N/A")
                    statRow(title: tr("Album", "专辑"), value: playback.state.track?.albumTitle ?? "N/A")
                }

                Section(header: Text(tr("AUDIO GRAPH SPECIFICATIONS", "音频引擎技术参数"))) {
                    statRow(title: tr("Codec / Format", "编码格式"), value: playback.state.track?.codec ?? "AAC / m4a (Opus fallback)")
                    statRow(title: tr("Sample Rate", "采样率"), value: "\(playback.state.track?.sampleRate ?? 48000) Hz")
                    statRow(title: tr("Bit Depth", "位深"), value: "\(playback.state.track?.bitDepth ?? 24)-bit Float")
                    statRow(title: tr("Bitrate", "码率"), value: "\( (playback.state.track?.bitRate ?? 256000) / 1000 ) kbps")
                    statRow(title: tr("Lossless Stream", "无损流"), value: playback.state.track?.isLossless == true ? tr("Yes", "是") : tr("High Fidelity AAC", "高解析度 AAC"))
                }

                Section(header: Text(tr("PLAYBACK PIPELINE", "播放管线"))) {
                    statRow(title: tr("Audio Engine", "底层音频引擎"), value: "AVAudioEngine (Dual PlayerNode)")
                    statRow(title: tr("Equalizer", "图形均衡器"), value: "AVAudioUnitEQ (32-Band)")
                    statRow(title: tr("Loudness Normalization", "响度均衡"), value: playback.state.track?.replayGain != nil ? "\(playback.state.track!.replayGain!) dB" : tr("Sound Check Active", "自动响度保护生效"))
                    statRow(title: tr("Active State", "状态"), value: playback.state.isPlaying ? tr("Playing", "播放中") : tr("Paused", "已暂停"))
                }
            }
            .navigationTitle(tr("Audio Nerd Inspector", "音频极客参数面板"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("Done", "完成")) {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(BrandColors.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(BrandColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(BrandColors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
    }
}
