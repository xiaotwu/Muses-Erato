import Foundation

/// Low-level youtubei HTTP client. Discovery and playback share this transport.
@MainActor
final class InnertubeClient {
    private let session: URLSession
    private let configuration: InnertubeConfiguration
    private var authentication: InnertubeAuthentication

    init(
        session: URLSession = .shared,
        configuration: InnertubeConfiguration = .default,
        authentication: InnertubeAuthentication = .anonymous
    ) {
        self.session = session
        self.configuration = configuration
        self.authentication = authentication
    }

    func updateAuthentication(_ authentication: InnertubeAuthentication) {
        self.authentication = authentication
    }

    /// `youtubei/v1/player` for a configured player client.
    func player(videoID: String, client: InnertubePlayerClient, timeout: TimeInterval = 20) async throws -> [String: Any] {
        guard let endpoint = URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false") else {
            throw InnertubeError.invalidResponse
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue(client.userAgent, forHTTPHeaderField: "User-Agent")
        applyAuth(&request)
        request.httpBody = try JSONSerialization.data(
            withJSONObject: client.playerPayload(
                videoId: videoID,
                language: configuration.language,
                region: configuration.region
            )
        )
        return try await jsonObject(for: request)
    }

    /// `music.youtube.com/youtubei/v1/browse` (WEB_REMIX).
    func browse(browseId: String?, continuation: String?, timeout: TimeInterval = 20) async throws -> [String: Any] {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/browse?prettyPrint=false") else {
            throw InnertubeError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.musicOrigin, forHTTPHeaderField: "Origin")
        request.setValue("\(configuration.musicOrigin)/", forHTTPHeaderField: "Referer")
        request.setValue(configuration.musicUserAgent, forHTTPHeaderField: "User-Agent")
        applyAuth(&request)
        var payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": configuration.webRemixClientName,
                    "clientVersion": configuration.webRemixClientVersion,
                    "hl": configuration.language,
                    "gl": configuration.region
                ]
            ]
        ]
        if let continuation {
            payload["continuation"] = continuation
        } else if let browseId {
            payload["browseId"] = browseId
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return try await jsonObject(for: request)
    }

    private func applyAuth(_ request: inout URLRequest) {
        if case .oauth(let token) = authentication, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func jsonObject(for request: URLRequest) async throws -> [String: Any] {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw InnertubeError.timeout
        } catch {
            throw InnertubeError.networkError(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw InnertubeError.invalidResponse
        }
        return json
    }
}
