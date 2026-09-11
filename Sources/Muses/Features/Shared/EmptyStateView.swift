import SwiftUI

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
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(BrandColors.accent)
                .padding()
                .background(Circle().fill(BrandColors.accent.opacity(0.12)))
            
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(BrandColors.textPrimary)
            
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(BrandColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
