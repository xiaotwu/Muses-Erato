import Foundation

enum InnertubeError: LocalizedError, Equatable, Sendable {
    case invalidResponse
    case networkError(String)
    case timeout
    case streamNotFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return tr("Invalid response from YouTube service", "YouTube 服务响应无效")
        case .networkError(let msg):
            return tr("Network error: \(msg)", "网络错误：\(msg)")
        case .timeout:
            return tr("Request timed out", "请求超时")
        case .streamNotFound(let id):
            return tr("No audio stream found for video: \(id)", "未找到视频的音频流：\(id)")
        }
    }
}

enum InnertubeAuthentication: Sendable {
    case anonymous
    case oauth(accessToken: String)
}
