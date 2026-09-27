import SwiftUI

/// Main container: floating Liquid Glass tab bar (Home / Browse / Library / Search)
/// and docked MiniPlayer capsule.
struct MainTabView: View {
    @Bindable var playback: PlaybackService
    @State private var selectedTab: Int = 0
    @State private var showNowPlaying: Bool = false
    @State private var showSettings: Bool = false
    @Namespace private var tabGlass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    init(playback: PlaybackService) {
        self.playback = playback
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(playback: playback, showSettings: $showSettings)
                    .tag(0)
                    .toolbar(.hidden, for: .tabBar)

                BrowseView(playback: playback)
                    .tag(1)
                    .toolbar(.hidden, for: .tabBar)

                LibraryView(playback: playback)
                    .tag(2)
                    .toolbar(.hidden, for: .tabBar)

                SearchView(playback: playback)
                    .tag(3)
                    .toolbar(.hidden, for: .tabBar)
            }
            .toolbar(.hidden, for: .tabBar)
            .tint(BrandColors.accent)

            // Docked floating functional layer: MiniPlayer & 4-Tab Liquid Glass Capsule
            VStack(spacing: AppleMusicTokens.miniPlayerDockMargin) {
                if playback.state.track != nil {
                    let shape = RoundedRectangle(cornerRadius: AppleMusicTokens.miniPlayerCornerRadius, style: .continuous)
                    MiniPlayerBar(playback: playback, isNowPlayingExpanded: $showNowPlaying)
                        .frame(maxWidth: 580)
                        .frame(height: AppleMusicTokens.miniPlayerHeight + 2.5)
                        .background(.ultraThinMaterial, in: shape)
                        .overlay {
                            shape.stroke(
                                BrandColors.glassRimGradient,
                                lineWidth: 0.65
                            )
                        }
                        .shadow(color: BrandColors.glassShadow, radius: 10, x: 0, y: 4)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }

                floatingTabBar
                    .frame(maxWidth: 480)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppleMusicTokens.tabBarFloatingInset)
            .padding(.bottom, 6)
        }
        .fullScreenCover(isPresented: $showNowPlaying) {
            NowPlayingView(playback: playback, isPresented: $showNowPlaying)
                .environment(playback)
        }
        #if DEBUG
        .task {
            // Delay so covers/sheets are not cleared by the first layout pass.
            try? await Task.sleep(nanoseconds: 400_000_000)
            applyDebugScreenFlags()
        }
        #endif
        .sheet(isPresented: $showSettings) {
            SettingsView(playback: playback)
                .environment(playback)
        }
    }

    // MARK: - 4-Tab Liquid Glass Capsule

    private var floatingTabBar: some View {
        MusesGlassGroup(spacing: 0) {
            HStack(spacing: 4) {
                tabButton(index: 0, title: tr("Home", "首页"), systemImage: "house.fill")
                tabButton(index: 1, title: tr("Browse", "发现"), systemImage: "square.grid.2x2.fill")
                tabButton(index: 2, title: tr("Library", "资料库"), systemImage: "music.note.list")
                tabButton(index: 3, title: tr("Search", "搜索"), systemImage: "magnifyingglass")
            }
            .padding(4)
            .frame(height: AppleMusicTokens.tabBarHeight)
            .musesGlassCapsule(role: .tabBar)
            .overlay {
                Capsule()
                    .stroke(BrandColors.glassRimGradient, lineWidth: 0.7)
            }
            .shadow(color: BrandColors.glassShadow, radius: 14, x: 0, y: 6)
        }
    }

    private func tabButton(index: Int, title: String, systemImage: String) -> some View {
        let isSelected = selectedTab == index

        return Button {
            triggerHapticFeedback()
            withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 19, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? BrandColors.accent : BrandColors.textSecondary)

                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? BrandColors.accent : BrandColors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Capsule())
            .background { tabSelectionChrome(isSelected: isSelected) }
        }
        .buttonStyle(MusesPressStyle(scale: MusesMotion.pressScale))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func tabSelectionChrome(isSelected: Bool) -> some View {
        if isSelected {
            if #available(iOS 26.0, *), !reduceTransparency, contrast != .increased {
                Color.clear
                    .glassEffect(
                        .regular.tint(BrandColors.laurelGold.opacity(0.18)).interactive(!reduceMotion),
                        in: Capsule()
                    )
                    .glassEffectID("tab-selection", in: tabGlass)
                    .overlay {
                        Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                    }
            } else {
                Capsule()
                    .fill(BrandColors.surface.opacity(0.85))
                    .overlay {
                        Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    }
            }
        }
    }

    #if DEBUG
    private func applyDebugScreenFlags() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "muses.debug.selectedTab") != nil {
            selectedTab = defaults.integer(forKey: "muses.debug.selectedTab")
            defaults.removeObject(forKey: "muses.debug.selectedTab")
        }
        if defaults.bool(forKey: "muses.debug.expandNowPlaying") {
            defaults.set(false, forKey: "muses.debug.expandNowPlaying")
            showNowPlaying = true
        }
        if defaults.bool(forKey: "muses.debug.showSearch") {
            defaults.set(false, forKey: "muses.debug.showSearch")
            selectedTab = 3
        }
        if defaults.bool(forKey: "muses.debug.showSettings") {
            defaults.set(false, forKey: "muses.debug.showSettings")
            showSettings = true
        }
    }
    #endif

    private func triggerHapticFeedback() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
}
