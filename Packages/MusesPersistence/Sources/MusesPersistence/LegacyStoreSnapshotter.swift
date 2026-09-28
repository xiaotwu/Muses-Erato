import Foundation
import SQLite3
import Darwin
import CryptoKit

public enum LegacySnapshotError: Error, Equatable, Sendable {
    case sourceMissing
    case destinationExists
    case sourceChanged
    case database(String)
    case integrity(String)
}

/// Produces a consistent, independent SQLite snapshot from the inherited SwiftData store.
/// A stable byte copy keeps SQLite away from the original WAL/SHM entirely.
/// SQLite's backup API then incorporates committed WAL pages from that disposable copy.
/// The app's old-model reader opens only the returned URL. Keep the original store and its
/// WAL/SHM files together until the user has verified the migrated library.
public enum LegacyStoreSnapshotter {
    public static func snapshot(sourceURL: URL, destinationURL: URL) throws -> URL {
        let manager = FileManager.default
        guard manager.fileExists(atPath: sourceURL.path) else { throw LegacySnapshotError.sourceMissing }
        guard !["", "-wal", "-shm"].contains(where: { manager.fileExists(atPath: destinationURL.path + $0) }) else {
            throw LegacySnapshotError.destinationExists
        }
        try manager.createDirectory(at: destinationURL.deletingLastPathComponent(),
                                    withIntermediateDirectories: true)
        // Startup owns the old app's quiescent store. Do not let SQLite even acquire
        // source SHM locks: copy all physical files using read-only filesystem operations.
        let scratch = destinationURL.deletingLastPathComponent().appendingPathComponent("snapshot-input-" + UUID().uuidString)
        try manager.createDirectory(at: scratch, withIntermediateDirectories: false)
        defer { try? manager.removeItem(at: scratch) }
        let input = scratch.appendingPathComponent("legacy.sqlite")
        let suffixes = ["", "-wal", "-shm"]
        let before = try suffixes.map { try fileDigest(URL(fileURLWithPath: sourceURL.path + $0)) }
        for (index, suffix) in suffixes.enumerated() where before[index] != nil {
            let copied = URL(fileURLWithPath: input.path + suffix)
            try manager.copyItem(at: URL(fileURLWithPath: sourceURL.path + suffix), to: copied)
            try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: copied.path)
        }
        guard before == (try suffixes.map { try fileDigest(URL(fileURLWithPath: sourceURL.path + $0)) }),
              before == (try suffixes.map { try fileDigest(URL(fileURLWithPath: input.path + $0)) }) else {
            throw LegacySnapshotError.sourceChanged
        }
        var source: OpaquePointer?
        var destination: OpaquePointer?
        defer {
            if let destination { sqlite3_close(destination) }
            if let source { sqlite3_close(source) }
        }
        guard sqlite3_open_v2(input.path, &source, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            throw LegacySnapshotError.database(source.map { String(cString: sqlite3_errmsg($0)) } ?? "open source")
        }
        // SQLITE_OPEN_EXCLUSIVE is reserved for the VFS and does not provide
        // exclusive creation through sqlite3_open_v2. Claim the path atomically.
        let fd = open(destinationURL.path, O_CREAT | O_EXCL | O_WRONLY, S_IRUSR | S_IWUSR)
        guard fd >= 0 else {
            if errno == EEXIST { throw LegacySnapshotError.destinationExists }
            throw LegacySnapshotError.database("create snapshot: \(String(cString: strerror(errno)))")
        }
        close(fd)
        do {
            guard sqlite3_open_v2(destinationURL.path, &destination,
                                  SQLITE_OPEN_READWRITE,
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
    private static func fileDigest(_ url: URL) throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty { hash.update(data: data) }
        return Data(hash.finalize())
    }

}
