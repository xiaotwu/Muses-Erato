#if DEBUG
import Foundation
import AVFoundation
import MusesNetworking

/// Only activated by an isolated UI test library plus explicit fixture mode.
/// Does not read credentials or contact any network endpoint.
actor PublicCatalogFixtureTransport: HTTPTransport {
    private var failedNext = false
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        let url = request.url!
        let query = Dictionary(uniqueKeysWithValues: URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value ?? "") })
        let second = query["pageToken"] != nil
        var body = ""
        switch url.lastPathComponent {
        case "search":
            if query["q"] == "quota" { return HTTPResponse(status: 403, body: Data(#"{"error":{"errors":[{"reason":"quotaExceeded"}]}}"#.utf8)) }
            if second && !failedNext { failedNext = true; throw URLError(.notConnectedToInternet) }
            switch query["type"] {
            case "playlist": body = #"{"items":[{"id":{"playlistId":"PLfixture"},"snippet":{"title":"Fixture public playlist"}}]}"#
            case "channel": body = #"{"items":[{"id":{"channelId":"UCabcdefghijklmnopqrstuv"},"snippet":{"title":"Fixture channel"}}]}"#
            default:
                body = second ? #"{"items":[{"id":{"videoId":"lmnopqrstuv"},"snippet":{"title":"Fixture second video"}}]}"# : #"{"nextPageToken":"second","items":[{"id":{"videoId":"abcdefghijk"},"snippet":{"title":"Fixture first video","channelId":"UCabcdefghijklmnopqrstuv"}}]}"#
            }
        case "videos":
            let ids = (query["id"] ?? "").split(separator: ",").map(String.init)
            let items = ids.map { id -> [String: Any] in
                ["id": id, "snippet": ["title": "YouTube video \(id)", "channelTitle": "Fixture artist - Topic"],
                 "status": ["madeForKids": id == "MFKabcdefgh", "embeddable": true]]
            }
            return HTTPResponse(status: 200, body: try JSONSerialization.data(withJSONObject: ["items": items]))
        case "channels": body = #"{"items":[{"id":"UCabcdefghijklmnopqrstuv","snippet":{"title":"Fixture channel","description":"Fixture channel description"},"contentDetails":{"relatedPlaylists":{"uploads":"UUfixture"}}}]}"#
        case "playlistItems": body = second ? #"{"items":[{"id":"entry2","snippet":{"title":"Fixture playlist video 2","resourceId":{"videoId":"lmnopqrstuv"}}}]}"# : #"{"nextPageToken":"second","items":[{"id":"entry1","snippet":{"title":"Fixture playlist video 1","resourceId":{"videoId":"abcdefghijk"}}}]}"#
        case "playlists": body = second ? #"{"items":[{"id":"PLsecond","snippet":{"title":"Fixture playlist 2"}}]}"# : #"{"nextPageToken":"second","items":[{"id":"PLfixture","snippet":{"title":"Fixture public playlist","description":"Fixture playlist description","channelId":"UCabcdefghijklmnopqrstuv"}}]}"#
        case "subscriptions": body = second ? #"{"items":[{"id":"sub2","snippet":{"title":"Fixture subscription 2","resourceId":{"channelId":"UCzyxwvutsrqponmlkjihgfe"}}}]}"# : #"{"nextPageToken":"second","items":[{"id":"sub1","snippet":{"title":"Fixture subscription 1","resourceId":{"channelId":"UCabcdefghijklmnopqrstuv"}}}]}"#
        default: body = #"{"items":[]}"#
        }
        if query["id"] != nil, url.lastPathComponent == "playlists" {
            body = body.replacingOccurrences(of: "\"nextPageToken\":\"second\",", with: "")
        }
        return HTTPResponse(status: 200, body: Data(body.utf8))
    }
}
/// Generated silence exercises AVPlayer without streaming media or authenticating.
@MainActor enum PublicFixtureAudio {
    static func makeURL() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("muses-ui-silence.wav")
        if FileManager.default.fileExists(atPath: url.path) { return url }
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16000 * 30)!
        buffer.frameLength = buffer.frameCapacity
        if let samples = buffer.floatChannelData?[0] { samples.initialize(repeating: 0, count: Int(buffer.frameLength)) }
        do { let file = try AVAudioFile(forWriting: url, settings: format.settings); try file.write(from: buffer) }
        return url
    }
}
#endif
