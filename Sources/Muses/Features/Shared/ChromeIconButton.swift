import SwiftUI

/// Round chrome control: glass capsule/circle, ≥44pt hit, light press spring.
public struct ChromeIconButton: View {
    public let systemName: String
    public var help: String? = nil
    public var accessibility: String
    public var action: () -> Void

    public init(systemName: String, help: String? = nil, accessibility: String, action: @escaping () -> Void) {
        self.systemName = systemName
        self.help = help
        self.accessibility = accessibility
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(BrandColors.textPrimary)
                .frame(width: 36, height: 36)
                .musesGlass(in: Circle(), role: .compactControl)
        }
        .buttonStyle(MusesPressStyle(scale: MusesMotion.pressScale))
        .frame(minWidth: AppleMusicSpacing.hitTarget, minHeight: AppleMusicSpacing.hitTarget)
        .contentShape(Rectangle())
        .help(help ?? accessibility)
        .accessibilityLabel(accessibility)
    }
}
