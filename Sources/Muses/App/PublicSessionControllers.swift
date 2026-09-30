import Foundation
import Observation
import MusesDomain
import MusesQueue
import MusesNetworking

/// Saved references are distinct from transient catalog display results. Track records are created
/// only by explicit open/enqueue/import or migration; catalog paging never creates these records.
struct PublicLibraryProjection {
    let tracks: [MusesDomain.Track]
    let history: [MusesDomain.Track]
    let favorites: [MusesDomain.Track]

    init(savedTracks: [MusesDomain.Track], playedIDs: [TrackID]) {
        let byID = Dictionary(savedTracks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<TrackID>()
        tracks = savedTracks.filter { if case .youtubeVideo = $0.source { return true }; return false }
        favorites = tracks.filter(\.liked)
        history = playedIDs.filter { seen.insert($0).inserted }.compactMap { byID[$0] }
    }
}

enum PublicSessionOperation: Hashable {
    case library, playback, queue, account, metadata, deletion
}

struct PublicOperationState {
    var isRunning: Bool = false
    var message: String?
    var error: String?
    var pendingRestart: Bool = false
}

/// Time updates remain in memory. Save at most once per interval, and immediately at lifecycle
/// boundaries. A failed attempt is throttled too, while explicit retry always bypasses the timer.
@MainActor @Observable
final class PublicPlaybackCheckpointController {
    private(set) var failure: String?
    private(set) var pending = false
    private var lastAttempt: Date?
    private let interval: TimeInterval

    init(interval: TimeInterval = 15) { self.interval = interval }

    @discardableResult
    func save(_ snapshot: QueueSnapshot, at now: Date, force: Bool = false,
              write: (QueueSnapshot) throws -> Void) -> Bool {
        pending = true
        guard force || lastAttempt.map({ now.timeIntervalSince($0) >= interval || now < $0 }) ?? true else { return false }
        lastAttempt = now
        do {
            try write(snapshot)
            pending = false
            failure = nil
            return true
        } catch {
            failure = "Playback position could not be saved. Retry saving before closing the app. \(error.localizedDescription)"
            return false
        }
    }

    func reset() { lastAttempt = nil; pending = false; failure = nil }
}

@MainActor enum PublicDeviceRequestBudgets {
    private static var budgets: [URL: RequestBudget] = [:]
    static func budget(at url: URL) throws -> RequestBudget {
        if let budget = budgets[url] { return budget }
        let budget = try RequestBudget(searchCallsPerDay: 10, otherUnitsPerDay: 100, storageURL: url)
        budgets[url] = budget
        return budget
    }
}

/// Dispatch acknowledgement is not playback confirmation. Only a matching real player state
/// settles an action; command identity prevents stale callbacks/timeouts from affecting a retry.
@MainActor @Observable
final class PublicPlaybackCommandController {
    enum Action { case play, pause }
    struct Request: Equatable {
        let id: UUID
        let action: Action
        let generation: UInt64
    }
    private(set) var pending: Request?
    private(set) var failedRequest: Request?
    private(set) var failure: String?
    private(set) var retryAllowed = false
    private let timeout: Duration
    @ObservationIgnored var onFailure: ((Request) -> Void)?
    @ObservationIgnored private var deadline: Task<Void, Never>?

    init(timeout: Duration = .seconds(8)) { self.timeout = timeout }

    func begin(_ action: Action, generation: UInt64) -> Request? {
        guard pending == nil else { return nil }
        let request = Request(id: UUID(), action: action, generation: generation)
        pending = request; failedRequest = nil; failure = nil; retryAllowed = false
        let delay = timeout
        deadline = Task { [weak self] in
            do { try await Task.sleep(for: delay) } catch { return }
            self?.expire(request)
        }
        return request
    }

    func dispatched(_ request: Request, failure message: String?) {
        guard pending == request, let message else { return }
        fail(request, message: message)
    }

    func confirmed(_ action: Action, generation: UInt64) {
        if let pending, pending.action == action, pending.generation == generation {
            deadline?.cancel(); deadline = nil
            self.pending = nil; failedRequest = nil; failure = nil; retryAllowed = false
        } else if let failedRequest, failedRequest.action == action, failedRequest.generation == generation {
            self.failedRequest = nil; failure = nil; retryAllowed = false
        }
    }

    func blocked(generation: UInt64) {
        guard let pending, pending.generation == generation, pending.action == .play else { return }
        fail(pending, message: "YouTube requires a tap on its visible player controls to start this video.")
        retryAllowed = false
    }

    func expire(_ request: Request) {
        guard pending == request else { return }
        fail(request, message: request.action == .play
             ? "YouTube has not confirmed playback. Retry Play or use the visible player controls."
             : "YouTube has not confirmed pause. Retry Pause or use the visible player controls.")
    }

    private func fail(_ request: Request, message: String) {
        deadline?.cancel(); deadline = nil
        pending = nil; failedRequest = request; failure = message; retryAllowed = true
        onFailure?(request)
    }

    func reset() {
        deadline?.cancel(); deadline = nil
        pending = nil; failedRequest = nil; failure = nil; retryAllowed = false
    }
}
