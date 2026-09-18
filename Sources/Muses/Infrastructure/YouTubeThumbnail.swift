import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#else
import AppKit
public typealias PlatformImage = NSImage
#endif

/// YouTube thumbnail URLs and letterbox stripping.
public enum YouTubeThumbnail {
    public static func urlString(videoId: String) -> String {
        "https://i.ytimg.com/vi/\(videoId)/hq720.jpg"
    }

    public static func url(videoId: String) -> URL? {
        URL(string: urlString(videoId: videoId))
    }

    public static func isLetterboxed(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(), host.contains("ytimg.com") else {
            return false
        }
        let path = url.path.lowercased()
        return path.contains("hqdefault")
            || path.contains("sddefault")
            || path.contains("mqdefault")
            || path.contains("/0.jpg")
            || path.contains("/1.jpg")
            || path.contains("/2.jpg")
            || path.contains("/3.jpg")
            || path.hasSuffix("/default.jpg")
            || path.hasSuffix("/default.webp")
            || path.contains("/default.")
    }

    /// Strip baked letterbox bars so square fill can width-cover and crop the sides.
    public static func cropLetterboxIfNeeded(_ image: PlatformImage, url: URL? = nil) -> PlatformImage {
        var result = cropFourByThreeLetterbox(image)
        result = cropDetectedLetterboxBars(result)
        return result
    }

    private static func cropFourByThreeLetterbox(_ image: PlatformImage) -> PlatformImage {
        guard let cg = cgImage(from: image) else { return image }
        let width = CGFloat(cg.width)
        let height = CGFloat(cg.height)
        guard height > 0 else { return image }
        let aspect = width / height
        guard aspect >= 1.22 && aspect <= 1.48 else { return image }
        let bar = (height * 45.0 / 360.0).rounded(.down)
        let cropHeight = height - bar * 2
        guard bar > 0, cropHeight > 8 else { return image }
        return cropped(image, cg: cg, rect: CGRect(x: 0, y: bar, width: width, height: cropHeight)) ?? image
    }

    private static func cropDetectedLetterboxBars(_ image: PlatformImage) -> PlatformImage {
        guard let rgba = rgbaBytes(from: image) else { return image }
        let width = rgba.width
        let height = rgba.height
        let ptr = rgba.bytes
        guard width > 16, height > 16 else { return image }

        func rowIsBar(_ y: Int) -> Bool {
            var dark = 0
            let samples = min(48, width)
            let step = max(1, width / samples)
            var x = 0
            var count = 0
            while x < width && count < samples {
                let i = (y * width + x) * 4
                let r = Int(ptr[i])
                let g = Int(ptr[i + 1])
                let b = Int(ptr[i + 2])
                // Loose near-black (covers compressed navy/gray bars).
                if r <= 28 && g <= 28 && b <= 28 { dark += 1 }
                x += step
                count += 1
            }
            return dark * 100 >= samples * 78
        }

        var top = 0
        while top < height / 3 && rowIsBar(top) { top += 1 }
        var bottom = 0
        while bottom < height / 3 && rowIsBar(height - 1 - bottom) { bottom += 1 }

        let minBar = max(3, height / 50)
        guard top >= minBar || bottom >= minBar else { return image }
        if top < 2 { top = 0 }
        if bottom < 2 { bottom = 0 }
        let cropHeight = height - top - bottom
        guard cropHeight > height / 3, let cg = cgImage(from: image) else { return image }
        return cropped(
            image,
            cg: cg,
            rect: CGRect(x: 0, y: top, width: width, height: cropHeight)
        ) ?? image
    }

    private struct RGBABuffer {
        let width: Int
        let height: Int
        let bytes: [UInt8]
    }

    private static func rgbaBytes(from image: PlatformImage) -> RGBABuffer? {
        guard let cg = cgImage(from: image) else { return nil }
        let width = cg.width
        let height = cg.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let ctx = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        return RGBABuffer(width: width, height: height, bytes: bytes)
    }

    private static func cgImage(from image: PlatformImage) -> CGImage? {
        #if canImport(UIKit)
        return image.cgImage
        #else
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #endif
    }

    private static func cropped(_ image: PlatformImage, cg: CGImage, rect: CGRect) -> PlatformImage? {
        guard let cropped = cg.cropping(to: rect) else { return nil }
        #if canImport(UIKit)
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
        #else
        return NSImage(cgImage: cropped, size: NSSize(width: rect.width, height: rect.height))
        #endif
    }
}
