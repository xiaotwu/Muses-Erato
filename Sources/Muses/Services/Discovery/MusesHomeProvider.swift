import Foundation

/// Local-only Home feed built from library and listening activity.
/// No network calls — Muses mode stays usable offline.
@MainActor
final class MusesHomeProvider: HomeDiscoveryProvider {
    private let library: LibraryService
    private let displayLimit: Int

    init(library: LibraryService, displayLimit: Int = 12) {
        self.library = library
        self.displayLimit = displayLimit
    }

    func fetch(for input: HomeDiscoveryInput) async -> HomeFetchResult {
        var sections: [HomeSection] = []

        let recent = library.recentlyPlayedTracks(limit: displayLimit)
        if !recent.isEmpty {
            sections.append(HomeSection(
                id: "muses-listen-again",
                title: tr("Listen again", "再听一次"),
                subtitle: tr("From your library", "来自你的资料库"),
                kind: .quickPicks,
                items: recent.map { .track($0) },
                source: .localLibrary
            ))
        }

        let onRepeat = onRepeatTracks(limit: displayLimit)
        if !onRepeat.isEmpty {
            sections.append(HomeSection(
                id: "muses-on-repeat",
                title: tr("On repeat", "循环播放"),
                subtitle: tr("Your most-played tracks", "播放次数最多的歌曲"),
                kind: .songGrid,
                items: onRepeat.map { .track($0) },
                source: .localLibrary
            ))
        }

        let liked = library.likedTracks().prefix(displayLimit).map { TrackSnapshot(from: $0) }
        if !liked.isEmpty {
            sections.append(HomeSection(
                id: "muses-liked",
                title: tr("Liked songs", "喜欢的歌曲"),
                subtitle: tr("From your library", "来自你的资料库"),
                kind: .songGrid,
                items: liked.map { .track($0) },
                source: .localLibrary
            ))
        }

        let added = recentlyAddedTracks(limit: displayLimit)
        if !added.isEmpty {
            sections.append(HomeSection(
                id: "muses-recently-added",
                title: tr("Recently added", "最近添加"),
                subtitle: tr("Fresh in your library", "刚加入资料库"),
                kind: .albumCarousel,
                items: added.map { .track($0) },
                source: .localLibrary
            ))
        }

        if sections.isEmpty {
            sections.append(HomeSection(
                id: "muses-empty",
                title: tr("Your Muses Home", "你的 Muses 首页"),
                subtitle: tr(
                    "Play or like tracks to build local recommendations.",
                    "播放或点赞歌曲后，这里会生成本机推荐。"
                ),
                kind: .mixed,
                items: [],
                status: .loaded,
                source: .localLibrary
            ))
        }

        return .baseline(scope: input.scope, sections: sections)
    }

    private func onRepeatTracks(limit: Int) -> [TrackSnapshot] {
        let tracks = library.allTracks()
            .filter { $0.playCount >= 2 }
            .sorted { lhs, rhs in
                if lhs.playCount != rhs.playCount { return lhs.playCount > rhs.playCount }
                return (lhs.lastPlayedAt ?? .distantPast) > (rhs.lastPlayedAt ?? .distantPast)
            }
            .prefix(limit)
        return tracks.map { TrackSnapshot(from: $0) }
    }

    private func recentlyAddedTracks(limit: Int) -> [TrackSnapshot] {
        let tracks = library.allTracks()
            .sorted { $0.addedAt > $1.addedAt }
            .prefix(limit)
        return tracks.map { TrackSnapshot(from: $0) }
    }
}
