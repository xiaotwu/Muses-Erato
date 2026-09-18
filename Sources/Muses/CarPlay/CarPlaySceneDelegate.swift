import CarPlay
import UIKit

/// CarPlay audio scene.
///
/// Enable **CarPlay Audio** (`com.apple.developer.carplay-audio`) on the App ID
/// in Apple Developer before a device build. Simulator can still attach this scene.
/// The iPhone UI does not depend on the entitlement.
///
/// Steering-wheel play/pause/next use `MPRemoteCommandCenter` via `NowPlayingManager`.
@objc(CarPlaySceneDelegate)
@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var session: CarPlayInterfaceSession?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        let session = CarPlayInterfaceSession(controller: interfaceController)
        self.session = session
        session.connect()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        session?.disconnect()
        session = nil
        interfaceController = nil
    }
}

@MainActor
final class CarPlayInterfaceSession: NSObject, @MainActor CPNowPlayingTemplateObserver, @MainActor CPTabBarTemplateDelegate {
    private let controller: CPInterfaceController
    private var tabBar: CPTabBarTemplate?
    private var recentlyTemplate: CPListTemplate?
    private var playlistsTemplate: CPListTemplate?
    private var favoritesTemplate: CPListTemplate?
    private var recentSnapshots: [TrackSnapshot] = []
    private var favoriteSnapshots: [TrackSnapshot] = []

    init(controller: CPInterfaceController) {
        self.controller = controller
        super.init()
    }

    func connect() {
        let recently = makeList(
            title: "Recently",
            systemImage: "clock",
            emptyTitle: "Nothing played yet",
            emptySubtitle: "Play a song on iPhone first"
        )
        let playlists = makeList(
            title: "Playlists",
            systemImage: "music.note.list",
            emptyTitle: "No playlists",
            emptySubtitle: "Import or create playlists in Muses"
        )
        let favorites = makeList(
            title: "Favorites",
            systemImage: "heart",
            emptyTitle: "No favorites",
            emptySubtitle: "Like a song in Muses"
        )
        recentlyTemplate = recently
        playlistsTemplate = playlists
        favoritesTemplate = favorites

        let nowPlaying = CPNowPlayingTemplate.shared
        nowPlaying.tabTitle = "Now Playing"
        nowPlaying.tabImage = UIImage(systemName: "play.circle")
        nowPlaying.isUpNextButtonEnabled = true
        nowPlaying.add(self)

        reload()
        let tabs = CPTabBarTemplate(templates: [recently, playlists, favorites, nowPlaying])
        tabs.delegate = self
        tabBar = tabs
        controller.setRootTemplate(tabs, animated: false, completion: nil)
    }

    func disconnect() {
        CPNowPlayingTemplate.shared.remove(self)
        tabBar = nil
        recentlyTemplate = nil
        playlistsTemplate = nil
        favoritesTemplate = nil
    }

    func tabBarTemplate(_ tabBarTemplate: CPTabBarTemplate, didSelect selectedTemplate: CPTemplate) {
        if selectedTemplate === recentlyTemplate || selectedTemplate === playlistsTemplate
            || selectedTemplate === favoritesTemplate {
            reload()
        }
    }

