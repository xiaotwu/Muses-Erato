import Foundation

/// Device-side guardrail only; it does not measure or reset the shared Google project quota.
/// Share one actor per storage URL within an app process. Separate URLs isolate tests/profiles.
public actor RequestBudget {
    private struct State: Codable {
        var day: String
        var searchUsed: Int
        var otherUsed: Int
    }
    public struct Snapshot: Sendable, Equatable {
        public let searchUsed: Int
        public let otherUsed: Int
        public let resetsAt: Date
        public let timeZoneIdentifier: String
    }
    private let searchLimit: Int
    private let otherLimit: Int
    private let storageURL: URL?
    private var state: State?
    private let calendar: Calendar

    /// Existing calls retain an isolated in-memory budget. The default day boundary is Los Angeles.
    public init(searchCallsPerDay: Int, otherUnitsPerDay: Int,
                timeZone: TimeZone = TimeZone(identifier: "America/Los_Angeles")!) {
        searchLimit = max(searchCallsPerDay, 0); otherLimit = max(otherUnitsPerDay, 0)
        storageURL = nil
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        self.calendar = calendar
    }

    /// Opt-in persistence. Corrupt/unreadable storage throws instead of silently resetting usage.
    /// Reservations are written atomically before success; storage failures propagate to the caller.
    public init(searchCallsPerDay: Int, otherUnitsPerDay: Int, storageURL: URL,
                timeZone: TimeZone = TimeZone(identifier: "America/Los_Angeles")!) throws {
        searchLimit = max(searchCallsPerDay, 0); otherLimit = max(otherUnitsPerDay, 0)
        self.storageURL = storageURL
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        self.calendar = calendar
        if FileManager.default.fileExists(atPath: storageURL.path) {
            let loaded = try JSONDecoder().decode(State.self, from: Data(contentsOf: storageURL))
            guard loaded.searchUsed >= 0, loaded.otherUsed >= 0 else { throw CocoaError(.fileReadCorruptFile) }
            state = loaded
        }
    }

    public func reserve(endpoint: String, at now: Date = Date()) throws {
        var next = currentState(at: now)
        if endpoint == "search" {
            guard next.searchUsed < searchLimit else { throw APIError.quotaExceeded(reason: "localSearchBudget") }
            next.searchUsed += 1
        } else {
            guard next.otherUsed < otherLimit else { throw APIError.quotaExceeded(reason: "localReadBudget") }
            next.otherUsed += 1
        }
        if let storageURL {
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(next).write(to: storageURL, options: .atomic)
        }
        state = next
    }

    public func snapshot(at now: Date = Date()) -> Snapshot {
        let current = currentState(at: now)
        return Snapshot(searchUsed: current.searchUsed, otherUsed: current.otherUsed,
                        resetsAt: calendar.dateInterval(of: .day, for: now)!.end,
                        timeZoneIdentifier: calendar.timeZone.identifier)
    }

    private func currentState(at now: Date) -> State {
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        let key = "\(calendar.timeZone.identifier):\(components.year!)-\(components.month!)-\(components.day!)"
        return state?.day == key ? state! : State(day: key, searchUsed: 0, otherUsed: 0)
    }
}
