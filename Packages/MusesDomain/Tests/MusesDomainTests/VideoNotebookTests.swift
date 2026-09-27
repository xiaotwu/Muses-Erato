import XCTest
@testable import MusesDomain

final class VideoNotebookTests: XCTestCase {
    func testRejectsUnsafeTimesIncludingDecodedValues() throws {
        let id = try TrackID(UUID().uuidString)
        for value in [-1.0, .infinity, -.infinity, .nan, Double(Int.max)] {
            XCTAssertThrowsError(try VideoTimeBookmark(trackID: id, timestampMilliseconds: value))
        }
        let valid = try VideoTimeBookmark(trackID: id, timestampMilliseconds: 1250.5, title: "Moment", note: "Words")
        XCTAssertEqual(try JSONDecoder().decode(VideoTimeBookmark.self, from: JSONEncoder().encode(valid)), valid)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(valid)) as? [String: Any])
        object["timestampMs"] = -1
        XCTAssertThrowsError(try JSONDecoder().decode(VideoTimeBookmark.self, from: JSONSerialization.data(withJSONObject: object)))
    }
    func testNoteEditPreservesIdentityCreationAndVerbatimContent() throws {
        let note = VideoNote(trackID: try TrackID(UUID().uuidString), content: "Old", createdAt: .distantPast, updatedAt: .distantPast)
        let edited = note.edited(content: "  New\nwords  ", at: .distantFuture)
        XCTAssertEqual(edited.id, note.id)
        XCTAssertEqual(edited.trackID, note.trackID)
        XCTAssertEqual(edited.createdAt, note.createdAt)
        XCTAssertEqual(edited.updatedAt, .distantFuture)
        XCTAssertEqual(edited.content, "  New\nwords  ")
    }
}
