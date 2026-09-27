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
                .overlay {
                    Circle().stroke(BrandColors.glassRimGradient, lineWidth: 0.65)
                }
        }
        .buttonStyle(MusesPressStyle(scale: MusesMotion.pressScale))
        .frame(minWidth: AppleMusicSpacing.hitTarget, minHeight: AppleMusicSpacing.hitTarget)
        .contentShape(Rectangle())
        .help(help ?? accessibility)
        .accessibilityLabel(accessibility)
    }
}

#if canImport(UIKit)
import UIKit

/// Custom bar button that bypasses iOS 18 default circular toolbar platters.
public struct PlatterlessBarButton<Content: View>: UIViewRepresentable {
    private let action: () -> Void
    private let content: Content

    public init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }

    public func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear

        let hosting = UIHostingController(rootView: content)
        hosting.view.backgroundColor = .clear
        hosting.view.isUserInteractionEnabled = false

        button.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: button.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: button.trailingAnchor)
        ])

        button.addAction(UIAction { _ in
            action()
        }, for: .touchUpInside)

        return button
    }

    public func updateUIView(_ uiView: UIButton, context: Context) {}
}
#endif

