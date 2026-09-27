import XCTest
@testable import MusesNetworking

final class HTTPTests: XCTestCase {
    func testErrorClassification() {
        let quota = HTTPResponse(status: 403, body: Data(#"{"error":{"errors":[{"reason":"quotaExceeded"}]}}"#.utf8))
        XCTAssertEqual(APIError.classify(quota), .quotaExceeded(reason: "quotaExceeded"))
        XCTAssertEqual(APIError.classify(HTTPResponse(status: 429, headers: ["retry-after":"12"], body: Data())), .rateLimited(retryAfter: 12))
        XCTAssertEqual(APIError.classify(HTTPResponse(status: 503, body: Data())), .server(status: 503))
        XCTAssertEqual(APIError.classify(HTTPResponse(status: 403, body: Data())), .forbidden(reason: nil))
        XCTAssertEqual(APIError.classify(HTTPResponse(status: 404, body: Data())), .unavailable)
        XCTAssertEqual(APIError.classify(HTTPResponse(status: 401, body: Data())), .unauthorized)
        XCTAssertTrue(APIError.unavailable.localizedDescription.contains("unavailable"))
    }
    func testSeparateDeviceBudgets() async throws {
        let budget = RequestBudget(searchCallsPerDay: 1, otherUnitsPerDay: 2)
        try await budget.reserve(endpoint: "search")
        do { try await budget.reserve(endpoint: "search"); XCTFail("expected search cap") }
        catch { XCTAssertEqual(error as? APIError, .quotaExceeded(reason: "localSearchBudget")) }
        try await budget.reserve(endpoint: "videos")
        try await budget.reserve(endpoint: "playlists")
        do { try await budget.reserve(endpoint: "channels"); XCTFail("expected read cap") }
        catch { XCTAssertEqual(error as? APIError, .quotaExceeded(reason: "localReadBudget")) }
    }
}

private actor GatedTransport: HTTPTransport {
    var continuation: CheckedContinuation<HTTPResponse, Never>?
    var count = 0
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        count += 1
        return await withCheckedContinuation { continuation = $0 }
    }
    func finish() { continuation?.resume(returning: HTTPResponse(status: 200, body: Data())); continuation = nil }
    var ready: Bool { continuation != nil }
}
private actor SearchFailure: HTTPTransport {
    var count = 0
    func send(_ request: URLRequest) async throws -> HTTPResponse { count += 1; return HTTPResponse(status: 503, body: Data()) }
}
extension HTTPTests {
    func testCoalescingCancellationAndSingleBudgetReservation() async throws {
        let transport = GatedTransport(), ledger = RequestLedger()
        let coalescer = GETCoalescer(transport: transport)
        let budget = RequestBudget(searchCallsPerDay: 1, otherUnitsPerDay: 0)
        let request = URLRequest(url: URL(string: "https://example.invalid")!)
        let first = Task { try await coalescer.get(request, identity: "same", ledger: ledger, endpoint: "search", budget: budget) }
        let second = Task { try await coalescer.get(request, identity: "same", ledger: ledger, endpoint: "search", budget: budget) }
        while await coalescer.waiterCount != 2 { await Task.yield() }
        while !(await transport.ready) { await Task.yield() }
        first.cancel()
        await transport.finish()
        do { _ = try await first.value; XCTFail("Cancelled waiter") } catch { XCTAssertTrue(error is CancellationError) }
        let response = try await second.value
        XCTAssertEqual(response.status, 200)
        let counts = await ledger.snapshot()
        XCTAssertEqual(counts.calls["search"], 1)
    }
    func testSearchDoesNotSpendQuotaOnAutomaticRetry() async throws {
        let transport = SearchFailure()
        let coalescer = GETCoalescer(transport: transport)
        let response = try await coalescer.get(URLRequest(url: URL(string: "https://example.invalid")!), identity: "search", endpoint: "search")
        XCTAssertEqual(response.status, 503)
        let count = await transport.count
        XCTAssertEqual(count, 1)
    }
}
