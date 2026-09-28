import SwiftUI

/// Public support and provider controls remain accessible without exposing account data.
struct PublicServiceLinks: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { links }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) { links }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .controlSize(.regular)
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

/// Prefer a single action row; keep complete labels when width or text size needs more space.
struct PublicActionGroup<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8, content: content)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16, content: content).fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .leading, spacing: 8, content: content)
                }
            }
        }
        .buttonStyle(.borderless)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PublicTextActionLabel: View {
    let title: String
    let symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .labelStyle(.titleAndIcon)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
            .accessibilityLabel(title)
    }
}
