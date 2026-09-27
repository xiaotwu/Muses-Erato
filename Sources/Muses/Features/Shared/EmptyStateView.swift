import SwiftUI

/// Poetic empty-state view that sits gracefully on the content layer.
/// Complies with Apple HIG by using content surfaces instead of floating glass.
public struct EmptyStateView: View {
    public let icon: String
    public let title: String
    public var subtitle: String?
    public var showsEratoLogo: Bool
    public var actionTitle: String?
    public var action: (() -> Void)?

    public init(
        icon: String = "music.note",
        title: String,
        subtitle: String? = nil,
        showsEratoLogo: Bool = false,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.showsEratoLogo = showsEratoLogo
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: 16) {
            if showsEratoLogo {
                Image("EratoLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(BrandColors.laurelGold)
                    .padding(20)
                    .background(Circle().fill(BrandColors.laurelGold.opacity(0.12)))
            }

            Text(title)
                .font(EratoTypography.poeticTitle(size: 20, weight: .bold))
                .foregroundStyle(BrandColors.textPrimary)
                .multilineTextAlignment(.center)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(BrandColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandColors.laurelGold)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(BrandColors.laurelGold.opacity(0.14))
                                .overlay(
                                    Capsule()
                                        .stroke(BrandColors.laurelGold.opacity(0.32), lineWidth: 0.8)
                                )
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.vertical, 36)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BrandColors.surface.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
        .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
        .padding(.vertical, 24)
    }
}
