import SwiftUI
#if canImport(UIKit)
import UIKit

/// Fills `bounds` with aspect-fill every layout pass (avoids SwiftUI intrinsic-size letterboxing).
struct AspectFillImage: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> FillImageView {
        let view = FillImageView()
        view.setImage(image)
        return view
    }

    func updateUIView(_ uiView: FillImageView, context: Context) {
        uiView.setImage(image)
    }
}

final class FillImageView: UIView {
    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        isUserInteractionEnabled = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        addSubview(imageView)
    }

    required init?(coder: NSCoder) { nil }

    func setImage(_ image: UIImage) {
        imageView.image = image
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        imageView.contentMode = .scaleAspectFill
    }

    override var intrinsicContentSize: CGSize {
        // Don't fight SwiftUI's proposed frame.
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
}
#endif
