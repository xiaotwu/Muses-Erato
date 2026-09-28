import Foundation
import SwiftData
import XCTest
@testable import MusesPersistence

@MainActor final class ArchiveLifecycleTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 10_000_000)
    private let age: TimeInterval = 29 * 86_400
    private func field(_ address: String, _ value: String) throws -> ArchiveField {
        ArchiveField(address: address, value: try JSONEncoder().encode(value))
    }
    private func plan(_ fields: [ArchiveField], _ evidence: [ArchiveEvidence], at: Date? = nil,
                      revoked: Set<String> = [], excluded: Set<String> = []) throws -> ArchiveSuccessor {
        try ArchiveLifecycle.successor(fields: fields, evidence: evidence,
            originalReceipt: .init(recordCount: 19, payloadSHA256: "original-receipt"), parentArchiveDigest: "parent",
            now: at ?? now, maximumAPIAge: age, revokedAuthorizations: revoked, excludedAddresses: excluded)
    }
    func testMixedRecordPreservesOnlyEvidencedUserInputWithoutChangingReceipt() throws {
        let note = try field("model/trackNote/one/content", "我的文字"), title = try field("track/one/title", "Remote title")
        let nested = try field("queue/one/itemsJSON", "[{\"title\":\"Mixed\"}]")
        let result = try plan([note, title, nested], [ArchiveEvidence(field: note, origin: .userInput,
            reference: "review: NotesService.setTrackNote + NotesSheets input, baseline dd6fabb")])
        XCTAssertEqual(result.userFields, [note]); XCTAssertTrue(result.hasUnresolvedFields)
        XCTAssertEqual(result.originalReceipt?.payloadSHA256, "original-receipt")
        XCTAssertEqual(result.assessments.filter { $0.origin == .unknown }.count, 2)
        let reopened = try JSONDecoder().decode(ArchiveSuccessor.self, from: JSONEncoder().encode(result))
        XCTAssertEqual(reopened.userFields, [note]); XCTAssertEqual(reopened.originalReceipt, result.originalReceipt)
    }
    func testClockBoundaryMissingFutureDatesAndRevocationDoNotRenewAge() throws {
        let value = try field("track/one/title", "API")
        let fetched = now.addingTimeInterval(-age)
        let proof = ArchiveEvidence(field: value, origin: .publicAPI, reference: "fixture response", fetchedAt: fetched)
        XCTAssertEqual(try plan([value], [proof], at: now.addingTimeInterval(-1)).assessments.first?.disposition, .temporaryAPI)
        XCTAssertEqual(try plan([value], [proof]).assessments.first?.disposition, .removalDue)
        XCTAssertEqual(try plan([value], [proof], at: now.addingTimeInterval(90 * 86_400)).assessments.first?.deadline, now)
        for date in [nil, now.addingTimeInterval(1)] as [Date?] {
            let item = ArchiveEvidence(field: value, origin: .publicAPI, reference: "review", fetchedAt: date)
            XCTAssertEqual(try plan([value], [item]).assessments.first?.disposition, .removalDue)
        }
        let authorized = ArchiveEvidence(field: value, origin: .authorizedAPI, reference: "authorized response",
            fetchedAt: now, authorizationReference: "synthetic-grant")
        XCTAssertEqual(try plan([value], [authorized], revoked: ["synthetic-grant"]).assessments.first?.disposition, .removalDue)
        XCTAssertEqual(try plan([value], [authorized]).assessments.first?.origin, .authorizedAPI)
    }
    func testEvidenceCannotBeReusedAfterFieldEditOrWithoutAuthorizationLineage() throws {
        let original = try field("a", "original"), changed = try field("a", "changed")
        let proof = ArchiveEvidence(field: original, origin: .userInput, reference: "review")
        XCTAssertThrowsError(try plan([changed], [proof]))
        XCTAssertThrowsError(try plan([original], [proof, proof]))
        XCTAssertThrowsError(try plan([original], [ArchiveEvidence(field: original, origin: .authorizedAPI, reference: "review")]))
        let result = try plan([original], [proof], excluded: ["a"])
        XCTAssertTrue(result.userFields.isEmpty)
        XCTAssertEqual(result.assessments.first?.disposition, .excludedByDeletion)
    }
    func testInventoryIncludesUnknownFieldsAndOpaqueNestedPayloads() throws {
        let model = LegacyModelArchive(id: UUID(), fields: Data("{\"content\":\"note\",\"futureField\":{\"remote\":1}}".utf8), fieldNames: ["content", "futureField"])
        let archive = LegacyLibraryArchive(formatVersion: 1, receipt: nil, tracks: [], queue: [], models: ["trackNote": [model]], settings: [])
        let values = try ArchiveLifecycle.inventory(archive)
        XCTAssertEqual(values.count, 2)
        XCTAssertTrue(values.contains { $0.address.hasSuffix("/futureField") })
        XCTAssertTrue(try plan(values, []).assessments.allSatisfy { $0.origin == .unknown })
    }
    func testRemovalFailureSurvivingBytesAndRestartRemainPending() throws {
        enum Failure: Error { case denied }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("synthetic disposable copy".utf8).write(to: file)
        var journal = try ArchiveRemovalJournal(successorID: UUID(), requiredArtifactIDs: ["copy", "wal"])
        XCTAssertThrowsError(try journal.attempt("copy", remove: { throw Failure.denied }, isAbsent: { true }))
        XCTAssertFalse(journal.allListedArtifactsAbsent)
        journal = try JSONDecoder().decode(ArchiveRemovalJournal.self, from: JSONEncoder().encode(journal))
        XCTAssertEqual(journal.failedArtifactIDs, ["copy"])
        XCTAssertThrowsError(try journal.attempt("copy", remove: {}, isAbsent: { !FileManager.default.fileExists(atPath: file.path) }))
        try journal.attempt("copy", remove: { try FileManager.default.removeItem(at: file) }, isAbsent: { !FileManager.default.fileExists(atPath: file.path) })
        XCTAssertFalse(journal.allListedArtifactsAbsent)
        try journal.attempt("wal", remove: {}, isAbsent: { true })
        XCTAssertTrue(journal.allListedArtifactsAbsent)
        XCTAssertThrowsError(try journal.attempt("unlisted-original", remove: { XCTFail("must not execute") }, isAbsent: { true }))
    }
    func testStagingPersistsRestoreBarrierAndDoesNotRewriteArchiveOrReceipt() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("candidate.sqlite")
        var originalDigest = ""
        try autoreleasepool {
            let container = try SwiftDataSnapshotRepository.container(url: url)
            let repo = SwiftDataSnapshotRepository(context: ModelContext(container))
            let model = LegacyModelArchive(id: UUID(), fields: Data("{\"content\":\"note\"}".utf8), fieldNames: ["content"])
            try repo.put(model, kind: .legacyModel, id: "trackNote:" + model.id.uuidString)
            let receipt = LegacyMigrationReceipt(recordCount: 1, payloadSHA256: "historical")
            try repo.put(receipt, kind: .migration, id: "legacy-complete-v1")
            originalDigest = try repo.legacyArchiveDigest()
            let fields = try ArchiveLifecycle.inventory(repo.legacyArchive())
            let successor = try ArchiveLifecycle.successor(fields: fields, evidence: [], originalReceipt: receipt,
                parentArchiveDigest: originalDigest, now: now, maximumAPIAge: age)
            let incomplete = try ArchiveLifecycle.successor(fields: [], evidence: [], originalReceipt: receipt,
                parentArchiveDigest: originalDigest, now: now, maximumAPIAge: age)
            XCTAssertThrowsError(try repo.stageArchiveSuccessor(incomplete))
            XCTAssertNoThrow(try repo.requireOriginalArchiveRestoreAllowed())
            try repo.stageArchiveSuccessor(successor)
            XCTAssertThrowsError(try repo.stageArchiveSuccessor(successor))
            XCTAssertEqual(try repo.legacyArchiveDigest(), originalDigest)
            XCTAssertEqual(try repo.legacyArchive().receipt, receipt)
        }
        let container = try SwiftDataSnapshotRepository.container(url: url)
        let reopened = SwiftDataSnapshotRepository(context: ModelContext(container))
        XCTAssertEqual(try reopened.legacyArchiveDigest(), originalDigest)
        XCTAssertThrowsError(try reopened.restoreOriginalPlaylist(UUID())) { error in
            XCTAssertEqual(error as? ArchiveLifecycleError, .restoreBlocked)
        }
        // Corruption cannot silently reopen the restore path.
        try reopened.put("damaged", kind: .migration, id: "archive-successor-v1")
        XCTAssertThrowsError(try reopened.requireOriginalArchiveRestoreAllowed())
    }
}
