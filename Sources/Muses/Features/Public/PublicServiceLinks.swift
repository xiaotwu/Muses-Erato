import SwiftUI

/// Public support and provider controls remain accessible without exposing account data.
struct PublicServiceLinks: View {
    var body: some View {
        HStack(spacing: 16) {
            serviceLink("GitHub support", symbol: "questionmark.circle", url: "https://github.com/xiaotwu/Muses-Erato/issues")
            serviceLink("YouTube terms", symbol: "doc.text", url: "https://www.youtube.com/t/terms")
            serviceLink("Google privacy policy", symbol: "hand.raised", url: "https://policies.google.com/privacy")
            serviceLink("Google account permissions", symbol: "lock.rotation", url: "https://security.google.com/settings/security/permissions")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private func serviceLink(_ title: String, symbol: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            Label(title, systemImage: symbol).frame(minWidth: 24, minHeight: 24)
        }
        .accessibilityHint("Opens in your browser")
    }
}
