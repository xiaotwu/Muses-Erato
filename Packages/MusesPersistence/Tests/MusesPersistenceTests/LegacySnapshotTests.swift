import Foundation
import SQLite3
import XCTest
@testable import MusesPersistence

final class LegacySnapshotTests: XCTestCase {
    func testSnapshotIncludesCommittedWALAndLeavesSourceFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("old.sqlite")
        let copy = directory.appendingPathComponent("copy.sqlite")
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(source.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, "CREATE TABLE user_truth (value TEXT)", nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, "INSERT INTO user_truth VALUES ('from wal')", nil, nil, nil), SQLITE_OK)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path + "-wal"))
        let originalSHM = try Data(contentsOf: URL(fileURLWithPath: source.path + "-shm"))
        let originalMain = try Data(contentsOf: source)
        let originalWAL = try Data(contentsOf: URL(fileURLWithPath: source.path + "-wal"))
        XCTAssertEqual(try LegacyStoreSnapshotter.snapshot(sourceURL: source, destinationURL: copy), copy)
        var copied: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(copy.path, &copied, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(copied) }
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(copied, "SELECT value FROM user_truth", -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        XCTAssertEqual(String(cString: sqlite3_column_text(statement, 0)), "from wal")
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path + "-wal"))
        XCTAssertEqual(try Data(contentsOf: source), originalMain)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: source.path + "-shm")), originalSHM)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: source.path + "-wal")), originalWAL)
    }

    func testCorruptSourceDoesNotProduceReplacementStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("broken.sqlite")
        let copy = directory.appendingPathComponent("copy.sqlite")
        try Data("not a database".utf8).write(to: source)
        XCTAssertThrowsError(try LegacyStoreSnapshotter.snapshot(sourceURL: source, destinationURL: copy))
        XCTAssertFalse(FileManager.default.fileExists(atPath: copy.path))
        XCTAssertEqual(try Data(contentsOf: source), Data("not a database".utf8))
    }
    func testExistingDestinationSidecarIsPreserved() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.sqlite")
        let copy = directory.appendingPathComponent("copy.sqlite")
        try Data().write(to: source)
        let sidecar = URL(fileURLWithPath: copy.path + "-wal")
        let evidence = Data("orphaned user data".utf8)
        try evidence.write(to: sidecar)
        XCTAssertThrowsError(try LegacyStoreSnapshotter.snapshot(sourceURL: source, destinationURL: copy)) { error in
            XCTAssertEqual(error as? LegacySnapshotError, .destinationExists)
        }
        XCTAssertEqual(try Data(contentsOf: sidecar), evidence)
        XCTAssertFalse(FileManager.default.fileExists(atPath: copy.path))
    }

    func testArchiveFieldInventoryEncodingIsCanonical() throws {
        let fields: Set<String> = ["z", "b", "a"]
        let archive = LegacyModelArchive(id: UUID(), fields: Data(), fieldNames: fields)
        let data = try JSONEncoder().encode(archive)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["fieldNames"] as? [String], ["a", "b", "z"])
        XCTAssertEqual(try JSONDecoder().decode(LegacyModelArchive.self, from: data).fieldNames, fields)
    }

}
