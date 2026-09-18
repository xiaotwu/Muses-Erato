import SwiftUI
#if canImport(UIKit)
import UIKit

/// UIKit-backed aspect-fill — SwiftUI `scaledToFill` was still letterboxing some remote thumbs.
struct AspectFillImage: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.image = image
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.image = image
        uiView.contentMode = .scaleAspectFill
        uiView.clipsToBounds = true
    }
}
#endif
