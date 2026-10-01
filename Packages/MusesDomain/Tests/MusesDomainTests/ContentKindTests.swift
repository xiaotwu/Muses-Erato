import XCTest
@testable import MusesDomain

final class ContentKindTests: XCTestCase {
    private func track(at date: Date) throws -> Track {
        Track(id: try TrackID(UUID().uuidString), title: "API title", artist: "API artist",
              source: .youtubeVideo(try VideoID("abcdefghijk")),
              provenance: try Provenance(provider: ProviderID("youtube"), originalID: "abcdefghijk"),
              liked: true, metadataOrigin: .youtubeDataAPI, metadataFetchedAt: date, contentKind: .music)
    }

    func testLegacyTrackDecodesWithoutContentKindAndNewFieldRoundTrips() throws {
        let original = try track(at: Date())
        XCTAssertEqual(try JSONDecoder().decode(Track.self, from: JSONEncoder().encode(original)), original)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        json.removeValue(forKey: "contentKind")
        let legacy = try JSONDecoder().decode(Track.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(legacy.contentKind)
        XCTAssertTrue(legacy.liked)
    }

    func testAPIClassificationExpiresAndNeverEntersLocalSnapshot() throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        var value = try track(at: now)
        value.expireYouTubeMetadata(at: now)
        XCTAssertEqual(value.contentKind, .music)
        XCTAssertNil(value.localPersistenceSnapshot.contentKind)
        value.expireYouTubeMetadata(at: now.addingTimeInterval(29 * 86400))
        XCTAssertNil(value.contentKind)
        XCTAssertTrue(value.liked)
        XCTAssertEqual(value.metadataOrigin, .placeholder)
    }

    func testForceClearDoesNotRemoveUserTitleOrFavoriting() throws {
        var value = try track(at: Date())
        value.metadataOrigin = .user; value.title = "My title"
        XCTAssertNil(value.localPersistenceSnapshot.contentKind)
        XCTAssertEqual(value.localPersistenceSnapshot.title, "My title")
        value.expireYouTubeMetadata(force: true)
        XCTAssertNil(value.contentKind)
        XCTAssertEqual(value.title, "My title")
        XCTAssertEqual(value.metadataOrigin, .user)
        XCTAssertTrue(value.liked)
    }
}
