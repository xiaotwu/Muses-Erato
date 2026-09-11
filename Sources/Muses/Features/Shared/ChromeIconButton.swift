import SwiftUI

public struct ChromeIconButton: View {
    public let systemName: String
    public var help: String?
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
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
    }
}
