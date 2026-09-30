import XCTest
@testable import MusesNetworking

private actor SequenceTransport: HTTPTransport {
    private var responses: [HTTPResponse]
    var count = 0
    init(_ responses: [HTTPResponse]) { self.responses = responses }
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        count += 1
        return responses[min(count - 1, responses.count - 1)]
    }
}
private actor DelayRecorder {
    var values: [TimeInterval] = []
    func record(_ value: TimeInterval) { values.append(value) }
}
private actor CancellationSleeper {
    var started = false
    var cancelled = false
    func sleep(_ delay: TimeInterval) async throws {
        started = true
        do { try await Task.sleep(for: .seconds(30)) }
        catch { cancelled = true; throw error }
    }
}

final class RecoveryTests: XCTestCase {
    private let request = URLRequest(url: URL(string: "https://example.invalid/recovery")!)
    private let now = Date(timeIntervalSince1970: 784111777) // Sun, 06 Nov 1994 08:49:37 GMT

    func testRetryAfterDateFormatsCaseAndValidation() {
        for value in ["Sun, 06 Nov 1994 08:49:57 GMT", "Sunday, 06-Nov-94 08:49:57 GMT", "Sun Nov  6 08:49:57 1994", " 20 "] {
            let response = HTTPResponse(status: 429, headers: ["Retry-After": value], body: Data())
            XCTAssertEqual(APIError.classify(response, at: now), .rateLimited(retryAfter: 20), value)
        }
        XCTAssertEqual(RetryAfter.delay(in: HTTPResponse(status: 429, headers: ["retry-after": "Sun, 06 Nov 1994 08:49:00 GMT"], body: Data()), at: now), 0)
        for invalid in ["-1", "1.5", "NaN", "infinity", "tomorrow", ""] {
            XCTAssertNil(RetryAfter.delay(in: HTTPResponse(status: 429, headers: ["retry-after": invalid], body: Data()), at: now))
        }
    }

    func testLongServerDelayReturnsWithoutSleepOrEarlyRequest() async throws {
        for status in [429, 503] {
            for value in ["120", "Sun, 06 Nov 1994 08:51:37 GMT"] {
                let delays = DelayRecorder()
                let transport = SequenceTransport([HTTPResponse(status: status, headers: ["Retry-After": value], body: Data()), HTTPResponse(status: 200, body: Data())])
                let policy = HTTPRetryPolicy(now: { [now] in now }, random: { 1 }, sleep: { await delays.record($0) })
                let response = try await GETCoalescer(transport: transport, retryPolicy: policy).get(request, identity: "long", endpoint: "videos")
                XCTAssertEqual(response.status, status)
                let count = await transport.count, recorded = await delays.values
                XCTAssertEqual(count, 1)
                XCTAssertTrue(recorded.isEmpty)
            }
        }
    }

    func testShortServerDelayIsHonoredAndFallbackUsesJitter() async throws {
        for header in ["1", "Sun, 06 Nov 1994 08:49:38 GMT"] {
            let delays = DelayRecorder()
            let transport = SequenceTransport([HTTPResponse(status: 429, headers: ["retry-after": header], body: Data()), HTTPResponse(status: 200, body: Data())])
            let policy = HTTPRetryPolicy(now: { [now] in now }, random: { 0 }, sleep: { await delays.record($0) })
            _ = try await GETCoalescer(transport: transport, retryPolicy: policy).get(request, identity: "short", endpoint: "videos")
            let recorded = await delays.values
            XCTAssertEqual(recorded, [1])
        }
        let delays = DelayRecorder()
        let transport = SequenceTransport([HTTPResponse(status: 503, body: Data())])
        let policy = HTTPRetryPolicy(now: { [now] in now }, random: { 0.5 }, sleep: { await delays.record($0) })
        _ = try await GETCoalescer(transport: transport, retryPolicy: policy).get(request, identity: "jitter", endpoint: "videos")
        let recorded = await delays.values, count = await transport.count
        XCTAssertEqual(recorded, [0.1875, 0.375])
        XCTAssertEqual(count, 3)
    }

