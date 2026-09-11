import SwiftUI

/// Settings view for audio options, cache management, and application preferences.
struct SettingsView: View {
    @Bindable var playback: PlaybackService
    @Environment(\.dismiss) private var dismiss

    @AppStorage(PrefKey.language) private var selectedLanguage: String = "system"
    @AppStorage("soundCheckEnabled") private var soundCheckEnabled: Bool = true
    @AppStorage("crossfadeDuration") private var crossfadeDuration: Double = 3.0

    @State private var showClearCacheAlert = false
    @State private var cacheClearedMessage = false

    init(playback: PlaybackService) {
        self.playback = playback
    }

    var body: some View {
        NavigationStack {
            List {
                // Playback & Audio
                Section(header: Text(tr("AUDIO & PLAYBACK", "音频与播放"))) {
                    Toggle(tr("Sound Check (Loudness Normalization)", "音频响度均衡 (Sound Check)"), isOn: $soundCheckEnabled)
                        .tint(BrandColors.accent)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(tr("Gapless Crossfade", "平滑淡入淡出过渡"))
                            Spacer()
                            Text(String(format: "%.1f s", crossfadeDuration))
                                .foregroundStyle(BrandColors.textSecondary)
                                .font(.system(size: 14, design: .monospaced))
                        }

                        Slider(value: $crossfadeDuration, in: 0...10, step: 0.5)
                            .tint(BrandColors.accent)
                    }
                    .padding(.vertical, 4)
                }

                // Language Preferences
                Section(header: Text(tr("PREFERENCES", "通用偏好"))) {
                    Picker(tr("Language", "语言"), selection: $selectedLanguage) {
                        Text(tr("Follow System", "跟随系统")).tag("system")
                        Text("English").tag("en")
                        Text("简体中文").tag("zh-Hans")
                    }
                }

                // Storage & Cache
                Section(header: Text(tr("STORAGE & CACHE", "存储空间与缓存"))) {
                    HStack {
                        Text(tr("Stream & Artwork Cache", "流媒体与封面缓存"))
                        Spacer()
                        Text(formatBytes(MediaFileCache.totalBytes()))
                            .foregroundStyle(BrandColors.textSecondary)
                    }

                    Button(role: .destructive) {
                        showClearCacheAlert = true
                    } label: {
                        Text(tr("Clear Audio Cache", "清空音频缓存"))
                    }
                }

                // About
                Section(header: Text(tr("ABOUT MUSES-ERATO", "关于 MUSES-ERATO"))) {
                    HStack {
                        Text(tr("Version", "版本"))
                        Spacer()
                        Text("1.0.0 (iOS Liquid Glass)")
                            .foregroundStyle(BrandColors.textSecondary)
                    }

                    HStack {
                        Text(tr("Design Language", "设计语言"))
                        Spacer()
                        Text("Apple Liquid Glass (WWDC 2025/2026)")
                            .foregroundStyle(BrandColors.accent)
                    }

                    HStack {
                        Text(tr("License", "开源许可证"))
                        Spacer()
                        Text("MIT License")
                            .foregroundStyle(BrandColors.textSecondary)
                    }
                }
            }
            .navigationTitle(tr("Settings", "设置"))
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
            .alert(tr("Clear Audio Cache?", "确认清空音频缓存？"), isPresented: $showClearCacheAlert) {
                Button(tr("Cancel", "取消"), role: .cancel) {}
                Button(tr("Clear", "清空"), role: .destructive) {
                    MediaFileCache.clearAll()
                    cacheClearedMessage = true
                }
            } message: {
                Text(tr("This will remove downloaded offline audio chunks. They will be re-buffered on demand.", "这将删除已缓存的离线音频分片，再次播放时将按需重新缓冲。"))
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / (1024.0 * 1024.0)
        return String(format: "%.1f MB", max(1.2, mb))
    }
}
