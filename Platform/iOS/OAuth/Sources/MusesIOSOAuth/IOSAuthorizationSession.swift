#if os(iOS)
import AuthenticationServices
import UIKit

@MainActor
public final class IOSAuthorizationSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    private weak var anchor: UIWindow?
    private var session: ASWebAuthenticationSession?
    public init(anchor: UIWindow) { self.anchor = anchor }
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { anchor ?? UIWindow() }

    public func authorize(_ attempt: OAuthAttempt) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: attempt.authorizationURL, callbackURLScheme: attempt.redirectURI.scheme) { callback, error in
                if let error { continuation.resume(throwing: error) }
                else if let callback { continuation.resume(returning: callback) }
                else { continuation.resume(throwing: OAuthFailure.invalidCallback) }
            }
            self.session = session
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            if !session.start() { self.session = nil; continuation.resume(throwing: OAuthFailure.invalidConfiguration) }
        }
    }
    public func cancel() { session?.cancel(); session = nil }
}
#endif
