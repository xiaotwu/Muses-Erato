import Foundation

public struct LegacySettingsSnapshot: Sendable {
    public let values: [LegacySetting]
    public let inspectedKeys: Set<String>

    /// Read the app's explicit persistent domain. Registered defaults are not user choices.
    /// Each value is wrapped in a binary property list so Date, Data, and NSNumber types survive.
    public static func read(defaults: UserDefaults, domainName: String) throws -> Self {
        let domain = defaults.persistentDomain(forName: domainName) ?? [:]
        let keys = domain.keys.filter { $0.hasPrefix("muses.") }.sorted()
        let values = try keys.map { key -> LegacySetting in
            guard let value = domain[key] else {
                throw PersistenceError.unsupportedLegacyRecord("setting.\(key)")
            }
            let payload = try PropertyListSerialization.data(
                fromPropertyList: ["value": value], format: .binary, options: 0)
            return LegacySetting(key: key, value: payload)
        }
        return Self(values: values,
                    inspectedKeys: LegacyCompleteBundle.knownSettingKeys.union(keys))
    }
}
