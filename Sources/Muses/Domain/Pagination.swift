import Foundation

enum PaginationIncompleteKind: String, Codable, Sendable, Equatable {
    case continuation
    case safetyLimit
    case cancelled
    case timedOut
    case quotaExceeded
    case rateLimited
    case parseFailure
    case requestFailure
}

struct PaginationIncompleteReason: Codable, Sendable, Equatable {
    let kind: PaginationIncompleteKind
    let detail: String?

    init(_ kind: PaginationIncompleteKind, detail: String? = nil) {
        self.kind = kind
        self.detail = detail
    }
}

enum PaginationCompleteness: Codable, Sendable, Equatable {
    case complete
    case incomplete(PaginationIncompleteReason)

    var isComplete: Bool {
        if case .complete = self { return true }
        return false
    }
}

struct PaginatedResult<Item: Sendable>: Sendable {
    let items: [Item]
    let completeness: PaginationCompleteness
    let pageCount: Int
    let nextPageToken: String?

    var isComplete: Bool { completeness.isComplete }
}

extension PaginatedResult: Equatable where Item: Equatable {}

struct PaginationPage<Item: Sendable>: Sendable {
    let items: [Item]
    let nextPageToken: String?
}

