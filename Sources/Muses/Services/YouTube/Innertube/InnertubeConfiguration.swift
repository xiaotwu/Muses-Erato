import Foundation

/// Central Innertube client identities. Versions live here so call sites stay replaceable.
struct InnertubeConfiguration: Sendable {
    var language: String
    var region: String
    var musicOrigin: String
    var musicUserAgent: String
    var webRemixClientName: String
    var webRemixClientVersion: String
    var playerClients: [InnertubePlayerClient]

    static let `default` = InnertubeConfiguration(
        language: "en",
        region: "US",
        musicOrigin: "https://music.youtube.com",
        musicUserAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15",
        webRemixClientName: "WEB_REMIX",
        webRemixClientVersion: "1.20240617.01.00",
        playerClients: InnertubePlayerClient.allCases
    )
}

enum InnertubePlayerClient: CaseIterable, Sendable {
    case androidVR
    case ios
    case webEmbedded

    var userAgent: String {
        switch self {
        case .androidVR:
            return "com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12; eureka-user Build/SQ3A.220605.009.A1) gzip"
        case .ios:
            return "com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iPhone OS 18_0 like Mac OS X)"
        case .webEmbedded:
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15"
        }
    }

    func playerPayload(videoId: String, language: String = "en", region: String = "US") -> [String: Any] {
        switch self {
        case .androidVR:
            return [
                "videoId": videoId,
                "context": [
                    "client": [
                        "clientName": "ANDROID_VR",
                        "clientVersion": "1.60.19",
                        "deviceMake": "Oculus",
                        "deviceModel": "Quest 3",
                        "androidSdkVersion": 32,
                        "osName": "Android",
                        "osVersion": "12",
                        "hl": language,
                        "gl": region
                    ]
                ]
            ]
        case .ios:
            return [
                "videoId": videoId,
                "context": [
                    "client": [
                        "clientName": "IOS",
                        "clientVersion": "19.29.1",
                        "deviceMake": "Apple",
                        "deviceModel": "iPhone16,2",
                        "osName": "iOS",
                        "osVersion": "18.0.0",
                        "hl": language,
                        "gl": region
                    ]
                ]
            ]
        case .webEmbedded:
            return [
                "videoId": videoId,
                "context": [
                    "client": [
                        "clientName": "WEB_EMBEDDED_PLAYER",
                        "clientVersion": "1.20240324.01.00",
                        "hl": language,
                        "gl": region
                    ],
                    "thirdParty": [
                        "embedUrl": "https://www.youtube.com/"
                    ]
                ]
            ]
        }
    }
}

/// Compatibility alias for existing call sites / tests.
typealias YouTubeInnerTubeClient = InnertubePlayerClient
