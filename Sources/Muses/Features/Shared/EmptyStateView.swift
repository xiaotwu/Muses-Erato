import SwiftUI

/// Soft glass empty-state card that sits on the ambient wash instead of a dead void.
public struct EmptyStateView: View {
    public let icon: String
    public let title: String
    public var subtitle: String?

    public init(icon: String, title: String, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(BrandColors.accent)
                .padding(18)
                .background(Circle().fill(BrandColors.accent.opacity(0.14)))

            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(BrandColors.textPrimary)
                .multilineTextAlignment(.center)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(BrandColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.vertical, 36)
        .musesGlass(cornerRadius: 24, role: .modalDeck)
        .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
        .padding(.vertical, 24)
    }
}
