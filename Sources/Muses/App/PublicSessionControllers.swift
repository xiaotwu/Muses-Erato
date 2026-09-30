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
