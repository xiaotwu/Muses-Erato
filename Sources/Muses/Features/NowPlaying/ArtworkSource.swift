import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Artwork source: remote YouTube/catalog image or placeholder.
/// Resolution only yields the identity; decoding is handled by `ArtworkView` + `ImageLoader`.
enum ArtworkSource: Equatable, Sendable {
    case remote(URL)
    case placeholder

    var identity: String {
        switch self {
        case .remote(let url): "remote:\(url.absoluteString)"
        case .placeholder: "placeholder"
        }
    }

    /// Resolve a track's remote metadata image, then its YouTube thumbnail.
    static func resolve(for track: TrackSnapshot?) -> ArtworkSource {
        guard let track else { return .placeholder }
        return resolve(remoteURL: track.artworkUrl, youTubeId: track.youTubeId)
    }

    static func resolve(for track: Track) -> ArtworkSource {
        resolve(for: TrackSnapshot(from: track))
    }

    static func resolve(remoteURL: String?, youTubeId: String? = nil) -> ArtworkSource {
        if let urlStr = remoteURL, let url = URL(string: urlStr) {
            return .remote(url)
        }
        if let vid = youTubeId, let url = YouTubeThumbnail.url(videoId: vid) {
            return .remote(url)
        }
        return .placeholder
    }

    /// Blocking decode for detached palette only. Never call from `body`.
    func loadPlatformImage() -> PlatformImage? {
        switch self {
        case .remote(let url):
            guard let data = try? Data(contentsOf: url),
                  let img = PlatformImage(data: data) else { return nil }
            return YouTubeThumbnail.cropLetterboxIfNeeded(img, url: url)
        case .placeholder:
            return nil
        }
    }
}

enum ArtworkPresentation: String, Equatable, Sendable {
    case fill
    case fitOnAmbient
}

/// Unified artwork rendering. Browsing defaults to square fill; selected
/// Hero/Home surfaces can opt into complete artwork over an ambient wash.
struct ArtworkView: View {
    let source: ArtworkSource
    var cornerRadius: CGFloat = 12
    var glyphSize: CGFloat = 80
    var clipCircle: Bool = false
    var targetSize: CGFloat = 200
    var targetHeight: CGFloat? = nil
    var presentation: ArtworkPresentation = .fill

    init(source: ArtworkSource,
         cornerRadius: CGFloat = 12,
         glyphSize: CGFloat = 80,
         clipCircle: Bool = false,
         targetSize: CGFloat = 200,
         targetHeight: CGFloat? = nil,
         presentation: ArtworkPresentation = .fill) {
        self.source = source
        self.cornerRadius = cornerRadius
        self.glyphSize = glyphSize
        self.clipCircle = clipCircle
        self.targetSize = targetSize
        self.targetHeight = targetHeight
        self.presentation = presentation
    }

    private var resolvedHeight: CGFloat { targetHeight ?? targetSize }

    var body: some View {
        let shape: AnyShape = clipCircle
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

        ZStack {
            // Opaque base so any layout miss never shows page-black "letterbox".
            shape.fill(BrandColors.surface)

            switch source {
            case .remote(let url):
                RemoteArtworkRender(
                    url: url,
                    presentation: presentation,
                    width: targetSize,
                    height: resolvedHeight
                )
            case .placeholder:
                placeholderGlyph
            }
        }
        .frame(width: targetSize, height: resolvedHeight)
        .clipShape(shape)
    }

    private var placeholderGlyph: some View {
        Image(systemName: "music.note")
            .font(.system(size: glyphSize))
            .foregroundStyle(BrandColors.textSecondary.opacity(0.5))
    }

}


private struct RemoteArtworkRender: View {
    let url: URL
    let presentation: ArtworkPresentation
    let width: CGFloat
    let height: CGFloat

    @State private var image: PlatformImage?
    @State private var identity: String?

    var body: some View {
        Group {
            if let image {
                switch presentation {
                case .fill:
                    #if canImport(UIKit)
                    AspectFillImage(image: image)
                        .frame(width: width, height: height)
                        .clipped()
                    #else
                    Color.clear
                        .frame(width: width, height: height)
                        .overlay {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFill()
                        }
                        .clipped()
                    #endif
                case .fitOnAmbient:
                    ResolvedArtworkImage(
                        image: {
                            #if canImport(UIKit)
                            Image(uiImage: image)
                            #else
                            Image(nsImage: image)
                            #endif
                        }(),
                        presentation: .fitOnAmbient,
                        width: width,
                        height: height
                    )
                }
            } else {
                Color.clear.frame(width: width, height: height)
            }
        }
        .task(id: url.absoluteString) {
            let loaded = await ImageLoader.shared.load(url).value
            if !Task.isCancelled {
                image = loaded
                identity = url.absoluteString
            }
        }
    }
}

private struct ResolvedArtworkImage: View {
    let image: Image
    let presentation: ArtworkPresentation
    let width: CGFloat
    let height: CGFloat

    @ViewBuilder
    var body: some View {
        switch presentation {
        case .fill:
            Color.clear
                .frame(width: width, height: height)
                .overlay {
                    image
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
        case .fitOnAmbient:
            ZStack {
                image
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(1.18)
                    .blur(radius: max(12, width * 0.075), opaque: true)
                    .saturation(1.12)
                    .brightness(-0.12)

                LinearGradient(
                    colors: [
                        BrandColors.background.opacity(0.08),
                        Color.clear,
                        BrandColors.background.opacity(0.16)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                image
                    .resizable()
                    .scaledToFit()
                    .saturation(0.96)
            }
            .frame(width: width, height: height)
            .clipped()
        }
    }
}
