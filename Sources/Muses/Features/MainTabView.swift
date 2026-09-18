import SwiftUI

/// Main container for Muses-Erato iOS, featuring a floating Liquid Glass tab bar and docked MiniPlayer.
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
            // Main Content Area
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

            // Floating Functional Layer: MiniPlayer + Floating TabBar
            VStack(spacing: AppleMusicTokens.miniPlayerDockMargin) {
                // Floating MiniPlayer (appears when a track is active)
                if playback.state.track != nil {
                    MiniPlayerBar(playback: playback, isNowPlayingExpanded: $showNowPlaying)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Floating Liquid Glass Tab Bar
                floatingTabBar
                    .padding(.horizontal, AppleMusicTokens.tabBarFloatingInset)
            }
            .padding(.bottom, 6)
        }
        .fullScreenCover(isPresented: $showNowPlaying) {
            NowPlayingView(playback: playback, isPresented: $showNowPlaying)
                .environment(playback)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(playback: playback)
                .environment(playback)
        }
    }

    // MARK: - Floating Liquid Glass Tab Bar

    private var floatingTabBar: some View {
        MusesGlassGroup(spacing: 0) {
            HStack(spacing: 0) {
                tabButton(index: 0, title: tr("Home", "首页"), systemImage: "house.fill")
                tabButton(index: 1, title: tr("Browse", "发现"), systemImage: "square.grid.2x2.fill")
                tabButton(index: 2, title: tr("Library", "资料库"), systemImage: "music.note.list")
                tabButton(index: 3, title: tr("Search", "搜索"), systemImage: "magnifyingglass")
            }
            .padding(4)
            .frame(height: AppleMusicTokens.tabBarHeight)
            .musesGlassCapsule(role: .tabBar)
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
                        .regular.tint(BrandColors.accent.opacity(0.32)).interactive(!reduceMotion),
                        in: Capsule()
                    )
                    .glassEffectID("tab-selection", in: tabGlass)
            } else {
                Capsule().fill(BrandColors.accent.opacity(0.16))
            }
        }
    }

    private func triggerHapticFeedback() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
}
