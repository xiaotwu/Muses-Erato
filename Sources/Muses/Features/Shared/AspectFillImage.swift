import SwiftUI
#if canImport(UIKit)
import UIKit

/// Center-crop fill that always respects the SwiftUI-proposed frame.
struct AspectFillImage: View {
    let image: UIImage

    var body: some View {
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .clipped()
        .allowsHitTesting(false)
    }
}
#endif
