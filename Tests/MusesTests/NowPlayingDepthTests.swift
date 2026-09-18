import XCTest
@testable import Muses

@MainActor
final class NowPlayingDepthTests: XCTestCase {

    func testParseLRCReadsTimestampsAndSkipsMetadata() {
        let lrc = """
        [ti:Title]
        [ar:Artist]
        [offset:250]
        [00:01.00]hello
        [00:02.50][00:10.00]repeat
        untimed line
        """
        let lines = LyricsService.parseLRC(lrc)
        XCTAssertEqual(lines.map(\.text), ["hello", "repeat", "repeat", "untimed line"])
        XCTAssertEqual(lines[0].time, 1.0)
        XCTAssertEqual(lines[1].time, 2.5)
        XCTAssertEqual(lines[2].time, 10.0)
        XCTAssertNil(lines[3].time)
    }

    func testParseLRCFractionalMilliseconds() {
        let lines = LyricsService.parseLRC("[01:23.456]late")
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].time ?? 0, 83.456, accuracy: 0.0001)
        XCTAssertEqual(lines[0].text, "late")
    }

    func testParseOffsetMs() {
        XCTAssertEqual(LyricsService.parseOffsetMs("[offset:250]abc"), 250)
        XCTAssertEqual(LyricsService.parseOffsetMs("[offset:-500]\n[00:01.00]hi"), -500)
        XCTAssertNil(LyricsService.parseOffsetMs("[00:01.00]no offset tag"))
        XCTAssertNil(LyricsService.parseOffsetMs(""))
    }

    func testTenBandUIMapsOntoThirtyTwoEngineSlots() {
        var ui = EQPresets.flat
        ui[5].gain = 6
        let mapped = EQBandMapping.assignments(from: ui, slotCount: 32)
        XCTAssertEqual(mapped.count, 32)
        XCTAssertEqual(mapped.filter { !$0.bypass }.count, 10)
        XCTAssertEqual(mapped.filter(\.bypass).count, 22)
        XCTAssertEqual(mapped[5].frequency, 1000)
        XCTAssertEqual(mapped[5].gain, 6)
        XCTAssertFalse(mapped[5].bypass)
        XCTAssertTrue(mapped[10].bypass)
        XCTAssertEqual(mapped[0].frequency, 31)
    }

    func testFlatPresetLeavesTenActiveZeroGainBands() {
        let mapped = EQBandMapping.assignments(from: EQPresets.flat)
        XCTAssertTrue(mapped.prefix(10).allSatisfy { $0.gain == 0 && !$0.bypass })
    }

    func testNowPlayingDeckShowsOneCenterAndPeeksOnPhone() {
        XCTAssertEqual(NowPlayingDeckMetrics.radius(width: 390, landscape: false), 1)
        XCTAssertEqual(NowPlayingDeckMetrics.radius(width: 800, landscape: true), 2)
        XCTAssertEqual(NowPlayingDeckMetrics.radius(width: 1200, landscape: false), 3)
        let visible = CollectionDeckProjection.visibleIndices(count: 6, position: 2, radius: 1)
        XCTAssertEqual(visible, [1, 2, 3])
        let wide = CollectionDeckProjection.visibleIndices(count: 9, position: 4, radius: 3)
        XCTAssertEqual(wide, [1, 2, 3, 4, 5, 6, 7])
    }

    func testNowPlayingVerticalSkipNeedsDominantHeight() {
        XCTAssertTrue(
            CollectionDeckProjection.acceptsVerticalGesture(
                translation: CGSize(width: 10, height: -80),
                direction: .up,
                threshold: NowPlayingDeckMetrics.skipThreshold
            )
        )
        XCTAssertFalse(
            CollectionDeckProjection.acceptsVerticalGesture(
                translation: CGSize(width: 80, height: -20),
                direction: .up,
                threshold: NowPlayingDeckMetrics.skipThreshold
            )
        )
    }

    func testStreamParserUsesPlainURLAndAssemblesCipher() {
        let plain = YouTubeStreamParser.audioURL(from: [
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

        let cipher = YouTubeStreamParser.url(fromCipher: "url=https%3A%2F%2Fexample.com%2Fstream&s=ABC&sp=sig")
        XCTAssertEqual(cipher?.absoluteString, "https://example.com/stream?sig=ABC")
    }

    func testStreamParserReturnsNilForMissingURLOrUnusableCipher() {
        XCTAssertNil(YouTubeStreamParser.url(fromCipher: "s=ABC&sp=sig"))
        XCTAssertNil(YouTubeStreamParser.url(fromCipher: ""))
        XCTAssertNil(YouTubeStreamParser.url(fromFormat: [
            "mimeType": "audio/webm",
            "bitrate": 128000,
            "signatureCipher": "s=ONLYSIG&sp=sig"
        ]))
        XCTAssertNil(YouTubeStreamParser.audioURL(from: [
            "streamingData": [
                "adaptiveFormats": [
                    ["mimeType": "audio/webm", "bitrate": 128000]
                ]
            ]
        ]))
    }

    func testPipedEmptyAudioStreamsIsNotSuccess() {
        XCTAssertNil(YouTubeStreamParser.pipedAudioURL(from: [:]))
        XCTAssertNil(YouTubeStreamParser.pipedAudioURL(from: ["audioStreams": []]))
        let url = YouTubeStreamParser.pipedAudioURL(from: [
            "audioStreams": [
                ["bitrate": 64000, "url": "https://example.com/low"],
                ["bitrate": 160000, "url": "https://example.com/high"]
            ]
        ])
        XCTAssertEqual(url?.absoluteString, "https://example.com/high")
    }

    func testInnerTubeClientsFallbackOrderIsStable() {
        let clients = YouTubeInnerTubeClient.allCases
        XCTAssertEqual(clients.count, 4)
        XCTAssertEqual(clients, [.visionOS, .androidVR, .ios, .webEmbedded])
    }
}
