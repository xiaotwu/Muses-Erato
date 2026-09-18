import SwiftUI

/// Light press scale for chrome controls (~0.97), springy and Reduce Motion–aware.
struct MusesPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.72),
                value: configuration.isPressed
            )
    }
}

/// Secondary / chrome controls → system `.glass` (capsule) on iOS 26+, else `.bordered`.
private struct MusesControlsModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    @ViewBuilder
    func body(content: Content) -> some View {
        let opaque = reduceTransparency || contrast == .increased
        if #available(iOS 26.0, *), !opaque {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .transaction { if reduceMotion { $0.animation = nil } }
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

/// Primary / destructive actions → `.glassProminent` / `.glass` on iOS 26+, else borderedProminent / bordered.
private struct MusesActionModifier: ViewModifier {
    var prominent: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    @ViewBuilder
    func body(content: Content) -> some View {
        let opaque = reduceTransparency || contrast == .increased
        if #available(iOS 26.0, *), !opaque {
            if prominent {
                content
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                    .tint(BrandColors.accent)
            } else {
                content.buttonStyle(.glass).buttonBorderShape(.capsule)
            }
        } else if prominent {
            content.buttonStyle(.borderedProminent).tint(BrandColors.accent)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

extension View {
    /// Secondary controls (toolbar, chrome, cancel). Prefer over `.bordered` / `.plain` for chrome.
    func musesControls() -> some View { modifier(MusesControlsModifier()) }

    /// Primary / emphasis actions. Prefer over `.borderedProminent`.
    func musesAction(prominent: Bool = true) -> some View {
        modifier(MusesActionModifier(prominent: prominent))
    }
}

/// Compact, accessible choice group with one moving glass selection (Settings / filters).
struct SettingsGlassChoice: View {
    struct Option: Identifiable {
        let id: String
        let title: String
        let symbol: String
    }

    let title: String
    @Binding var selection: String
    let options: [Option]
    @Namespace private var glassSelection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        MusesGlassGroup(spacing: 8) { choices }
    }

    private var choices: some View {
        HStack(spacing: 8) {
            ForEach(options) { option in
                Button {
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
                        selection = option.id
                    }
                } label: {
                    choiceLabel(option)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option.id ? .isSelected : [])
            }
        }
        .padding(6)
        .background(.primary.opacity(0.045), in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private func choiceLabel(_ option: Option) -> some View {
        let label = Label(option.title, systemImage: option.symbol)
            .font(.body.weight(selection == option.id ? .semibold : .regular))
            .foregroundStyle(BrandColors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: AppleMusicSpacing.hitTarget)
            .padding(.horizontal, 12)
            .contentShape(Capsule())

        if selection == option.id {
            if #available(iOS 26.0, *), !reduceTransparency, contrast != .increased {
                label
                    .glassEffect(.regular.interactive(!reduceMotion), in: Capsule())
                    .glassEffectID("selection", in: glassSelection)
            } else {
                label
                    .background(BrandColors.accent.opacity(0.15), in: Capsule())
                    .overlay(Capsule().strokeBorder(.primary.opacity(0.5), lineWidth: 1))
            }
        } else {
            label
        }
    }
}
