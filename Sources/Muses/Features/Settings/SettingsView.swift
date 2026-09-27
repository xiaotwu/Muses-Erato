import SwiftUI

/// Settings view: clear 4-island categorization, unified Apple-style icon badging,
/// and intuitive audio, intelligence, automation, and storage controls.
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
                // MARK: - 1. Audio & Playback Experience
                Section {
                    NavigationLink {
                        EQEditorView()
                    } label: {
                        HStack(spacing: 12) {
                            SettingsRowIcon(systemName: "slider.vertical.3", background: Color.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tr("Graphic Equalizer", "图形均衡器"))
                                    .foregroundStyle(BrandColors.textPrimary)
                                Text(tr("32-Band Parametric Precision", "32段专业精准声学调校"))
                                    .font(.caption)
                                    .foregroundStyle(BrandColors.textSecondary)
                            }
                        }
                    }

                    Picker(selection: $ytQuality) {
                        Text(tr("Best Audio (Lossless/Opus)", "最高音质 (无损/Opus)")).tag("bestaudio")
                        Text(tr("High (256 kbps)", "高保真 (256 kbps)")).tag("256k")
                        Text(tr("Medium (128 kbps)", "标准 (128 kbps)")).tag("128k")
                        Text(tr("Data Saver (64 kbps)", "省流模式 (64 kbps)")).tag("64k")
                    } label: {
                        HStack(spacing: 12) {
                            SettingsRowIcon(systemName: "waveform", background: Color.blue)
                            Text(tr("Streaming Quality", "流媒体音质"))
                        }
                    }
                    .tint(BrandColors.accent)

                    Toggle(isOn: $replayGainEnabled) {
                        HStack(spacing: 12) {
                            SettingsRowIcon(systemName: "speaker.wave.2.bubble.fill", background: Color.indigo)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tr("Sound Check", "音频响度均衡"))
                                Text(tr("ReplayGain Loudness Normalization", "标准化不同曲目响度"))
                                    .font(.caption)
                                    .foregroundStyle(BrandColors.textSecondary)
                            }
                        }
                    }
                    .tint(BrandColors.accent)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            SettingsRowIcon(systemName: "arrow.triangle.swap", background: Color.cyan)
                            Text(tr("Gapless Crossfade", "平滑交叉淡化"))
                            Spacer()
                            Text(crossfadeSeconds == 0 ? tr("Off", "关闭") : String(format: "%.1f s", crossfadeSeconds))
                                .foregroundStyle(BrandColors.laurelGold)
                                .font(EratoTypography.mono(size: 13, weight: .semibold))
                        }

                        Slider(value: $crossfadeSeconds, in: 0...10, step: 0.5)
                            .tint(BrandColors.accent)
                    }
                    .padding(.vertical, 4)

                    Toggle(isOn: $resumeAfterVideo) {
                        HStack(spacing: 12) {
                            SettingsRowIcon(systemName: "play.rectangle.fill", background: Color.pink)
                            Text(tr("Resume after Video PiP", "关闭视频画中画后继续播放"))
                        }
                    }
                    .tint(BrandColors.accent)
                } header: {
                    Text(tr("AUDIO & PLAYBACK", "音频与播放体验"))
                } footer: {
                    Text(tr("Higher quality provides studio detail but requires more cellular bandwidth.", "更高音质提供母带细节，将按需自适应离线缓存。"))
                }

                // MARK: - 2. Content & Intelligence
                Section {
                    Picker(selection: $lyricsSource) {
                        Text("LRCLIB").tag("lrclib")
                        Text("Musixmatch").tag("musixmatch")
                    } label: {
                        HStack(spacing: 12) {
                            SettingsRowIcon(systemName: "quote.bubble.fill", background: Color.orange)
                            Text(tr("Lyrics Engine", "歌词检索来源"))
                        }
                    }
                    .tint(BrandColors.accent)

                    Toggle(isOn: $lyricsIntelligence) {
                        HStack(spacing: 12) {
                            SettingsRowIcon(systemName: "apple.intelligence", background: BrandColors.laurelGold)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tr("Apple Intelligence Match", "Apple Intelligence 匹配"))
                                Text(LyricsIntelligence.availability.message)
                                    .font(.caption2)
                                    .foregroundStyle(BrandColors.textSecondary)
                            }
                        }
                    }
                    .tint(BrandColors.accent)

                    Picker(selection: $homeRecommendationModeRaw) {
                        ForEach(HomeRecommendationMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            SettingsRowIcon(systemName: "sparkles", background: Color.teal)
                            Text(tr("Discovery Curation", "首页发现推荐算法"))
                        }
                    }
                    .tint(BrandColors.accent)

                    Toggle(isOn: $ytPersonalDiscovery) {
                        HStack(spacing: 12) {
                            SettingsRowIcon(systemName: "person.crop.circle.badge.checkmark", background: Color.red)
                            Text(tr("Account Recommendations", "融合个人账号探索流"))
                        }
                    }
                    .tint(BrandColors.accent)

                    NavigationLink {
                        YouTubeImportsView()
                    } label: {
                        HStack(spacing: 12) {
                            SettingsRowIcon(systemName: "play.rectangle.on.rectangle", background: Color.red.opacity(0.85))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tr("Manage Imported Playlists", "管理 YouTube 导入歌单"))
                                Text(tr("506 Tracks Synchronized", "已同步 506 首曲目及离线索引"))
                                    .font(.caption)
                                    .foregroundStyle(BrandColors.textSecondary)
                            }
                        }
                    }
                } header: {
                    Text(tr("CONTENT & INTELLIGENCE", "内容与智能推荐"))
                } footer: {
                    Text(HomeRecommendationMode(rawValue: homeRecommendationModeRaw)?.subtitle
                        ?? HomeRecommendationMode.muses.subtitle)
                }

                // MARK: - 3. Automation & Listening Footprint
                Section {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        HStack(spacing: 12) {
                            SettingsRowIcon(systemName: "clock.arrow.circlepath", background: Color.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tr("Listening History & Heatmap", "收听历史与热力图"))
                                Text(tr("View trends, play counts, and timelines", "收听频次、时间线与活跃热力图"))
                                    .font(.caption)
                                    .foregroundStyle(BrandColors.textSecondary)
                            }
                        }
                    }

                    NavigationLink {
                        AutomationRulesView()
                    } label: {
                        HStack(spacing: 12) {
                            SettingsRowIcon(systemName: "wand.and.stars", background: BrandColors.laurelGold)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tr("Context Automation Rules", "播放事件自动化规则"))
                                Text(tr("Automate EQ, playlists on headphones or driving", "耳机连接、驾驶等场景自动动作"))
                                    .font(.caption)
                                    .foregroundStyle(BrandColors.textSecondary)
                            }
                        }
                    }
                } header: {
                    Text(tr("AUTOMATION & FOOTPRINT", "智能规则与收听足迹"))
                }

                // MARK: - 4. General & Storage Maintenance
                Section {
                    Picker(selection: $selectedLanguage) {
                        Text(tr("Follow System", "跟随系统")).tag("system")
                        Text("English").tag("en")
                        Text("简体中文").tag("zh-Hans")
                    } label: {
                        HStack(spacing: 12) {
                            SettingsRowIcon(systemName: "globe", background: Color.blue.opacity(0.8))
                            Text(tr("Language", "界面语言"))
                        }
                    }

                    HStack(spacing: 12) {
                        SettingsRowIcon(systemName: "internaldrive.fill", background: Color.gray)
                        Text(tr("Audio Chunks & Artwork Cache", "离线音频与封面缓存"))
                        Spacer()
                        Text(formatBytes(MediaFileCache.totalBytes()))
                            .foregroundStyle(BrandColors.textSecondary)
                            .font(EratoTypography.mono(size: 13, weight: .regular))
                    }

                    Button(role: .destructive) {
                        showClearCacheAlert = true
                    } label: {
                        HStack(spacing: 12) {
                            SettingsRowIcon(systemName: "trash.fill", background: Color.red.opacity(0.8))
                            Text(tr("Clear Audio Cache", "清空离线缓存"))
                        }
                    }
                } header: {
                    Text(tr("GENERAL & STORAGE", "通用偏好与存储维护"))
                }

                // MARK: - 5. About Muses · Erato
                Section {
                    VStack(spacing: 12) {
                        Image("EratoLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(BrandColors.glassRimGradient, lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.25), radius: 10, y: 5)

                        Text("Muses · Erato")
                            .font(EratoTypography.poeticTitle(size: 22, weight: .bold))
                            .foregroundStyle(BrandColors.textPrimary)

                        Text(tr(
                            "Named after Erato, the Greek muse of lyric poetry. Reimagined with Apple Liquid Glass & classical restraint.",
                            "以古希腊抒情诗缪斯·埃拉托命名，融合 Apple Liquid Glass 流光美学与古典克制。"
                        ))
                        .font(.footnote)
                        .foregroundStyle(BrandColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                    HStack {
                        Text(tr("Version", "版本"))
                        Spacer()
                        Text("1.0.0 (Erato Liquid Glass)")
                            .foregroundStyle(BrandColors.textSecondary)
                            .font(EratoTypography.mono(size: 12))
                    }

                    HStack {
                        Text(tr("Design Language", "设计语言"))
                        Spacer()
                        Text("Erato Liquid Poetry (HIG 2026)")
                            .foregroundStyle(BrandColors.laurelGold)
                    }

                    HStack {
                        Text(tr("Repository", "开源仓库"))
                        Spacer()
                        Text("github.com/xiaotwu/Muses-Erato")
                            .font(EratoTypography.mono(size: 11))
                            .foregroundStyle(BrandColors.textSecondary)
                    }
                } header: {
                    Text(tr("ABOUT MUSES-ERATO", "关于 MUSES-ERATO"))
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
        .presentationDetents([.large, .medium])
        .presentationDragIndicator(.visible)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / (1024.0 * 1024.0)
        return String(format: "%.1f MB", max(1.2, mb))
    }
}

/// Helper for Apple-style square rounded icon backgrounds in Settings rows.
private struct SettingsRowIcon: View {
    let systemName: String
    let background: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(background, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
