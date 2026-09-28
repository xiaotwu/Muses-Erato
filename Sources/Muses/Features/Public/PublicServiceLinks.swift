import SwiftUI

/// Public support and provider controls remain accessible without exposing account data.
struct PublicServiceLinks: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { links }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) { links }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    @ViewBuilder private var links: some View {
        serviceLink("GitHub support", symbol: "questionmark.circle", url: "https://github.com/xiaotwu/Muses-Erato/issues")
        serviceLink("YouTube terms", symbol: "doc.text", url: "https://www.youtube.com/t/terms")
        serviceLink("Google privacy policy", symbol: "hand.raised", url: "https://policies.google.com/privacy")
        serviceLink("Google account permissions", symbol: "lock.rotation", url: "https://security.google.com/settings/security/permissions")
    }

    private func serviceLink(_ title: String, symbol: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            PublicIconActionLabel(title: title, symbol: symbol)
        }
        .accessibilityHint("Opens in your browser")
    }
}

/// Keep the touch target inside the control label, including borderless list actions.
struct PublicIconActionLabel: View {
    let title: String
    let symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .labelStyle(.iconOnly)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(title)
    }
}
