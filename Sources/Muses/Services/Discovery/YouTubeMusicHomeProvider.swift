import Foundation

/// YouTube Music Home via Innertube `browse` (`FEmusic_home`).
/// Guest (anonymous) by default; OAuth bearer applied when `YouTubeMusicAccountSession` is signed in.
@MainActor
final class YouTubeMusicHomeProvider: HomeDiscoveryProvider {
    private let client: InnertubeClient
    private let accountSession: YouTubeMusicAccountSession?
    private let browseId: String
    private let maxSections: Int
    private let maxItems: Int

    init(
        client: InnertubeClient,
        accountSession: YouTubeMusicAccountSession? = nil,
        browseId: String = "FEmusic_home",
        maxSections: Int = 12,
        maxItems: Int = 12
    ) {
        self.client = client
        self.accountSession = accountSession
        self.browseId = browseId
        self.maxSections = maxSections
        self.maxItems = maxItems
    }

    func fetch(for input: HomeDiscoveryInput) async -> HomeFetchResult {
        await accountSession?.syncAuthentication()
        do {
            let json = try await client.browse(browseId: browseId, continuation: nil)
            let parsed = InnertubeHomeParser.sections(
                from: json,
                maxSections: maxSections,
                maxItems: maxItems
            )
            let source: HomeSource = (accountSession?.isSignedIn == true)
                ? .officialAccount
                : .publicDiscovery
            let sections: [HomeSection] = parsed.map { section in
                HomeSection(
                    id: section.id,
                    title: section.title,
                    subtitle: tr("From YouTube Music", "来自 YouTube Music"),
                    kind: .youTubeCarousel,
                    items: section.cards.map { .youTube($0) },
                    source: source,
                    accountChannelID: {
                        if case .account(let id) = input.scope { return id }
                        return nil
                    }()
                )
            }
            if sections.isEmpty {
                return .baseline(
                    scope: input.scope,
                    sections: [
                        HomeSection(
                            id: "ytm-home-empty",
                            title: tr("YouTube Music", "YouTube Music"),
                            subtitle: tr("No home shelves returned", "未返回首页内容"),
                            kind: .youTubeCarousel,
                            items: [],
                            status: .failed(tr("Empty home response", "首页响应为空")),
                            source: source
                        )
                    ],
                    failures: [
                        HomeFetchFailure(
                            layer: .baseline,
                            code: .baselineUnavailable,
                            message: "empty home response")
                    ]
                )
            }
            return .baseline(scope: input.scope, sections: sections)
        } catch {
            let message = (error as? InnertubeError)?.errorDescription ?? error.localizedDescription
            return .baseline(
                scope: input.scope,
                sections: [
                    HomeSection(
                        id: "ytm-home-failed",
                        title: tr("YouTube Music", "YouTube Music"),
                        subtitle: nil,
                        kind: .youTubeCarousel,
                        items: [],
                        status: .failed(message),
                        source: .publicDiscovery
                    )
                ],
                failures: [
                    HomeFetchFailure(
                        layer: .baseline,
                        code: .baselineUnavailable,
                        message: message)
                ]
            )
        }
    }
}