    func testCancelLastWaiterCancelsBackoffWithoutAnotherRequest() async throws {
        let sleeper = CancellationSleeper()
        let transport = SequenceTransport([HTTPResponse(status: 503, body: Data())])
        let policy = HTTPRetryPolicy(now: { [now] in now }, random: { 1 }, sleep: { try await sleeper.sleep($0) })
        let coalescer = GETCoalescer(transport: transport, retryPolicy: policy)
        let task = Task { [request] in try await coalescer.get(request, identity: "cancel", endpoint: "videos") }
        while !(await sleeper.started) { await Task.yield() }
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        let count = await transport.count, cancelled = await sleeper.cancelled
        XCTAssertEqual(count, 1)
        XCTAssertTrue(cancelled)
    }

    func testPersistentBudgetReconstructionAndLocalMidnight() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("budget.json")
        let zone = TimeZone(identifier: "America/Los_Angeles")!
        // DST transition day ends at 07:00 UTC, rather than 24 hours from its start.
        let before = ISO8601DateFormatter().date(from: "2026-03-09T06:59:59Z")!
        let after = before.addingTimeInterval(1)
        let first = try RequestBudget(searchCallsPerDay: 1, otherUnitsPerDay: 1, storageURL: url, timeZone: zone)
        try await first.reserve(endpoint: "search", at: before)
        try await first.reserve(endpoint: "videos", at: before)
        let restored = try RequestBudget(searchCallsPerDay: 1, otherUnitsPerDay: 1, storageURL: url, timeZone: zone)
        let snapshot = await restored.snapshot(at: before)
        XCTAssertEqual(snapshot.searchUsed, 1)
        XCTAssertEqual(snapshot.otherUsed, 1)
        XCTAssertEqual(snapshot.resetsAt, after)
        XCTAssertEqual(snapshot.timeZoneIdentifier, zone.identifier)
        do { try await restored.reserve(endpoint: "search", at: before); XCTFail("Expected persisted cap") }
        catch { XCTAssertEqual(error as? APIError, .quotaExceeded(reason: "localSearchBudget")) }
        try await restored.reserve(endpoint: "search", at: after)
        let next = await restored.snapshot(at: after)
        XCTAssertEqual(next.searchUsed, 1)
        XCTAssertEqual(next.otherUsed, 0)
        let utc = RequestBudget(searchCallsPerDay: 1, otherUnitsPerDay: 1, timeZone: TimeZone(secondsFromGMT: 0)!)
        let utcSnapshot = await utc.snapshot(at: before)
        XCTAssertNotEqual(utcSnapshot.resetsAt, snapshot.resetsAt)
        let isolated = try RequestBudget(searchCallsPerDay: 1, otherUnitsPerDay: 1, storageURL: directory.appendingPathComponent("isolated.json"))
        try await isolated.reserve(endpoint: "search", at: before)
    }

    func testStorageFailureDoesNotPublishSuccessfulReservation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data().write(to: directory) // Parent is a file, so writing its child must fail.
        let budget = try RequestBudget(searchCallsPerDay: 1, otherUnitsPerDay: 1, storageURL: directory.appendingPathComponent("budget.json"))
        do { try await budget.reserve(endpoint: "search", at: now); XCTFail("Expected write failure") } catch { }
        let snapshot = await budget.snapshot(at: now)
        XCTAssertEqual(snapshot.searchUsed, 0)
        XCTAssertFalse(APIError.quotaExceeded(reason: "localSearchBudget").localizedDescription == APIError.quotaExceeded(reason: "quotaExceeded").localizedDescription)
    }

    func testCorruptStorageIsNotSilentlyReset() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("invalid JSON".utf8).write(to: url)
        XCTAssertThrowsError(try RequestBudget(searchCallsPerDay: 1, otherUnitsPerDay: 1, storageURL: url))
    }

    func testEveryPhysicalRetryConsumesLocalBudget() async throws {
        let budget = RequestBudget(searchCallsPerDay: 0, otherUnitsPerDay: 1)
        let transport = SequenceTransport([HTTPResponse(status: 503, body: Data())])
        let policy = HTTPRetryPolicy(now: { Date() }, random: { 1 }, sleep: { _ in })
        let coalescer = GETCoalescer(transport: transport, retryPolicy: policy)
        do {
            _ = try await coalescer.get(request, identity: "budgeted", endpoint: "videos", budget: budget)
            XCTFail("Expected retry to hit local budget")
        } catch { XCTAssertEqual(error as? APIError, .quotaExceeded(reason: "localReadBudget")) }
        let count = await transport.count
        XCTAssertEqual(count, 1)
    }
}
