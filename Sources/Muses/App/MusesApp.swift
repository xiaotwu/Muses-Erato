import SwiftUI
import SwiftData
import AVFoundation

@main
struct MusesApp: App {
    private let container: ModelContainer
    @State private var playback: PlaybackService
    private let nowPlayingManager: NowPlayingManager

    init() {
        // Initialize SwiftData store
        let storeResult = makeModelContainerWithFallback()
        self.container = storeResult.container

        // Initialize Audio Session for Background Playback
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to initialize AVAudioSession: \(error)")
        }
        #endif

        // Instantiate Playback Engine & Core Services
        let engine = YouTubeStreamEngine()
        let queue = QueueService()
        queue.modelContext = ModelContext(storeResult.container)
        let library = LibraryService(modelContainer: storeResult.container)
        let playbackService = PlaybackService(engine: engine, queue: queue, library: library)

        self._playback = State(initialValue: playbackService)
        self.nowPlayingManager = NowPlayingManager(playbackService, library: library, queue: queue)

        // Seed initial sample track if queue is empty
        if playbackService.state.track == nil {
            let sample = TrackSnapshot(
                id: UUID(),
                title: "Triumph on the Ice (Erato Remix)",
                artist: "Streetwise Rhapsody",
                albumTitle: "Snezhnaya Melodies",
                durationSeconds: 214,
                youTubeId: "sample-erato-1",
                artworkUrl: nil,
                sampleRate: 48000,
                bitDepth: 24,
                codec: "AAC",
                isLossless: true,
                lyrics: "[00:00.00]Triumph on the Ice (Erato Remix)\n[00:05.00]Streetwise Rhapsody • Muses iOS\n[00:14.00]Apple Liquid Glass Interface Active\n[00:26.50]Crystal clear audio on iOS\n[00:40.00]32-Band Equalizer processing"
            )
            playbackService.state.track = sample
            playbackService.state.duration = 214.0
            playbackService.state.position = 0.0
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(playback: playback)
                .modelContainer(container)
                .preferredColorScheme(.dark)
        }
    }
}
