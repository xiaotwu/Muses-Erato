import Foundation
import CryptoKit
import Security
import MusesNetworking
import MusesCatalog
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum OAuthFailure: Error, Sendable, Equatable { case invalidConfiguration, invalidCallback, stateMismatch, denied, invalidToken, storage, revoked }

public struct OAuthConfiguration: Sendable {
    public let clientID: String
    public let redirectURI: URL
    public init(clientID: String, redirectURI: URL) throws {
        guard clientID.hasSuffix(".apps.googleusercontent.com"),
              let scheme = redirectURI.scheme,
              scheme.contains("."),
              scheme != "http", scheme != "https",
              redirectURI.host == nil else { throw OAuthFailure.invalidConfiguration }
        self.clientID = clientID; self.redirectURI = redirectURI
    }
}

public struct OAuthAttempt: Sendable {
    public let authorizationURL: URL
    public let verifier: String
    public let state: String
    public let redirectURI: URL
    public init(configuration: OAuthConfiguration, scope: String = "https://www.googleapis.com/auth/youtube.readonly") throws {
        guard scope == "https://www.googleapis.com/auth/youtube.readonly" else { throw OAuthFailure.invalidConfiguration }
        verifier = Self.randomURLSafe(32)
        state = Self.randomURLSafe(32)
        redirectURI = configuration.redirectURI
        let digest = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Data(digest).base64URLEncoded()
        var parts = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        parts.queryItems = [
            .init(name: "client_id", value: configuration.clientID),
            .init(name: "redirect_uri", value: redirectURI.absoluteString),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: scope),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            .init(name: "access_type", value: "offline")
        ]
        guard let url = parts.url else { throw OAuthFailure.invalidConfiguration }
        authorizationURL = url
    }
    public func code(from callback: URL) throws -> String {
        guard callback.scheme == redirectURI.scheme,
              callback.host == redirectURI.host,
              callback.path == redirectURI.path,
              let parts = URLComponents(url: callback, resolvingAgainstBaseURL: false) else { throw OAuthFailure.invalidCallback }
        let values = parts.queryItems ?? []
        guard values.filter({ $0.name == "state" }).count == 1,
              values.first(where: { $0.name == "state" })?.value == state else { throw OAuthFailure.stateMismatch }
        if values.contains(where: { $0.name == "error" }) { throw OAuthFailure.denied }
        guard values.filter({ $0.name == "code" }).count == 1,
              let code = values.first(where: { $0.name == "code" })?.value, !code.isEmpty else { throw OAuthFailure.invalidCallback }
        return code
    }
    private static func randomURLSafe(_ bytes: Int) -> String {
        var data = [UInt8](repeating: 0, count: bytes)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes, &data)
        precondition(result == errSecSuccess)
        return Data(data).base64URLEncoded()
    }
}

private extension Data {
    func base64URLEncoded() -> String { base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
}

public struct OAuthTokens: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: Date
    public init(accessToken: String, refreshToken: String?, expiresAt: Date) {
        self.accessToken = accessToken; self.refreshToken = refreshToken; self.expiresAt = expiresAt
    }
}

public protocol OAuthTokenStore: Sendable {
    func load() throws -> OAuthTokens?
    func save(_ tokens: OAuthTokens) throws
    func delete() throws
}

public struct KeychainOAuthTokenStore: OAuthTokenStore {
    private let service: String
    private let account: String
    public init(service: String, account: String = "youtube") { self.service = service; self.account = account }
    private var key: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account] }
    public func load() throws -> OAuthTokens? {
        var query = key
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = value as? Data,
              let tokens = try? JSONDecoder().decode(OAuthTokens.self, from: data) else { throw OAuthFailure.storage }
        return tokens
    }
    public func save(_ tokens: OAuthTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        let updated = SecItemUpdate(key as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updated == errSecSuccess { return }
        guard updated == errSecItemNotFound else { throw OAuthFailure.storage }
        var attributes = key
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess else { throw OAuthFailure.storage }
    }
    public func delete() throws {
        let status = SecItemDelete(key as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw OAuthFailure.storage }
    }
}

