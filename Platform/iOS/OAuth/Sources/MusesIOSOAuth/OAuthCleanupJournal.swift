import Foundation
import Darwin

/// Contains deletion intent only. No credentials or account identifiers are recorded.
public protocol OAuthCleanupJournal: Sendable {
    func isPending() throws -> Bool
    func begin() throws
    func finish() throws
}

public struct FileOAuthCleanupJournal: OAuthCleanupJournal {
    private struct Marker: Codable { let version: Int; let pending: Bool }
    private let url: URL
    public init(url: URL) { self.url = url }

    public func isPending() throws -> Bool {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return false }
        catch { throw OAuthFailure.storage }
        guard let value = try? JSONDecoder().decode(Marker.self, from: data), value.version == 1 else {
            throw OAuthFailure.storage
        }
        return value.pending
    }
    public func begin() throws { try write(pending: true) }
    public func finish() throws { try write(pending: false) }

    private func write(pending: Bool) throws {
        do {
            let parent = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            try JSONEncoder().encode(Marker(version: 1, pending: pending)).write(to: url, options: .atomic)
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.synchronize()
            let descriptor = open(parent.path, O_RDONLY | O_DIRECTORY)
            guard descriptor >= 0 else { throw OAuthFailure.storage }
            defer { close(descriptor) }
            guard fsync(descriptor) == 0 else { throw OAuthFailure.storage }
        } catch { throw OAuthFailure.storage }
    }
}
