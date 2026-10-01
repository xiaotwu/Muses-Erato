import Foundation

/// Retry-After is either nonnegative integer seconds or an HTTP date (RFC 9110).
public enum RetryAfter {
    public static func delay(in response: HTTPResponse, at now: Date = Date()) -> TimeInterval? {
        guard let raw = response.headers.first(where: { $0.key.lowercased() == "retry-after" })?.value else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty, value.utf8.allSatisfy({ (48...57).contains($0) }),
           let seconds = TimeInterval(value), seconds.isFinite { return seconds }
        // Also accept the two obsolete HTTP date formats required of HTTP recipients.
        for format in ["EEE, dd MMM yyyy HH:mm:ss 'GMT'", "EEEE, dd-MMM-yy HH:mm:ss 'GMT'", "EEE MMM d HH:mm:ss yyyy"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            formatter.isLenient = false
            if let date = formatter.date(from: value) { return max(0, date.timeIntervalSince(now)) }
        }
        return nil
    }
}

public struct HTTPRetryPolicy: Sendable {
    public let maximumAutomaticDelay: TimeInterval
    let now: @Sendable () -> Date
    let sleep: @Sendable (TimeInterval) async throws -> Void
    private let random: @Sendable () -> Double

    public init(maximumAutomaticDelay: TimeInterval = 2) {
        self.init(maximumAutomaticDelay: maximumAutomaticDelay, now: { Date() },
                  random: { Double.random(in: 0...1) }, sleep: { try await Task.sleep(for: .seconds($0)) })
    }

    // Injectable time and sleeper keep retry/cancellation tests deterministic without real waits.
    init(maximumAutomaticDelay: TimeInterval = 2, now: @escaping @Sendable () -> Date,
         random: @escaping @Sendable () -> Double,
         sleep: @escaping @Sendable (TimeInterval) async throws -> Void) {
        self.maximumAutomaticDelay = maximumAutomaticDelay.isFinite ? max(0, maximumAutomaticDelay) : 2
        self.now = now; self.random = random; self.sleep = sleep
    }

    func backoff(attempt: Int) -> TimeInterval {
        // Equal jitter: exponential base with a random delay between half and all of the base.
        let base = min(maximumAutomaticDelay, 0.25 * pow(2, Double(attempt)))
        return base * (0.5 + 0.5 * min(max(random(), 0), 1))
    }
}
