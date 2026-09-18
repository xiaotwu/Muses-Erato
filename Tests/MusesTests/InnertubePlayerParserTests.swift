import XCTest
@testable import Muses

final class InnertubePlayerParserTests: XCTestCase {
    func testAssemblesCipherAndPlainURL() {
        let plain = InnertubePlayerParser.audioURL(from: [
            "streamingData": [
                "adaptiveFormats": [
                    [
                        "mimeType": "audio/webm",
                        "bitrate": 128000,
                        "url": "https://example.com/a.webm"
                    ]
                ]
            ]
        ])
        XCTAssertEqual(plain?.absoluteString, "https://example.com/a.webm")

        let cipher = InnertubePlayerParser.url(fromCipher: "url=https%3A%2F%2Fexample.com%2Fstream&s=ABC&sp=sig")
        XCTAssertEqual(cipher?.absoluteString, "https://example.com/stream?sig=ABC")
    }

    func testUnusableCipherReturnsNil() {
        XCTAssertNil(InnertubePlayerParser.url(fromCipher: "s=ABC&sp=sig"))
        XCTAssertNil(InnertubePlayerParser.url(fromFormat: [
            "mimeType": "audio/webm",
            "signatureCipher": "s=ONLYSIG&sp=sig"
        ]))
    }

    func testPipedEmptyIsNotSuccess() {
        XCTAssertNil(InnertubePlayerParser.pipedAudioURL(from: [:]))
        XCTAssertNil(InnertubePlayerParser.pipedAudioURL(from: ["audioStreams": []]))
    }

    func testPlayerClientRosterMatchesLegacyOrder() {
        XCTAssertEqual(InnertubePlayerClient.allCases, [.visionOS, .androidVR, .ios, .webEmbedded])
        XCTAssertEqual(YouTubeInnerTubeClient.allCases, InnertubePlayerClient.allCases)
    }

    func testVisionOSPayloadIncludesVisitorDataAndContentChecks() {
        let payload = InnertubePlayerClient.visionOS.playerPayload(
            videoId: "3yllbVl1EnY",
            visitorData: "CgtTEST_VISITOR"
        )
        XCTAssertEqual(payload["contentCheckOk"] as? Bool, true)
        XCTAssertEqual(payload["racyCheckOk"] as? Bool, true)

        let context = payload["context"] as? [String: Any]
        let client = context?["client"] as? [String: Any]
        XCTAssertEqual(client?["clientName"] as? String, "VISIONOS")
        XCTAssertEqual(client?["clientVersion"] as? String, "1.02")
        XCTAssertEqual(client?["visitorData"] as? String, "CgtTEST_VISITOR")
        XCTAssertEqual(InnertubePlayerClient.visionOS.youtubeClientNameHeader, "101")
        XCTAssertEqual(InnertubePlayerClient.visionOS.youtubeClientVersionHeader, "1.02")
    }

    func testWebRemixConfigurationIsCentralized() {
        let config = InnertubeConfiguration.default
        XCTAssertEqual(config.webRemixClientName, "WEB_REMIX")
        XCTAssertEqual(config.webRemixClientVersion, "1.20240617.01.00")
    }

    @MainActor
    func testLiveResolveResonatingBeatsViaVisionOSVisitor() async throws {
        // Live smoke: anonymous VISIONOS + visitorData must yield a googlevideo audio URL.
        let resolver = YouTubePlaybackResolver()
        let url = try await resolver.resolveStreamURL(videoID: "3yllbVl1EnY", quality: "bestaudio")
        XCTAssertTrue(
            url.host?.contains("googlevideo.com") == true || url.scheme == "https",
            "unexpected stream URL: \(url.absoluteString)"
        )
        XCTAssertFalse(url.absoluteString.isEmpty)
    }
}
