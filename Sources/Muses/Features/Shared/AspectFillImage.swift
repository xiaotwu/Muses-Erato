import SwiftUI
#if canImport(UIKit)
import UIKit

/// Renders a square, letterbox-stripped bitmap into a fixed slot.
struct AspectFillImage: View {
    let image: UIImage
    var width: CGFloat
    var height: CGFloat
    var sourceURL: URL? = nil

    private var prepared: UIImage {
        let stripped = YouTubeThumbnail.cropLetterboxIfNeeded(image, url: sourceURL)
        return YouTubeThumbnail.squareCenterCrop(stripped)
    }

    var body: some View {
        Image(uiImage: prepared)
            .resizable()
            // Prepared bitmap is already square — stretch to slot.
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
            .allowsHitTesting(false)
    }
}
#endif
