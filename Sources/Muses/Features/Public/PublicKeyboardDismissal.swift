import SwiftUI
import UIKit

/// Dismiss text input on an outside tap without consuming the tapped control's action.
struct PublicKeyboardDismissal: UIViewRepresentable {
    var onDismiss: () -> Void = {}
    func makeUIView(context: Context) -> KeyboardDismissalView {
        let view = KeyboardDismissalView()
        view.onDismiss = onDismiss
        return view
    }
    func updateUIView(_ uiView: KeyboardDismissalView, context: Context) { uiView.onDismiss = onDismiss }
    static func dismantleUIView(_ uiView: KeyboardDismissalView, coordinator: ()) { uiView.detach() }
}

final class KeyboardDismissalView: UIView, UIGestureRecognizerDelegate {
    var onDismiss: () -> Void = {}
    private weak var observedWindow: UIWindow?
    private lazy var outsideTap: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(dismissInput))
        gesture.cancelsTouchesInView = false
        gesture.delegate = self
        return gesture
    }()

    override func didMoveToWindow() {
        super.didMoveToWindow()
        detach()
        guard let window else { return }
        observedWindow = window
        window.addGestureRecognizer(outsideTap)
        isUserInteractionEnabled = false
    }

    func detach() {
        observedWindow?.removeGestureRecognizer(outsideTap)
        observedWindow = nil
    }

    @objc private func dismissInput() {
        observedWindow?.endEditing(true)
        onDismiss()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Ending editing can move an alert before its button receives touch-up.
        // Let system alerts and controls own their complete interaction.
        var responder: UIResponder? = touch.view
        while let current = responder {
            if current is UIAlertController { return false }
            responder = current.next
        }
        var touchedView = touch.view
        while let view = touchedView {
            if view is UIControl || view is UITextView { return false }
            touchedView = view.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
