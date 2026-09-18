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
        XCTAssertEqual(InnertubePlayerClient.allCases, [.androidVR, .ios, .webEmbedded])
        XCTAssertEqual(YouTubeInnerTubeClient.allCases, InnertubePlayerClient.allCases)
    }

    func testWebRemixConfigurationIsCentralized() {
        let config = InnertubeConfiguration.default
        XCTAssertEqual(config.webRemixClientName, "WEB_REMIX")
        XCTAssertEqual(config.webRemixClientVersion, "1.20240617.01.00")
    }
}
