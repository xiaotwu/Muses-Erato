import Foundation
import ActivityKit
import WidgetKit
#if canImport(UIKit)
import UIKit
#endif

/// Writes the App Group snapshot, drives one listening Live Activity, and reloads widgets.
@MainActor
final class NowPlayingSessionCoordinator {
    private let playback: PlaybackService
    private let store: NowPlayingSnapshotStore
    private let policy: LiveActivitySessionPolicy
    private var loop: Task<Void, Never>?
    private var activity: Activity<ListeningActivityAttributes>?
    private var startedAt: Date?
    private var lastPausedAt: Date?
    private var lastArtworkURL: String?
    private var lastWidgetSignature: String?
    private var darwinObserver: DarwinPlaybackObserver?

    init(
        playback: PlaybackService,
        store: NowPlayingSnapshotStore = .shared,
        policy: LiveActivitySessionPolicy = LiveActivitySessionPolicy()
    ) {
        self.playback = playback
        self.store = store
        self.policy = policy
        darwinObserver = DarwinPlaybackObserver { [weak self] in
            Task { @MainActor in
                await self?.tick()
            }
        }
        adoptExistingActivity()
        start()
    }

    deinit {
        loop?.cancel()
    }

    private func start() {
        loop = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func tick() async {
        handleRemoteCommand()
        publishSnapshot()
        PhoneWatchSession.shared?.publishIfNeeded()
        await applyLiveActivityPolicy()
    }

    private func handleRemoteCommand() {
        switch store.dequeue() {
        case .toggle:
            playback.toggle()
        case .next:
            playback.next()
        case .previous:
            playback.previous()
        case .none:
            break
        }
    }

    private func publishSnapshot() {
        let state = playback.state
        let previous = store.load()
        let snapshot: NowPlayingSnapshot
        if let track = state.track {
            snapshot = NowPlayingSnapshot.currentOrRecent(
                trackId: track.id.uuidString,
                title: track.title,
                artist: track.artist,
                isPlaying: state.isPlaying,
                previous: previous
            )
            if track.artworkUrl != lastArtworkURL {
                lastArtworkURL = track.artworkUrl
                Task { await self.refreshArtwork(urlString: track.artworkUrl) }
            }
        } else {
            snapshot = NowPlayingSnapshot.currentOrRecent(
                trackId: nil,
                title: "",
                artist: "",
                isPlaying: false,
                previous: previous
            )
            lastArtworkURL = nil
        }
        store.save(snapshot)
        let signature = "\(snapshot.trackId ?? "")|\(snapshot.isPlaying)|\(snapshot.artworkFileName ?? "")"
        if signature != lastWidgetSignature {
            lastWidgetSignature = signature
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func refreshArtwork(urlString: String?) async {
        guard let urlString, let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let fileName = store.writeArtwork(data), var snapshot = store.load() {
                snapshot.artworkFileName = fileName
                store.save(snapshot)
                lastWidgetSignature = nil
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            return
        }
    }

    private func applyLiveActivityPolicy() async {
        let enabled = UserDefaults.standard.object(forKey: PrefKey.liveActivitiesEnabled) as? Bool ?? true
        let state = playback.state
        if state.isPlaying {
            lastPausedAt = nil
        } else if lastPausedAt == nil, state.track != nil {
            lastPausedAt = Date()
        }
        let decision = policy.decide(
            enabled: enabled && ActivityAuthorizationInfo().areActivitiesEnabled,
            hasTrack: state.track != nil,
            isPlaying: state.isPlaying,
            hasActivity: activity != nil,
            startedAt: startedAt,
            lastPausedAt: lastPausedAt,
            now: Date()
        )
        switch decision {
        case .none:
            break
        case .start:
            startActivity()
        case .update:
            await updateActivity()
        case .end:
            await endActivity()
        case .restart:
            await endActivity()
            startActivity()
        }
    }

    private func contentState() -> ListeningActivityAttributes.ContentState? {
        guard let track = playback.state.track else { return nil }
        return ListeningActivityAttributes.ContentState(
            title: track.title,
            artist: track.artist,
            isPlaying: playback.state.isPlaying,
            trackId: track.id.uuidString,
            artworkFileName: store.load()?.artworkFileName
        )
    }

    private func adoptExistingActivity() {
        let existing = Activity<ListeningActivityAttributes>.activities
        activity = existing.first
        startedAt = existing.first?.attributes.startedAt
        for extra in existing.dropFirst() {
            let handle = ActivityBridge.Handle(activity: extra)
            Task {
                await ActivityBridge.end(handle)
            }
        }
    }

    private func startActivity() {
        guard let state = contentState() else { return }
        let now = Date()
        startedAt = now
        let attributes = ListeningActivityAttributes(startedAt: now)
        let content = ActivityContent(state: state, staleDate: now.addingTimeInterval(policy.maxDuration))
        do {
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            activity = nil
            startedAt = nil
        }
    }

    private func updateActivity() async {
        guard let activity, let state = contentState() else { return }
        await ActivityBridge.update(
            ActivityBridge.Handle(activity: activity),
            content: ActivityContent(state: state, staleDate: nil)
        )
    }

    private func endActivity() async {
        guard let activity else { return }
        let handle = ActivityBridge.Handle(activity: activity)
        self.activity = nil
        startedAt = nil
        lastPausedAt = nil
        await ActivityBridge.end(handle)
    }
}

/// ActivityKit's `Activity` is not Sendable; box the reference for Swift 6 hops into `update`/`end`.
private enum ActivityBridge {
    struct Handle: @unchecked Sendable {
        let activity: Activity<ListeningActivityAttributes>
    }

    nonisolated static func update(
        _ handle: Handle,
        content: ActivityContent<ListeningActivityAttributes.ContentState>
    ) async {
        await handle.activity.update(content)
    }

    nonisolated static func end(_ handle: Handle) async {
        await handle.activity.end(nil, dismissalPolicy: .immediate)
    }
}

/// Darwin notify bridge so Control Center / Live Activity intents reach the audio session.
final class DarwinPlaybackObserver: @unchecked Sendable {
    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            pointer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                Unmanaged<DarwinPlaybackObserver>.fromOpaque(observer).takeUnretainedValue().handler()
            },
            MusesAppGroup.darwinName as CFString,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            CFNotificationName(MusesAppGroup.darwinName as CFString),
            nil
        )
    }
}
