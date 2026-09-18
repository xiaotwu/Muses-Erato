import Foundation

enum InnertubePlayerParser {
    static func audioURL(from playerJSON: [String: Any]) -> URL? {
        guard let streaming = playerJSON["streamingData"] as? [String: Any] else { return nil }
        let adaptive = streaming["adaptiveFormats"] as? [[String: Any]] ?? []
        let progressive = streaming["formats"] as? [[String: Any]] ?? []
        let combined = adaptive + progressive
        let audio = combined.filter { format in
            let mime = (format["mimeType"] as? String) ?? ""
            return mime.contains("audio/") || format["audioQuality"] != nil
        }
        let ranked = (audio.isEmpty ? combined : audio).sorted {
            numericBitrate($0) > numericBitrate($1)
        }
        for format in ranked {
            if let url = url(fromFormat: format) { return url }
        }
        return nil
    }

    static func url(fromFormat format: [String: Any]) -> URL? {
        if let raw = format["url"] as? String, !raw.isEmpty, let url = URL(string: raw) {
            return url
        }
        let cipher = (format["signatureCipher"] as? String) ?? (format["cipher"] as? String)
        guard let cipher, !cipher.isEmpty else { return nil }
        return url(fromCipher: cipher)
    }

    static func url(fromCipher cipher: String) -> URL? {
        var items: [String: String] = [:]
        for pair in cipher.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            items[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
        }
        // Unusable cipher: no plain url (and therefore nothing to sign) → nil.
        guard var urlString = items["url"], !urlString.isEmpty else { return nil }
        if urlString.contains("sig=") || urlString.contains("signature=") {
            return URL(string: urlString)
        }
        // Signature required but missing/empty → unusable.
        guard let signature = items["s"], !signature.isEmpty else {
            // Plain url embedded in cipher without a signature payload is acceptable.
            return URL(string: urlString)
        }
        let parameter = items["sp"] ?? "signature"
        let separator = urlString.contains("?") ? "&" : "?"
        let encoded = signature.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? signature
        urlString += "\(separator)\(parameter)=\(encoded)"
        return URL(string: urlString)
    }

    /// Selects the best Piped `audioStreams` entry. Empty / missing arrays are not success.
    static func pipedAudioURL(from json: [String: Any]) -> URL? {
        guard let audioStreams = json["audioStreams"] as? [[String: Any]], !audioStreams.isEmpty else {
            return nil
        }
        let sorted = audioStreams.sorted {
            (($0["bitrate"] as? Int) ?? 0) > (($1["bitrate"] as? Int) ?? 0)
        }
        guard let best = sorted.first,
              let streamUrlStr = best["url"] as? String, !streamUrlStr.isEmpty,
              let streamURL = URL(string: streamUrlStr) else {
            return nil
        }
        return streamURL
    }

    static func invidiousAudioURL(from json: [String: Any]) -> URL? {
        let adaptive = json["adaptiveFormats"] as? [[String: Any]] ?? []
        let progressive = json["formatStreams"] as? [[String: Any]] ?? []
        let combined = adaptive + progressive
        let audio = combined.filter { format in
            let type = (format["type"] as? String) ?? ""
            return type.contains("audio/")
        }
        let ranked = (audio.isEmpty ? combined : audio).sorted {
            numericBitrate($0) > numericBitrate($1)
        }
        for format in ranked {
            if let raw = format["url"] as? String, let url = URL(string: raw) {
                return url
            }
        }
        return nil
    }

    private static func numericBitrate(_ format: [String: Any]) -> Int {
        (format["bitrate"] as? Int)
            ?? (format["bitrate"] as? String).flatMap(Int.init)
            ?? 0
    }
}

/// Compatibility alias for existing tests and call sites.
typealias YouTubeStreamParser = InnertubePlayerParser
