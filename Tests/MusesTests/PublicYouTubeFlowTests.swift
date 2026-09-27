import XCTest
import MusesDomain
@testable import Muses

final class PublicYouTubeFlowTests: XCTestCase {
    func testLegacyGateBlocksEverySQLiteSidecar() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = directory.appending(path: "muses-youtube-native.sqlite")
        XCTAssertFalse(legacyStoreArtifactsPresent(at: store))
        for suffix in ["", "-wal", "-shm"] {
            let file = URL(fileURLWithPath: store.path + suffix)
            try Data([1]).write(to: file)
            XCTAssertTrue(legacyStoreArtifactsPresent(at: store), suffix)
            try FileManager.default.removeItem(at: file)
        }
    }

    func testKnownVideoLinksRejectOtherHostsAndMalformedIDs() throws {
        let id = "dQw4w9WgXcQ"
        XCTAssertEqual(PublicYouTubeSession.videoID(from: id)?.rawValue, id)
        XCTAssertEqual(PublicYouTubeSession.videoID(from: "https://www.youtube.com/watch?v=\(id)&t=42")?.rawValue, id)
        XCTAssertEqual(PublicYouTubeSession.videoID(from: "https://youtu.be/\(id)")?.rawValue, id)
        XCTAssertNil(PublicYouTubeSession.videoID(from: "https://youtube.com.evil.test/watch?v=\(id)"))
        XCTAssertNil(PublicYouTubeSession.videoID(from: "http://youtube.com/watch?v=\(id)"))
        XCTAssertNil(PublicYouTubeSession.videoID(from: "https://www.youtube.com/watch?v=bad"))
    }

    func testPublicYouTubeCapabilitiesDoNotExposeNativeAudio() throws {
        let source = PlaybackSource.youtubeVideo(try VideoID("dQw4w9WgXcQ"))
        let effective = PlaybackCapabilityPolicy.effective(
            source: source, rights: ContentRights(origin: .youtube),
            distribution: DistributionCapabilities(channel: .appStore),
            adapter: [.videoVisible, .seek, .queueByID, .audioProcessing, .backgroundAudio, .systemRemote],
            runtime: [.videoVisible, .seek, .queueByID, .audioProcessing, .backgroundAudio, .systemRemote])
        XCTAssertEqual(effective, [.videoVisible, .seek, .queueByID])
    }
}
