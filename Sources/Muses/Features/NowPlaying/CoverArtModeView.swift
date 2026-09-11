import SwiftUI

/// Large cover mode: centered, static, large rounded-corner cover with subtle depth shadow.
struct CoverArtModeView: View {
    let source: ArtworkSource
    var size: CGFloat = 340

    init(source: ArtworkSource, size: CGFloat = 340) {
        self.source = source
        self.size = size
    }

    var body: some View {
        ArtworkView(source: source, cornerRadius: 24, glyphSize: min(80, size * 0.2), targetSize: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 30, x: 0, y: 15)
    }
}
