import Foundation

/// Low-level youtubei HTTP client. Discovery and playback share this transport.
@MainActor
final class InnertubeClient {
    private let session: URLSession
    private let configuration: InnertubeConfiguration
    private var authentication: InnertubeAuthentication

    /// Cached `VISITOR_DATA` scraped from YouTube HTML (watch page preferred).
    private var cachedVisitorData: String?
    /// Optional Innertube API key scraped alongside visitor data.
    private var cachedApiKey: String?

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

    /// Drop cached visitor / apiKey so the next player call re-bootstraps from HTML.
    func invalidateVisitorBootstrap() {
        cachedVisitorData = nil
        cachedApiKey = nil
    }

    /// `youtubei/v1/player` for a configured player client.
    func player(videoID: String, client: InnertubePlayerClient, timeout: TimeInterval = 20) async throws -> [String: Any] {
        // Prefer a scraped visitorData; continue anonymously if HTML bootstrap fails.
        var visitorData = try? await ensureVisitorData(for: videoID, timeout: timeout)
        var json = try await performPlayer(
            videoID: videoID,
            client: client,
            visitorData: visitorData,
            timeout: timeout
        )

        if Self.playabilityStatus(of: json) == "LOGIN_REQUIRED" {
            invalidateVisitorBootstrap()
            visitorData = try? await ensureVisitorData(for: videoID, timeout: timeout)
            if let visitorData {
                json = try await performPlayer(
                    videoID: videoID,
                    client: client,
                    visitorData: visitorData,
                    timeout: timeout
                )
            }
        }

        return json
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

    /// `music.youtube.com/youtubei/v1/search` (WEB_REMIX).
    func search(query: String, params: String? = nil, continuation: String? = nil, timeout: TimeInterval = 20) async throws -> [String: Any] {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/search?prettyPrint=false") else {
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
        } else {
            payload["query"] = query
            if let params {
                payload["params"] = params
            }
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return try await jsonObject(for: request)
    }

    private func performPlayer(
        videoID: String,
        client: InnertubePlayerClient,
        visitorData: String?,
        timeout: TimeInterval
    ) async throws -> [String: Any] {
        guard let endpoint = URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false") else {
            throw InnertubeError.invalidResponse
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue(client.userAgent, forHTTPHeaderField: "User-Agent")
        if let visitorData, !visitorData.isEmpty {
            request.setValue(visitorData, forHTTPHeaderField: "X-Goog-Visitor-Id")
        }
        if let name = client.youtubeClientNameHeader {
            request.setValue(name, forHTTPHeaderField: "X-Youtube-Client-Name")
        }
        if let version = client.youtubeClientVersionHeader {
            request.setValue(version, forHTTPHeaderField: "X-Youtube-Client-Version")
        }
        applyAuth(&request)
        request.httpBody = try JSONSerialization.data(
            withJSONObject: client.playerPayload(
                videoId: videoID,
                language: configuration.language,
                region: configuration.region,
                visitorData: visitorData
            )
        )
        return try await jsonObject(for: request)
    }

    private func ensureVisitorData(for videoID: String, timeout: TimeInterval) async throws -> String {
        if let cachedVisitorData, !cachedVisitorData.isEmpty {
            return cachedVisitorData
        }

        let candidates = [
            "https://www.youtube.com/watch?v=\(videoID)",
            "https://www.youtube.com/"
        ]

        for urlString in candidates {
            guard let url = URL(string: urlString) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = timeout
            request.setValue(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15",
                forHTTPHeaderField: "User-Agent"
            )
            request.setValue("https://www.youtube.com/", forHTTPHeaderField: "Referer")

            guard let (data, response) = try? await session.data(for: request),
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                continue
            }

            if let visitor = Self.captureBootstrapValue("VISITOR_DATA", in: html), !visitor.isEmpty {
                cachedVisitorData = visitor
                if let apiKey = Self.captureBootstrapValue("INNERTUBE_API_KEY", in: html), !apiKey.isEmpty {
                    cachedApiKey = apiKey
                }
                return visitor
            }
        }

        throw InnertubeError.invalidResponse
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

    static func playabilityStatus(of json: [String: Any]) -> String? {
        (json["playabilityStatus"] as? [String: Any])?["status"] as? String
    }

    /// Same capture shape as macOS Muses WebHome bootstrap.
    static func captureBootstrapValue(_ key: String, in string: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: key)
        let pattern = "[\\\"]\(escaped)[\\\"]\\s*:\\s*[\\\"]([^\\\"]+)[\\\"]"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              let range = Range(match.range(at: 1), in: string) else {
            return nil
        }
        return String(string[range])
    }
}
