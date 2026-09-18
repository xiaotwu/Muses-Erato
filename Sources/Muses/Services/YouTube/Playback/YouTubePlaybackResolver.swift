import Foundation

@MainActor
protocol YouTubeStreamResolving: AnyObject {
    func resolveStreamURL(videoID: String, quality: String) async throws -> URL
    func invalidateCachedStream(videoID: String, quality: String)
}

/// Playback-only stream resolution: Innertube player, then optional Piped / Invidious fallbacks.
@MainActor
final class YouTubePlaybackResolver: YouTubeStreamResolving {
    private let session: URLSession
    private let innertube: InnertubeClient
    private let configuration: InnertubeConfiguration
    private let log = AppLog.for("YouTubePlaybackResolver")

    init(
        session: URLSession = .shared,
        innertube: InnertubeClient? = nil,
        configuration: InnertubeConfiguration = .default
    ) {
        self.session = session
        self.configuration = configuration
        self.innertube = innertube ?? InnertubeClient(session: session, configuration: configuration)
    }

    func resolveStreamURL(videoID: String, quality: String = "bestaudio") async throws -> URL {
        if let cached = StreamURLCache.default.get(videoId: videoID, quality: quality) {
            return cached
        }
        if let sample = Bundle.main.url(forResource: videoID, withExtension: "mp3")
            ?? Bundle.main.url(forResource: videoID, withExtension: "m4a") {
            return sample
        }

        do {
            let url = try await resolveViaInnerTube(videoID: videoID)
            StreamURLCache.default.set(videoId: videoID, url: url, quality: quality)
            return url
        } catch {
            log.warning("InnerTube resolution failed for \(videoID): \(error.localizedDescription)")
        }

        do {
            let url = try await resolveViaPiped(videoID: videoID)
            StreamURLCache.default.set(videoId: videoID, url: url, quality: quality)
            return url
        } catch {
            log.warning("Piped resolution failed for \(videoID): \(error.localizedDescription)")
        }

        do {
            let url = try await resolveViaInvidious(videoID: videoID)
            StreamURLCache.default.set(videoId: videoID, url: url, quality: quality)
            return url
        } catch {
            log.error("All stream resolution methods failed for \(videoID): \(error.localizedDescription)")
            throw InnertubeError.streamNotFound(videoID)
        }
    }

    func invalidateCachedStream(videoID: String, quality: String = "bestaudio") {
        StreamURLCache.default.invalidate(videoId: videoID, quality: quality)
    }

    private func resolveViaInnerTube(videoID: String, timeout: TimeInterval = 20) async throws -> URL {
        for client in configuration.playerClients {
            do {
                var json = try await innertube.player(videoID: videoID, client: client, timeout: timeout)
                if InnertubeClient.playabilityStatus(of: json) == "LOGIN_REQUIRED" {
                    log.warning("playabilityStatus LOGIN_REQUIRED for \(videoID) via \(String(describing: client))")
                }
                if let url = InnertubePlayerParser.audioURL(from: json) {
                    return url
                }
                // visionOS is first; if visitor bootstrap went stale, refresh once and retry.
                if client == .visionOS {
                    innertube.invalidateVisitorBootstrap()
                    json = try await innertube.player(videoID: videoID, client: client, timeout: timeout)
                    if let url = InnertubePlayerParser.audioURL(from: json) {
                        return url
                    }
                }
            } catch {
                continue
            }
        }
        throw InnertubeError.streamNotFound(videoID)
    }

    private func resolveViaPiped(videoID: String, timeout: TimeInterval = 20) async throws -> URL {
        let instances = [
            "https://api.piped.private.coffee/streams/\(videoID)",
            "https://pipedapi.kavin.rocks/streams/\(videoID)",
            "https://pipedapi.adminforge.de/streams/\(videoID)"
        ]
        for instance in instances {
            guard let url = URL(string: instance) else { continue }
            var req = URLRequest(url: url)
            req.timeoutInterval = timeout
            req.setValue("Muses-Erato/1.0", forHTTPHeaderField: "User-Agent")
            if let (data, resp) = try? await session.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let streamURL = InnertubePlayerParser.pipedAudioURL(from: json) {
                return streamURL
            }
        }
        throw InnertubeError.streamNotFound(videoID)
    }

    private func resolveViaInvidious(videoID: String, timeout: TimeInterval = 20) async throws -> URL {
        let instances = [
            "https://yewtu.be/api/v1/videos/\(videoID)",
            "https://inv.nadeko.net/api/v1/videos/\(videoID)"
        ]
        for instance in instances {
            guard let url = URL(string: instance) else { continue }
            var req = URLRequest(url: url)
            req.timeoutInterval = timeout
            req.setValue("Muses-Erato/1.0", forHTTPHeaderField: "User-Agent")
            guard let (data, resp) = try? await session.data(for: req),
                  let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let stream = InnertubePlayerParser.invidiousAudioURL(from: json) else {
                continue
            }
            return stream
        }
        throw InnertubeError.streamNotFound(videoID)
    }
}
