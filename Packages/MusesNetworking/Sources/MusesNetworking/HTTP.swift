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

public enum APIConfigurationIssue: Sendable, Equatable {
    case appNotAuthorized
    case serviceDisabled
    case invalidKey
}

public enum APIError: Error, Sendable, Equatable {
    case configuration(APIConfigurationIssue)
    case quotaExceeded(reason: String?)
    case rateLimited(retryAfter: TimeInterval?)
    case forbidden(reason: String?)
    case unavailable
    case unauthorized
    case server(status: Int)
    case invalidResponse
    case network

    public static func classify(_ response: HTTPResponse, at now: Date = Date()) -> APIError? {
        guard !(200..<300).contains(response.status) else { return nil }
        let envelope = try? JSONDecoder().decode(GoogleErrorEnvelope.self, from: response.body)
        let reason = envelope?.error.errors?.first?.reason
        // Only expose known categories. Google messages/metadata can contain credentials,
        // project identifiers or request details, and must never become user-facing text.
        if (400...403).contains(response.status), let issue = envelope?.configurationIssue {
            return .configuration(issue)
        }
        switch response.status {
        case 404: return .unavailable
        case 401: return .unauthorized
        case 403 where reason?.lowercased().contains("quota") == true || reason?.lowercased().contains("dailylimit") == true || reason?.lowercased().contains("ratelimit") == true: return .quotaExceeded(reason: reason)
        case 403: return .forbidden(reason: reason)
        case 429: return .rateLimited(retryAfter: RetryAfter.delay(in: response, at: now))
        case 500...599: return .server(status: response.status)
        default: return .invalidResponse
        }
    }
}

private struct GoogleErrorEnvelope: Decodable {
    struct Detail: Decodable { let reason: String? }
    struct ErrorInfo: Decodable {
        let type: String?
        let reason: String?
        enum CodingKeys: String, CodingKey { case type = "@type", reason }
    }
    struct Body: Decodable {
        let errors: [Detail]?
        let details: [ErrorInfo]?
    }
    let error: Body

    var configurationIssue: APIConfigurationIssue? {
        let structuredReasons = (error.details ?? []).filter {
            $0.type == "type.googleapis.com/google.rpc.ErrorInfo"
        }.compactMap(\.reason)
        for reason in structuredReasons + (error.errors ?? []).compactMap(\.reason) {
            switch reason.uppercased() {
            case "API_KEY_IOS_APP_BLOCKED", "API_KEY_ANDROID_APP_BLOCKED", "API_KEY_HTTP_REFERRER_BLOCKED",
                 "API_KEY_IP_ADDRESS_BLOCKED", "API_KEY_SERVICE_BLOCKED", "IPREFERERBLOCKED":
                return .appNotAuthorized
            case "SERVICE_DISABLED", "ACCESSNOTCONFIGURED": return .serviceDisabled
            case "API_KEY_INVALID", "API_KEY_EXPIRED", "API_KEY_NOT_FOUND", "KEYINVALID": return .invalidKey
            default: continue
            }
        }
        return nil
    }
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

/// Coalesces only active identical GETs. Cancelling one waiter does not cancel other waiters.
public actor GETCoalescer {
    private struct Entry { let task: Task<HTTPResponse, Error>; var waiters: Set<UUID> }
    private var active: [String: Entry] = [:]
    private let transport: any HTTPTransport
    private let retryPolicy: HTTPRetryPolicy
    public init(transport: any HTTPTransport, retryPolicy: HTTPRetryPolicy = HTTPRetryPolicy()) {
        self.transport = transport
        self.retryPolicy = retryPolicy
    }

    public func get(_ request: URLRequest, identity: String, ledger: RequestLedger? = nil, endpoint: String? = nil, budget: RequestBudget? = nil) async throws -> HTTPResponse {
        let waiter = UUID()
        if var entry = active[identity] {
            entry.waiters.insert(waiter); active[identity] = entry
        } else {
            let transport = self.transport
            let retryPolicy = self.retryPolicy
            active[identity] = Entry(task: Task {
                for attempt in 0...2 {
                    try Task.checkCancellation()
                    if let budget, let endpoint { try await budget.reserve(endpoint: endpoint) }
                    if let ledger, let endpoint { await ledger.record(endpoint: endpoint) }
                    let response = try await transport.send(request)
                    guard attempt < 2, endpoint != "search" else { return response }
                    let now = retryPolicy.now()
                    let serverDelay = RetryAfter.delay(in: response, at: now)
                    switch APIError.classify(response, at: now) {
                    case .rateLimited, .server:
                        // Return the original response so callers retain its status, body and recovery metadata.
                        if let serverDelay, serverDelay > retryPolicy.maximumAutomaticDelay { return response }
                        let seconds = serverDelay ?? retryPolicy.backoff(attempt: attempt)
                        try Task.checkCancellation()
                        try await retryPolicy.sleep(seconds)
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
        case .configuration(.appNotAuthorized): "This app is not authorized to use the YouTube API. Check the app restrictions in the Google API configuration, then retry. You can also open this content in YouTube."
        case .configuration(.serviceDisabled): "The YouTube API is not enabled for this app's Google project. Check the Google API configuration, then retry. You can also open this content in YouTube."
        case .configuration(.invalidKey): "This app's YouTube API key is invalid or expired. Check the Google API configuration, then retry. You can also open this content in YouTube."
        case .quotaExceeded(let reason) where reason == "localSearchBudget": "This device's daily search budget is used. Try again after the local daily budget resets."
        case .quotaExceeded(let reason) where reason == "localReadBudget": "This device's daily read budget is used. Try again after the local daily budget resets."
        case .quotaExceeded: "YouTube's shared project quota is reached. Try again after the server quota resets."
        case .rateLimited(let delay): "YouTube is limiting requests. Try again later" + (delay.flatMap { seconds in
            seconds.isFinite ? " (after \(Int(min(max(seconds.rounded(.up), 0), Double(Int.max / 2)))) seconds)." : nil
        } ?? ".")
        case .forbidden: "You do not have permission to read this YouTube content."
        case .unauthorized: "Sign in to Google to read this content, or reconnect your account."
        case .unavailable: "This YouTube content is private, deleted or unavailable."
        case .server: "YouTube is temporarily unavailable. Try again."
        case .invalidResponse: "YouTube returned an unsupported response. Try again."
        case .network: "Could not connect to YouTube. Check your connection and retry."
        }
    }
}
