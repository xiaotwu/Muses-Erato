import Security
import Foundation

/// Explicit user deletion only. No inherited OAuth/network code is linked or executed.
enum PublicCredentialDeletion {
    static func deleteAppCredentials() throws {
        for service in ["muses.youtube.oauth", "com.xiaotwu.muses.erato.youtube"] {
            let query = [kSecClass as String: kSecClassGenericPassword,
                         kSecAttrService as String: service] as [String: Any]
            let result = SecItemDelete(query as CFDictionary)
            guard result == errSecSuccess || result == errSecItemNotFound else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(result))
            }
        }
    }
}
