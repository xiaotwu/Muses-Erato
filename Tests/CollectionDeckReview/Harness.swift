import SwiftUI
import SwiftData
import MusesDomain
import MusesPersistence

@main struct CollectionDeckReviewApp: App {
    @State private var session = Self.fixture()
    @MainActor static func fixture() -> PublicYouTubeSession {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("library.sqlite")
        let container = try! SwiftDataSnapshotRepository.container(url: url)
        let repo = SwiftDataSnapshotRepository(context: ModelContext(container))
        let titles = ["Midnight City", "Dreams", "Blue in Green", "Nightcall", "Everything in Its Right Place", "Teardrop", "Innerbloom", "A Walk", "Dayvan Cowboy"]
        let videos = ["dQw4w9WgXcQ", "jNQXAC9IVRw", "9bZkp7q19f0", "M7lc1UVf-VE"]
        let count = ProcessInfo.processInfo.environment["DECK_LARGE"] == "1" ? 5000 : 9
        var tracks: [MusesDomain.Track] = []
        for i in 0..<count {
            let video = videos[i % videos.count]
            let track = MusesDomain.Track(id: try! TrackID(UUID().uuidString), title: titles[i % titles.count], artist: "Collection sessions · \(i + 1)",
                source: .youtubeVideo(try! VideoID(video)), provenance: try! Provenance(provider: ProviderID("youtube"), originalID: video), metadataOrigin: .user)
            tracks.append(track)
            repo.context.insert(MusesSchemaV1.Record(kind: .track, recordID: track.id.rawValue, payload: try! JSONEncoder().encode(track)))
        }
        try! repo.context.save()
        let playlist = try! LocalPlaylist(name: "Late night selections", trackIDs: tracks.map(\.id),
            occurrences: tracks.enumerated().flatMap { index, track -> [LocalPlaylistOccurrence] in
                index == 1 ? [.init(id: UUID(), trackID: track.id), .init(id: UUID(), trackID: nil), .init(id: UUID(), trackID: track.id)] : [.init(id: UUID(), trackID: track.id)]
            })
        try! repo.savePlaylist(playlist)
        return PublicYouTubeSession(storeURL: url, deleteCredentials: {}, deleteWebsiteData: {})
    }
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text("Songs").font(.largeTitle.bold())
                            Spacer()
                            PublicLibraryClearButton(session: session, category: .songs)
                        }
                        PublicLibraryHeroShelf(session: session, tracks: session.tracks, category: .songs, presentation: .constant(.cards))
                        Divider()
                        ForEach(session.playlists) { playlist in PublicPlaylistBlock(session: session, playlist: playlist) }
                        Text("End of collection").font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("review.bottom")
                    }.padding(.horizontal, 18).padding(.vertical, 12)
                }.accessibilityIdentifier("review.scroll")
                .fullScreenCover(isPresented: $session.showPlayer) { PublicPlayerView(session: session) }
            }.preferredColorScheme(.dark)
        }
    }
}
