import SwiftUI
#if canImport(UIKit)
import UIKit

/// UIKit aspect-fill that ignores the image's intrinsic size (avoids letterboxing in SwiftUI).
struct AspectFillImage: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.clipsToBounds = true
        container.isUserInteractionEnabled = false

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        // Critical: don't let UIImageView's intrinsic size fight the SwiftUI frame.
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        context.coordinator.imageView = imageView
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.imageView?.image = image
        context.coordinator.imageView?.contentMode = .scaleAspectFill
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var imageView: UIImageView?
    }
}
#endif
