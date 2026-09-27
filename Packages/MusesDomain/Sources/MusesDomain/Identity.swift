import Foundation

public enum IdentityError: Error, Equatable, Sendable { case invalid(String) }

public protocol IDTag: Sendable {
    static var namespace: String { get }
    static func accepts(_ raw: String) -> Bool
}

public struct TypedID<Tag: IDTag>: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String
    public init(_ rawValue: String) throws {
        guard Tag.accepts(rawValue) else { throw IdentityError.invalid(Tag.namespace) }
        self.rawValue = rawValue
    }
    public var description: String { rawValue }
    public init(from decoder: Decoder) throws {
        try self.init(decoder.singleValueContainer().decode(String.self))
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

private func validOpaque(_ value: String) -> Bool {
    !value.isEmpty && value == value.trimmingCharacters(in: .whitespacesAndNewlines) && value.count <= 256 && !value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
}

public enum VideoTag: IDTag {
    public static let namespace = "youtube.video"
    public static func accepts(_ raw: String) -> Bool {
        raw.count == 11 && raw.utf8.allSatisfy { ($0 >= 65 && $0 <= 90) || ($0 >= 97 && $0 <= 122) || ($0 >= 48 && $0 <= 57) || $0 == 45 || $0 == 95 }
    }
}
public enum ChannelTag: IDTag { public static let namespace = "youtube.channel"; public static func accepts(_ raw: String) -> Bool { raw.hasPrefix("UC") && raw.count == 24 && validOpaque(raw) } }
public enum TrackTag: IDTag { public static let namespace = "track"; public static func accepts(_ raw: String) -> Bool { UUID(uuidString: raw) != nil } }
public enum ArtistTag: IDTag { public static let namespace = "artist"; public static func accepts(_ raw: String) -> Bool { validOpaque(raw) } }
public enum ReleaseTag: IDTag { public static let namespace = "release"; public static func accepts(_ raw: String) -> Bool { validOpaque(raw) } }
public enum PlaylistTag: IDTag { public static let namespace = "playlist"; public static func accepts(_ raw: String) -> Bool { validOpaque(raw) } }
public enum CatalogTag: IDTag { public static let namespace = "catalog"; public static func accepts(_ raw: String) -> Bool { validOpaque(raw) } }
public enum ProviderTag: IDTag { public static let namespace = "provider"; public static func accepts(_ raw: String) -> Bool { validOpaque(raw) } }
public enum ResourceTag: IDTag { public static let namespace = "resource"; public static func accepts(_ raw: String) -> Bool { validOpaque(raw) } }
public enum BookmarkedFileTag: IDTag { public static let namespace = "bookmarkedFile"; public static func accepts(_ raw: String) -> Bool { validOpaque(raw) } }
public typealias VideoID = TypedID<VideoTag>
public typealias ChannelID = TypedID<ChannelTag>
public typealias TrackID = TypedID<TrackTag>
public typealias ArtistID = TypedID<ArtistTag>
public typealias ReleaseID = TypedID<ReleaseTag>
public typealias PlaylistID = TypedID<PlaylistTag>
public typealias CatalogID = TypedID<CatalogTag>
public typealias ProviderID = TypedID<ProviderTag>
public typealias ResourceID = TypedID<ResourceTag>
public typealias BookmarkedFileID = TypedID<BookmarkedFileTag>

public struct Provenance: Codable, Hashable, Sendable {
    public let provider: ProviderID
    public let originalID: String
    public init(provider: ProviderID, originalID: String) throws {
        guard validOpaque(originalID) else { throw IdentityError.invalid("provenance.originalID") }
        self.provider = provider; self.originalID = originalID
    }
}
