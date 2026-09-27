import Foundation
import SQLite3

public enum LegacySnapshotError: Error, Equatable, Sendable {
    case sourceMissing
    case destinationExists
    case database(String)
    case integrity(String)
}

/// Produces a consistent, independent SQLite snapshot from the inherited SwiftData store.
/// SQLite's backup API includes committed WAL pages without writing to the source database.
/// The app's old-model reader opens only the returned URL. Keep the original store and its
/// WAL/SHM files together until the user has verified the migrated library.
public enum LegacyStoreSnapshotter {
    public static func snapshot(sourceURL: URL, destinationURL: URL) throws -> URL {
        let manager = FileManager.default
        guard manager.fileExists(atPath: sourceURL.path) else { throw LegacySnapshotError.sourceMissing }
        guard !manager.fileExists(atPath: destinationURL.path) else { throw LegacySnapshotError.destinationExists }
        try manager.createDirectory(at: destinationURL.deletingLastPathComponent(),
                                    withIntermediateDirectories: true)
        var source: OpaquePointer?
        var destination: OpaquePointer?
        defer {
            if let destination { sqlite3_close(destination) }
            if let source { sqlite3_close(source) }
        }
        guard sqlite3_open_v2(sourceURL.path, &source, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            throw LegacySnapshotError.database(source.map { String(cString: sqlite3_errmsg($0)) } ?? "open source")
        }
        do {
            guard sqlite3_open_v2(destinationURL.path, &destination,
                                  SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_EXCLUSIVE,
                                  nil) == SQLITE_OK else {
                throw LegacySnapshotError.database(destination.map { String(cString: sqlite3_errmsg($0)) } ?? "open destination")
            }
            guard let backup = sqlite3_backup_init(destination, "main", source, "main") else {
                throw LegacySnapshotError.database(String(cString: sqlite3_errmsg(destination)))
            }
            var step = SQLITE_BUSY
            for _ in 0..<5 {
                step = sqlite3_backup_step(backup, -1)
                if step != SQLITE_BUSY && step != SQLITE_LOCKED { break }
                sqlite3_sleep(100)
            }
            let finish = sqlite3_backup_finish(backup)
            guard step == SQLITE_DONE && finish == SQLITE_OK else {
                throw LegacySnapshotError.database(String(cString: sqlite3_errmsg(destination)))
            }
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(destination, "PRAGMA quick_check", -1, &statement, nil) == SQLITE_OK else {
                throw LegacySnapshotError.database(String(cString: sqlite3_errmsg(destination)))
            }
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW,
                  let result = sqlite3_column_text(statement, 0),
                  String(cString: result) == "ok" else {
                let reason = statement.flatMap { sqlite3_column_text($0, 0) }.map { String(cString: $0) } ?? "quick_check failed"
                throw LegacySnapshotError.integrity(reason)
            }
            return destinationURL
        } catch {
            if let handle = destination {
                sqlite3_close(handle)
                destination = nil
            }
            try? manager.removeItem(at: destinationURL)
            throw error
        }
    }
}
