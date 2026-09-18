import SwiftUI

/// Main container: floating Liquid Glass tab bar (Home / Browse / Library),
/// docked MiniPlayer, and a circular Search FAB at bottom-trailing.
struct MainTabView: View {
    @Bindable var playback: PlaybackService
    @State private var selectedTab: Int = 0
    @State private var showNowPlaying: Bool = false
    @State private var showSettings: Bool = false
    @State private var showSearch: Bool = false
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
            }
            .toolbar(.hidden, for: .tabBar)
            .tint(BrandColors.accent)

            // Full-width dock: MiniPlayer and (tab capsule + Search FAB) share the same inset.
            VStack(spacing: AppleMusicTokens.miniPlayerDockMargin) {
                if playback.state.track != nil {
                    let shape = RoundedRectangle(cornerRadius: AppleMusicTokens.miniPlayerCornerRadius, style: .continuous)
                    MiniPlayerBar(playback: playback, isNowPlayingExpanded: $showNowPlaying)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppleMusicTokens.miniPlayerHeight + 2.5)
                        .background(.ultraThinMaterial, in: shape)
                        .overlay { shape.stroke(BrandColors.hairline.opacity(0.9), lineWidth: 0.6) }
                        .laserStroke(cornerRadius: AppleMusicTokens.miniPlayerCornerRadius, lineWidth: 0.9, opacity: 0.62)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                HStack(alignment: .center, spacing: 10) {
                    floatingTabBar
                        .frame(maxWidth: .infinity)
                    searchFAB
                }
                .frame(maxWidth: .infinity)
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
        .fullScreenCover(isPresented: $showSearch) {
            NavigationStack {
                SearchView(playback: playback, isPresented: $showSearch)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                showSearch = false
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(width: 36, height: 36)
                            }
                            .musesControls()
                            .accessibilityLabel(tr("Close", "关闭"))
                        }
                    }
            }
            .environment(playback)
        }
    }


    private var searchFAB: some View {

        Button {
            triggerHapticFeedback()
            showSearch = true
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(BrandColors.textPrimary)
                .frame(width: 54, height: 54)
                .contentShape(Circle())
        }
        .buttonStyle(MusesPressStyle(scale: MusesMotion.pressScale))
        .musesGlass(in: Circle(), role: .compactControl)
        .laserStroke(Circle(), lineWidth: 1.15, opacity: 0.78)
        .accessibilityLabel(tr("Search", "搜索"))
    }

    private var floatingTabBar: some View {
        MusesGlassGroup(spacing: 0) {
            HStack(spacing: 0) {
                tabButton(index: 0, title: tr("Home", "首页"), systemImage: "house.fill")
                tabButton(index: 1, title: tr("Browse", "发现"), systemImage: "square.grid.2x2.fill")
                tabButton(index: 2, title: tr("Library", "资料库"), systemImage: "music.note.list")
            }
            .padding(4)
            .frame(height: AppleMusicTokens.tabBarHeight)
            .musesGlassCapsule(role: .tabBar)
            .laserStroke(Capsule(), lineWidth: 1.05, opacity: 0.65)
        }
    }

    private func tabButton(index: Int, title: String, systemImage: String) -> some View {
        let isSelected = selectedTab == index

        return Button {
            triggerHapticFeedback()
            withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.78)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: isSelected ? .bold : .medium))
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
                        .regular.tint(BrandColors.accent.opacity(0.22)).interactive(!reduceMotion),
                        in: Capsule()
                    )
                    .glassEffectID("tab-selection", in: tabGlass)
            } else {
                Capsule().fill(BrandColors.accent.opacity(0.14))
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
            showSearch = true
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