public protocol PrivateAccountData: Sendable { func deletePrivateData() async throws }

public actor OAuthClient: CatalogCredential {
    private let configuration: OAuthConfiguration
    private let transport: any HTTPTransport
    private let store: any OAuthTokenStore
    private let privateData: any PrivateAccountData
    public init(configuration: OAuthConfiguration, transport: any HTTPTransport = URLSessionTransport(), store: any OAuthTokenStore, privateData: any PrivateAccountData) {
        self.configuration = configuration; self.transport = transport; self.store = store; self.privateData = privateData
    }
    public func complete(_ attempt: OAuthAttempt, callback: URL) async throws {
        guard attempt.redirectURI == configuration.redirectURI else { throw OAuthFailure.invalidConfiguration }
        let code = try attempt.code(from: callback)
        let response = try await tokenRequest(["code":code, "client_id":configuration.clientID, "redirect_uri":configuration.redirectURI.absoluteString, "grant_type":"authorization_code", "code_verifier":attempt.verifier])
        guard let access = response.access_token else { throw OAuthFailure.invalidToken }
        if try store.load() != nil { try await privateData.deletePrivateData() }
        try store.save(OAuthTokens(accessToken: access, refreshToken: response.refresh_token, expiresAt: Date().addingTimeInterval(TimeInterval(response.expires_in ?? 3600))))
    }
    public func accessToken() async throws -> String {
        guard let saved = try store.load() else { throw OAuthFailure.revoked }
        if saved.expiresAt > Date().addingTimeInterval(60) { return saved.accessToken }
        guard let refresh = saved.refreshToken else { throw OAuthFailure.revoked }
        let response: TokenResponse
        do { response = try await tokenRequest(["refresh_token":refresh, "client_id":configuration.clientID, "grant_type":"refresh_token"]) }
        catch OAuthFailure.revoked {
            // A locked/failing token store must not skip private-cache cleanup.
            try await deleteLocalAccount()
            throw OAuthFailure.revoked
        }
        guard let access = response.access_token else { throw OAuthFailure.invalidToken }
        try store.save(OAuthTokens(accessToken: access, refreshToken: response.refresh_token ?? refresh, expiresAt: Date().addingTimeInterval(TimeInterval(response.expires_in ?? 3600))))
        return access
    }
    public func revokeAndDelete() async throws {
        let tokens: OAuthTokens?
        var storageFailed = false
        do { tokens = try store.load() }
        catch { tokens = nil; storageFailed = true }
        var revokeError: Error?
        if let token = tokens?.refreshToken ?? tokens?.accessToken {
            var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/revoke")!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = form(["token": token])
            do {
                let response = try await transport.send(request)
                if response.status != 200 { revokeError = APIError.classify(response) ?? .invalidResponse }
            } catch { revokeError = error }
        }
        do { try store.delete() } catch { storageFailed = true }
        do { try await privateData.deletePrivateData() } catch { storageFailed = true }
        if storageFailed { throw OAuthFailure.storage }
        if let revokeError { throw revokeError }
    }
    public func deleteLocalAccount() async throws {
        var storageFailed = false
        do { try store.delete() } catch { storageFailed = true }
        do { try await privateData.deletePrivateData() } catch { storageFailed = true }
        if storageFailed { throw OAuthFailure.storage }
    }
    private func tokenRequest(_ values: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = form(values)
        let response = try await transport.send(request)
        if response.status == 400,
           let error = try? JSONDecoder().decode(TokenFailure.self, from: response.body),
           error.error == "invalid_grant" { throw OAuthFailure.revoked }
        if let error = APIError.classify(response) { throw error }
        guard let decoded = try? JSONDecoder().decode(TokenResponse.self, from: response.body) else { throw OAuthFailure.invalidToken }
        return decoded
    }
}

private struct TokenResponse: Decodable { let access_token: String?; let refresh_token: String?; let expires_in: Int? }
private struct TokenFailure: Decodable { let error: String }
private func form(_ values: [String: String]) -> Data {
    var parts = URLComponents(); parts.queryItems = values.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
    return Data((parts.percentEncodedQuery ?? "").utf8)
}
