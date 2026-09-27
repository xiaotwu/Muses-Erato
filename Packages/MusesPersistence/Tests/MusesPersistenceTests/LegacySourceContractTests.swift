import Foundation
import XCTest
@testable import MusesPersistence

/// This is a source contract check, not a physical old-store migration fixture.
/// It fails when the inherited autoschema changes without updating the archive.
final class LegacySourceContractTests: XCTestCase {
    private var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOf: root.appending(path: path), encoding: .utf8)
    }

    private func captures(_ pattern: String, in text: String) throws -> Set<String> {
        let expression = try NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return Set(expression.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        })
    }

    private func modelFields(_ name: String, file: String) throws -> Set<String> {
        let text = try source("Sources/Muses/Domain/\(file).swift")
        guard let start = text.range(of: "@Model\nfinal class \(name) {")?.upperBound,
              let end = text[start...].range(of: "\n    init(")?.lowerBound else {
            XCTFail("Missing inherited model declaration: \(name)")
            return []
        }
        return try captures(#"\bvar\s+(\w+)\s*:"#, in: String(text[start..<end]))
    }

    func testEveryInheritedModelAndFieldHasAnArchiveContract() throws {
        let schema = try source("Sources/Muses/Persistence/MusesSchema.swift")
        let declared = try captures(#"\b(\w+)\.self"#, in: schema)
        XCTAssertEqual(declared.count, 19)

        let archive = try source("Packages/MusesPersistence/Sources/MusesPersistence/LegacyArchive.swift")
        let trackSection = archive.components(separatedBy: "public struct LegacyTrackArchive")[1]
            .components(separatedBy: "public func publicTrack")[0]
        XCTAssertEqual(try captures(#"\bvar\s+(\w+)\s*:"#, in: trackSection),
                       try modelFields("Track", file: "Track").subtracting(["youTubeImportItems"]))
        // The Track inverse is represented by each YouTubeImportItem.track ID.
        XCTAssertTrue(LegacyModelKind.youTubeImportItem.requiredFields.contains("track"))

        let queueSection = archive.components(separatedBy: "public struct LegacyQueueArchive")[1]
            .components(separatedBy: "public func validate")[0]
        XCTAssertEqual(try captures(#"\bvar\s+(\w+)\s*:"#, in: queueSection),
                       try modelFields("QueueState", file: "QueueState"))

        let models: [(LegacyModelKind, String, String)] = [
            (.youTubeImport, "YouTubeImport", "YouTubeImport"),
            (.youTubeImportItem, "YouTubeImportItem", "YouTubeImportItem"),
            (.playlist, "Playlist", "Playlist"),
            (.playlistItem, "PlaylistItem", "PlaylistItem"),
            (.listeningEvent, "ListeningEvent", "ListeningEvent"),
            (.trackNote, "TrackNote", "NotesModels"),
            (.trackBookmark, "TrackBookmark", "NotesModels"),
            (.listeningSession, "ListeningSession", "ListeningSession"),
            (.inboxItem, "InboxItem", "InboxItem"),
            (.eqPreset, "EQPreset", "EQPreset"),
            (.automationRule, "AutomationRule", "AutomationRule"),
            (.focusSession, "FocusSession", "FocusSession"),
            (.playlistRevision, "YouTubePlaylistRevision", "YouTubePlaylistSync"),
            (.syncBatch, "YouTubeSyncBatch", "YouTubePlaylistSync"),
            (.syncOperation, "YouTubeSyncOperation", "YouTubePlaylistSync"),
        ]
        for (kind, name, file) in models {
            XCTAssertEqual(kind.requiredFields, try modelFields(name, file: file), name)
        }
        XCTAssertEqual(declared, Set(models.map { $0.1 }).union([
            "Track", "QueueState", "CatalogRelease", "CatalogArtist"
        ]))
    }

    func testAllPersistedPreferenceKeysAreInventoried() throws {
        let preferences = try source("Sources/Muses/Domain/UserPreferences.swift")
        let prefSection = preferences.components(separatedBy: "enum PrefKey {")[1]
            .components(separatedBy: "enum FeatureFlagDefaults")[0]
        let declared = try captures(#"=\s*"(muses\.[^"]+)""#, in: prefSection)
        XCTAssertEqual(declared.count, 51)
        XCTAssertEqual(LegacyCompleteBundle.knownSettingKeys,
                       declared.union(["muses.search.recentQueries"]))
    }

    func testSettingsSnapshotCapturesOnlyExplicitValuesAndPreservesTypes() throws {
        let suite = "legacy.settings.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.register(defaults: ["muses.theme": "registered only"])
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let bytes = Data([0, 1, 255])
        defaults.set(date, forKey: "muses.updates.lastCheckAt")
        defaults.set(bytes, forKey: "muses.custom.savedData")
        defaults.set(["alpha", "beta"], forKey: "muses.search.recentQueries")
        defaults.set("unrelated", forKey: "other.key")

        let snapshot = try LegacySettingsSnapshot.read(defaults: defaults, domainName: suite)
        XCTAssertEqual(Set(snapshot.values.map(\.key)), [
            "muses.updates.lastCheckAt", "muses.custom.savedData", "muses.search.recentQueries"
        ])
        XCTAssertFalse(snapshot.values.contains { $0.key == "muses.theme" })
        XCTAssertTrue(snapshot.inspectedKeys.isSuperset(of: LegacyCompleteBundle.knownSettingKeys))
        let decoded = try Dictionary(uniqueKeysWithValues: snapshot.values.map { row in
            let envelope = try XCTUnwrap(PropertyListSerialization.propertyList(
                from: row.value, format: nil) as? [String: Any])
            return (row.key, try XCTUnwrap(envelope["value"]))
        })
        XCTAssertEqual(decoded["muses.updates.lastCheckAt"] as? Date, date)
        XCTAssertEqual(decoded["muses.custom.savedData"] as? Data, bytes)
        XCTAssertEqual(decoded["muses.search.recentQueries"] as? [String], ["alpha", "beta"])
    }
}
