import SwiftUI

/// Settings view for audio options, YouTube integration, automation rules, and application preferences.
struct SettingsView: View {
    @Bindable var playback: PlaybackService
    @Environment(\.dismiss) private var dismiss

    @AppStorage(PrefKey.language) private var selectedLanguage: String = "system"
    @AppStorage(PrefKey.ytAudioQuality) private var ytQuality: String = "bestaudio"
    @AppStorage(PrefKey.crossfadeSeconds) private var crossfadeSeconds: Double = 3.0
    @AppStorage(PrefKey.replayGainEnabled) private var replayGainEnabled: Bool = true
    @AppStorage(PrefKey.resumeAfterVideo) private var resumeAfterVideo: Bool = true
    @AppStorage(PrefKey.ytPersonalDiscovery) private var ytPersonalDiscovery: Bool = true
    @AppStorage(PrefKey.homeRecommendationMode) private var homeRecommendationModeRaw: String = HomeRecommendationMode.muses.rawValue
    @AppStorage(PrefKey.lyricsSource) private var lyricsSource: String = "lrclib"
    @AppStorage(PrefKey.lyricsIntelligence) private var lyricsIntelligence: Bool = true

    @State private var showClearCacheAlert = false
    @State private var cacheClearedMessage = false

    init(playback: PlaybackService) {
        self.playback = playback
    }

    var body: some View {
        NavigationStack {
            List {
                // Audio Quality
                Section(header: Text(tr("AUDIO STREAMING QUALITY", "音频流媒体音质")),
                        footer: Text(tr("Higher quality provides studio detail but requires more cellular bandwidth.",
                                       "更高音质提供更丰富的细节，但会消耗更多蜂窝网络数据。"))) {
                    Picker(tr("Audio Quality", "首选音质"), selection: $ytQuality) {
                        Text(tr("Best Audio (Lossless/Opus)", "最高音质 (无损/Opus)")).tag("bestaudio")
                        Text(tr("High (256 kbps)", "高保真 (256 kbps)")).tag("256k")
                        Text(tr("Medium (128 kbps)", "标准 (128 kbps)")).tag("128k")
                        Text(tr("Data Saver (64 kbps)", "省流模式 (64 kbps)")).tag("64k")
                    }
                    .tint(BrandColors.accent)
                }

                // Playback
                Section(header: Text(tr("PLAYBACK", "播放效果"))) {
                    Toggle(tr("Sound Check (ReplayGain Normalization)", "音频响度均衡 (ReplayGain)"), isOn: $replayGainEnabled)
                        .tint(BrandColors.accent)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(tr("Gapless Crossfade", "平滑无缝过渡"))
                            Spacer()
                            Text(crossfadeSeconds == 0 ? tr("Off", "关闭") : String(format: "%.1f s", crossfadeSeconds))
                                .foregroundStyle(BrandColors.textSecondary)
                                .font(.system(size: 14, design: .monospaced))
                        }

                        Slider(value: $crossfadeSeconds, in: 0...10, step: 0.5)
                            .tint(BrandColors.accent)
                    }
                    .padding(.vertical, 4)

                    Toggle(tr("Resume music when video closes", "关闭视频画中画后继续播放"), isOn: $resumeAfterVideo)
                        .tint(BrandColors.accent)
                }



                Section(header: Text(tr("LYRICS", "歌词")),
                        footer: Text(tr(
                            "Apple Intelligence only chooses among LRCLIB candidates. It never invents lyrics.",
                            "Apple Intelligence 只会从 LRCLIB 候选中选择，不会编造歌词。"
                        ))) {
                    Picker(tr("Lyrics source", "歌词来源"), selection: $lyricsSource) {
                        Text("LRCLIB").tag("lrclib")
                        Text("Musixmatch").tag("musixmatch")
                    }
                    .tint(BrandColors.accent)
                    Toggle(tr("Apple Intelligence matching", "Apple Intelligence 匹配"), isOn: $lyricsIntelligence)
                        .tint(BrandColors.accent)
                    Text(LyricsIntelligence.availability.message)
                        .font(.footnote)
                        .foregroundStyle(BrandColors.textSecondary)
                }

                // Home recommendation source
                Section(header: Text(tr("HOME RECOMMENDATIONS", "首页推荐")),
                        footer: Text(HomeRecommendationMode(rawValue: homeRecommendationModeRaw)?.subtitle
                                    ?? HomeRecommendationMode.muses.subtitle)) {
                    Picker(tr("Recommendation source", "推荐来源"), selection: $homeRecommendationModeRaw) {
                        ForEach(HomeRecommendationMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .tint(BrandColors.accent)
                }

                // YouTube Integration
                Section(header: Text(tr("YOUTUBE & CLOUD SYNC", "YOUTUBE 与云端同步"))) {
                    Toggle(tr("Personal Discovery Recommendations", "包含账号个性化探索推荐"), isOn: $ytPersonalDiscovery)
                        .tint(BrandColors.accent)

                    NavigationLink {
                        YouTubeImportsView()
                    } label: {
                        HStack {
                            Label(tr("Manage Imported Playlists", "管理 YouTube 导入歌单"), systemImage: "play.rectangle.on.rectangle")
                        }
                    }
                }

                // Automation Rules
                Section(header: Text(tr("SMART AUTOMATION", "智能自动化"))) {
                    NavigationLink {
                        AutomationRulesView()
                    } label: {
                        HStack {
                            Label(tr("Context Automation Rules", "播放事件自动化规则"), systemImage: "wand.and.stars")
                        }
                    }
                }

                // Language Preferences
                
                // Tools (History reachable after Library slim-down)
                Section(header: Text(tr("TOOLS", "工具"))) {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Label(tr("Listening History", "收听历史"), systemImage: "clock.arrow.circlepath")
                    }
                }

                Section(header: Text(tr("LANGUAGE & PREFERENCES", "通用偏好"))) {
                    Picker(tr("Language", "界面语言"), selection: $selectedLanguage) {
                        Text(tr("Follow System", "跟随系统")).tag("system")
                        Text("English").tag("en")
                        Text("简体中文").tag("zh-Hans")
                    }
                }

                // Storage & Cache
                Section(header: Text(tr("STORAGE & CACHE", "存储空间与缓存"))) {
                    HStack {
                        Text(tr("Stream Chunks & Artwork Cache", "音频分片与封面缓存"))
                        Spacer()
                        Text(formatBytes(MediaFileCache.totalBytes()))
                            .foregroundStyle(BrandColors.textSecondary)
                    }

                    Button(role: .destructive) {
                        showClearCacheAlert = true
                    } label: {
                        Text(tr("Clear Audio Cache", "清空离线缓存"))
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
                        Text("Apple Liquid Glass HIG")
                            .foregroundStyle(BrandColors.accent)
                    }

                    HStack {
                        Text(tr("Repository", "开源仓库"))
                        Spacer()
                        Text("github.com/xiaotwu/Muses-Erato")
                            .font(.caption)
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
                    .musesAction(prominent: true)
                    .tint(BrandColors.accent)
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
