import SwiftUI
#if canImport(UIKit)
import UIKit

/// Cover-fill that wins against Image's intrinsic aspect ratio in SwiftUI stacks.
struct AspectFillImage: View {
    let image: UIImage
    var width: CGFloat
    var height: CGFloat

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            // Critical: without this, landscape thumbs letterbox inside fixed frames.
            .layoutPriority(-1)
            .frame(width: width, height: height)
            .clipped()
            .allowsHitTesting(false)
    }
}
#endif
