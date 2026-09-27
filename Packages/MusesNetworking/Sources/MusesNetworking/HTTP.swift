import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct HTTPResponse: Sendable {
    public let status: Int
    public let headers: [String: String]
    public let body: Data
    public init(status: Int, headers: [String: String] = [:], body: Data) {
        self.status = status; self.headers = headers; self.body = body
    }
}

public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse
}

public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession
    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }
    public func send(_ request: URLRequest) async throws -> HTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return HTTPResponse(status: http.statusCode, headers: http.allHeaderFields.reduce(into: [:]) { result, pair in
            result[String(describing: pair.key).lowercased()] = String(describing: pair.value)
        }, body: data)
    }
}

public enum APIError: Error, Sendable, Equatable {
    case quotaExceeded(reason: String?)
    case rateLimited(retryAfter: TimeInterval?)
    case forbidden(reason: String?)
    case unavailable
    case unauthorized
    case server(status: Int)
    case invalidResponse
    case network

    public static func classify(_ response: HTTPResponse) -> APIError? {
        guard !(200..<300).contains(response.status) else { return nil }
        let reason = (try? JSONDecoder().decode(GoogleErrorEnvelope.self, from: response.body))?.error.errors?.first?.reason
        switch response.status {
        case 404: return .unavailable
        case 401: return .unauthorized
        case 403 where reason?.lowercased().contains("quota") == true || reason?.lowercased().contains("dailylimit") == true || reason?.lowercased().contains("ratelimit") == true: return .quotaExceeded(reason: reason)
        case 403: return .forbidden(reason: reason)
        case 429: return .rateLimited(retryAfter: response.headers["retry-after"].flatMap(TimeInterval.init))
        case 500...599: return .server(status: response.status)
        default: return .invalidResponse
        }
    }
}

private struct GoogleErrorEnvelope: Decodable {
    struct Detail: Decodable { let reason: String? }
    struct Body: Decodable { let errors: [Detail]? }
    let error: Body
}

public actor RequestLedger {
    public struct Snapshot: Sendable, Equatable {
        public let calls: [String: Int]
        public let estimatedUnits: [String: Int]
    }
    private var calls: [String: Int] = [:]
    private var units: [String: Int] = [:]
    public init() {}
    public func record(endpoint: String, cost: Int = 1) {
        calls[endpoint, default: 0] += 1
        units[endpoint, default: 0] += cost
    }
    public func snapshot() -> Snapshot { Snapshot(calls: calls, estimatedUnits: units) }
}

/// Device-side guardrail only. The Google Cloud project's shared quota remains authoritative.
public actor RequestBudget {
    private let searchLimit: Int
    private let otherLimit: Int
    private var day: DateComponents?
    private var searchUsed = 0
    private var otherUsed = 0
    private var calendar: Calendar
    public init(searchCallsPerDay: Int, otherUnitsPerDay: Int) {
        self.searchLimit = max(searchCallsPerDay, 0)
        self.otherLimit = max(otherUnitsPerDay, 0)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        self.calendar = calendar
    }
    public func reserve(endpoint: String, at now: Date = Date()) throws {
        let currentDay = calendar.dateComponents([.year, .month, .day], from: now)
        if day != currentDay { day = currentDay; searchUsed = 0; otherUsed = 0 }
        if endpoint == "search" {
            guard searchUsed < searchLimit else { throw APIError.quotaExceeded(reason: "localSearchBudget") }
            searchUsed += 1
        } else {
            guard otherUsed < otherLimit else { throw APIError.quotaExceeded(reason: "localReadBudget") }
            otherUsed += 1
        }
    }
}

/// Coalesces only active identical GETs. Cancelling one waiter does not cancel other waiters.
public actor GETCoalescer {
    private struct Entry { let task: Task<HTTPResponse, Error>; var waiters: Set<UUID> }
    private var active: [String: Entry] = [:]
    private let transport: any HTTPTransport
    public init(transport: any HTTPTransport) { self.transport = transport }

    public func get(_ request: URLRequest, identity: String, ledger: RequestLedger? = nil, endpoint: String? = nil, budget: RequestBudget? = nil) async throws -> HTTPResponse {
        let waiter = UUID()
        if var entry = active[identity] {
            entry.waiters.insert(waiter); active[identity] = entry
        } else {
            let transport = self.transport
            active[identity] = Entry(task: Task {
                for attempt in 0...2 {
                    try Task.checkCancellation()
                    if let budget, let endpoint { try await budget.reserve(endpoint: endpoint) }
                    if let ledger, let endpoint { await ledger.record(endpoint: endpoint) }
                    let response = try await transport.send(request)
                    guard attempt < 2, endpoint != "search" else { return response }
                    switch APIError.classify(response) {
                    case .rateLimited(let retryAfter):
                        let seconds = min(max(retryAfter ?? 0.25 * Double(1 << attempt), 0), 2)
                        try await Task.sleep(for: .seconds(seconds))
                    case .server:
                        try await Task.sleep(for: .seconds(0.25 * Double(1 << attempt)))
                    default: return response
                    }
                }
                throw APIError.invalidResponse
            }, waiters: [waiter])
        }
        guard let task = active[identity]?.task else { throw CancellationError() }
        defer { release(identity, waiter: waiter) }
        return try await withTaskCancellationHandler {
            let result = try await task.value
            try Task.checkCancellation()
            return result
        } onCancel: {
            Task { await self.release(identity, waiter: waiter) }
        }
    }
    var waiterCount: Int { active.values.reduce(0) { $0 + $1.waiters.count } }

    private func release(_ identity: String, waiter: UUID) {
        guard var entry = active[identity] else { return }
        guard entry.waiters.remove(waiter) != nil else { return }
        if entry.waiters.isEmpty { entry.task.cancel(); active[identity] = nil }
        else { active[identity] = entry }
    }
}


extension APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .quotaExceeded: "YouTube request quota reached. Try again after the quota resets."
        case .rateLimited(let delay): "YouTube is limiting requests. Try again later" + (delay.map { " (after \(Int($0)) seconds)." } ?? ".")
        case .forbidden: "You do not have permission to read this YouTube content."
        case .unauthorized: "Sign in to Google to read this content, or reconnect your account."
        case .unavailable: "This YouTube content is private, deleted or unavailable."
        case .server: "YouTube is temporarily unavailable. Try again."
        case .invalidResponse: "YouTube returned an unsupported response. Try again."
        case .network: "Could not connect to YouTube. Check your connection and retry."
        }
    }
}
