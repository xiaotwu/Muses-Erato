import XCTest
@testable import MusesNetworking

final class HTTPTests: XCTestCase {
    func testErrorClassification() {
        let quota = HTTPResponse(status: 403, body: Data(#"{"error":{"errors":[{"reason":"quotaExceeded"}]}}"#.utf8))
        XCTAssertEqual(APIError.classify(quota), .quotaExceeded(reason: "quotaExceeded"))
        XCTAssertEqual(APIError.classify(HTTPResponse(status: 429, headers: ["retry-after":"12"], body: Data())), .rateLimited(retryAfter: 12))
        XCTAssertEqual(APIError.classify(HTTPResponse(status: 503, body: Data())), .server(status: 503))
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
