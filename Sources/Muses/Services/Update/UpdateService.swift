import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// GitHub Releases update check. Opens the release page; does not auto-install.
@Observable
@MainActor
final class UpdateService {
    let repo: String
    private(set) var currentVersion: String
    private(set) var latestVersion: String?
    private(set) var releaseURL: URL?
    private(set) var isChecking = false
    private(set) var lastError: String?

    private let session: URLSession
    private let defaults: UserDefaults

    init(
        repo: String = "xiaotwu/Muses-Erato",
        session: URLSession = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.repo = repo
        self.session = session
        self.defaults = defaults
        self.currentVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
        latestVersion = defaults.string(forKey: PrefKey.latestKnownVersion)
    }

    var hasUpdate: Bool {
        guard let latest = latestVersion else { return false }
        return Self.semverCompare(latest, currentVersion) > 0
    }

    var secondsSinceLastCheck: Double? {
        guard let t = defaults.object(forKey: PrefKey.lastUpdateCheckAt) as? Date else { return nil }
        return Date().timeIntervalSince(t)
    }

    func checkForUpdates() async {
        guard !isChecking else { return }
        isChecking = true
        lastError = nil
        defer { isChecking = false }

        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            lastError = "Invalid repository URL"
            return
        }
        var req = URLRequest(url: url)
        req.setValue("Muses-Erato-UpdateChecker", forHTTPHeaderField: "User-Agent")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 15
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                lastError = "GitHub API returned \((resp as? HTTPURLResponse)?.statusCode ?? 0)"
                return
            }
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                lastError = "Failed to parse response"
                return
            }
            let tag = obj["tag_name"] as? String ?? ""
            let clean = tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag
            guard !clean.isEmpty else { lastError = "tag_name is empty"; return }
            latestVersion = clean
            releaseURL = (obj["html_url"] as? String).flatMap(URL.init(string:))
            defaults.set(clean, forKey: PrefKey.latestKnownVersion)
            defaults.set(Date(), forKey: PrefKey.lastUpdateCheckAt)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func checkIfDue(interval: TimeInterval = 86_400) async {
        let enabled = defaults.object(forKey: PrefKey.checkForUpdates) as? Bool ?? true
        guard enabled else { return }
        if let elapsed = secondsSinceLastCheck, elapsed < interval { return }
        await checkForUpdates()
    }

    func openReleasePage() {
        let target = releaseURL ?? URL(string: "https://github.com/\(repo)/releases")
        guard let target else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(target)
        #endif
    }

    nonisolated static func semverCompare(_ a: String, _ b: String) -> Int {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        let n = max(pa.count, pb.count)
        for i in 0..<n {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x < y { return -1 }
            if x > y { return 1 }
        }
        return 0
    }
}
