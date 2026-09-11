import SwiftUI

private struct BrowseGradientKey: EnvironmentKey {
    static let defaultValue: [Color] = [Color.black, BrandColors.background]
}

public extension EnvironmentValues {
    var browseGradient: [Color] {
        get { self[BrowseGradientKey.self] }
        set { self[BrowseGradientKey.self] = newValue }
    }
}

public struct BrowseBackground: View {
    @Environment(\.browseGradient) private var colors

    public init() {}

    public var body: some View {
        BrandColors.background.ignoresSafeArea()
    }
}