    func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
        guard let playback = MusesRuntime.playback else { return }
        let items = playback.queue.items.map(\.track)
        let page = CarPlayBrowseCatalogBuilder.playlistPage(items)
        let template = makeList(
            title: "Up Next",
            systemImage: "list.bullet",
            emptyTitle: "Queue is empty",
            emptySubtitle: "Choose a song from Recently or Playlists"
        )
        template.updateSections([section(from: page, snapshots: items, source: .songs)])
        controller.pushTemplate(template, animated: true, completion: nil)
    }

    private func reload() {
        guard let source = librarySource() else {
            recentlyTemplate?.updateSections([])
            playlistsTemplate?.updateSections([])
            favoritesTemplate?.updateSections([])
            return
        }
        let catalog = source.catalog()
        recentSnapshots = source.recentlyPlayed()
        favoriteSnapshots = source.favorites()

        recentlyTemplate?.updateSections([
            section(from: catalog.recentlyPlayed, snapshots: recentSnapshots, source: .recently)
        ])
        playlistsTemplate?.updateSections([playlistSection(catalog.playlists)])
        favoritesTemplate?.updateSections([
            section(from: catalog.favorites, snapshots: favoriteSnapshots, source: .songs)
        ])
    }

    private func librarySource() -> CarPlayLibrarySource? {
        guard let library = MusesRuntime.library, let playlists = MusesRuntime.playlists else {
            return nil
        }
        return CarPlayLibrarySource(library: library, playlists: playlists)
    }

    private func makeList(
        title: String,
        systemImage: String,
        emptyTitle: String,
        emptySubtitle: String
    ) -> CPListTemplate {
        let template = CPListTemplate(title: title, sections: [])
        template.tabTitle = title
        template.tabImage = UIImage(systemName: systemImage)
        template.emptyViewTitleVariants = [emptyTitle]
        template.emptyViewSubtitleVariants = [emptySubtitle]
        return template
    }

    private func section(
        from items: [CarPlayTrackItem],
        snapshots: [TrackSnapshot],
        source: QueueSource
    ) -> CPListSection {
        let byID = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0) })
        let listItems: [CPListItem] = items.compactMap { item in
            guard let track = byID[item.id] else { return nil }
            let row = CPListItem(text: item.title, detailText: item.artist)
            row.userInfo = item.id
            row.handler = { [weak self] _, completion in
                self?.play(track, context: snapshots, source: source)
                completion()
            }
            return row
        }
        return CPListSection(items: listItems)
    }

    private func playlistSection(_ playlists: [CarPlayPlaylistSummary]) -> CPListSection {
        let rows: [CPListItem] = playlists.map { playlist in
            let detail = playlist.trackCount == 1 ? "1 song" : "\(playlist.trackCount) songs"
            let row = CPListItem(text: playlist.title, detailText: detail)
            row.accessoryType = .disclosureIndicator
            row.userInfo = playlist.id
            row.handler = { [weak self] _, completion in
                self?.openPlaylist(playlist)
                completion()
            }
            return row
        }
        return CPListSection(items: rows)
    }

    private func openPlaylist(_ playlist: CarPlayPlaylistSummary) {
        let tracks = librarySource()?.playlistTracks(id: playlist.id) ?? []
        let page = CarPlayBrowseCatalogBuilder.playlistPage(tracks)
        let template = makeList(
            title: playlist.title,
            systemImage: "music.note.list",
            emptyTitle: "Playlist is empty",
            emptySubtitle: "Add songs in Muses"
        )
        template.updateSections([section(from: page, snapshots: tracks, source: .playlist)])
        controller.pushTemplate(template, animated: true, completion: nil)
    }

    private func play(_ track: TrackSnapshot, context: [TrackSnapshot], source: QueueSource) {
        let request: CarPlayPlayRequest
        switch source {
        case .recently:
            request = CarPlayPlaybackRouter.recently(track, in: context)
        case .playlist:
            request = CarPlayPlaybackRouter.playlist(track, in: context)
        default:
            request = CarPlayPlaybackRouter.favorites(track, in: context)
        }
        guard case let .play(start, queue, from) = request else { return }
        MusesRuntime.playback?.playTrack(start, context: queue, from: from)
        showNowPlaying()
    }

    private func showNowPlaying() {
        let nowPlaying = CPNowPlayingTemplate.shared
        if controller.topTemplate === nowPlaying { return }
        if controller.templates.contains(where: { $0 === nowPlaying }) {
            controller.popToRootTemplate(animated: true, completion: nil)
            return
        }
        tabBar?.select(nowPlaying)
    }
}
