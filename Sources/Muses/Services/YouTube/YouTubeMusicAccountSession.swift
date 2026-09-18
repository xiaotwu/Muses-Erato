import Foundation
import Observation

/// OAuth-oriented session for YouTube Music Innertube Home.
///
/// Does **not** use WebHome cookies or the macOS helper. Anonymous browse works
/// without sign-in; when Google OAuth is connected, bearer tokens are applied.
@MainActor
@Observable
final class YouTubeMusicAccountSession {
    private let oauth: GoogleOAuthSession
    private let innertube: InnertubeClient

    private(set) var isSignedIn: Bool = false
    private(set) var lastError: String?

    init(oauth: GoogleOAuthSession, innertube: InnertubeClient) {
        self.oauth = oauth
        self.innertube = innertube
        self.isSignedIn = oauth.isConnected
    }

    /// Refresh Innertube auth from the shared Google OAuth session.
    func syncAuthentication() async {
        isSignedIn = oauth.isConnected
        guard oauth.isConnected else {
            innertube.updateAuthentication(.anonymous)
            return
        }
        do {
            let token = try await oauth.validAccessToken()
            innertube.updateAuthentication(.oauth(accessToken: token))
            lastError = nil
        } catch {
            innertube.updateAuthentication(.anonymous)
            lastError = error.localizedDescription
            isSignedIn = false
        }
    }
}
