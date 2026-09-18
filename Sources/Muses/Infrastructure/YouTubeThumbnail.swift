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
    /// Stable fetch target. Many videos 404 on hq720; hqdefault is reliable and letterbox-cropped.
    public static func urlString(videoId: String) -> String {
        "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg"
    }

    public static func url(videoId: String) -> URL? {
        URL(string: urlString(videoId: videoId))
    }

    public static func videoId(from url: URL) -> String? {
        let parts = url.path.split(separator: "/").map(String.init)
        guard let vi = parts.firstIndex(of: "vi"), vi + 1 < parts.count else { return nil }
        let id = parts[vi + 1]
        return id.isEmpty ? nil : id
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

    /// Candidate URLs for a video, best-first. Caller may fall back on 404.
    public static func candidateURLs(videoId: String) -> [URL] {
        [
            "https://i.ytimg.com/vi/\(videoId)/maxresdefault.jpg",
            "https://i.ytimg.com/vi/\(videoId)/hq720.jpg",
            "https://i.ytimg.com/vi/\(videoId)/sddefault.jpg",
            urlString(videoId: videoId)
        ].compactMap(URL.init(string:))
    }

    public static func cropLetterboxIfNeeded(_ image: PlatformImage, url: URL? = nil) -> PlatformImage {
        var result = cropFourByThreeLetterbox(image)
        result = cropRelativeLetterboxBars(result)
        return result
    }

    /// Center-crop to a square bitmap so square UI slots never letterbox/pillarbox.
    public static func squareCenterCrop(_ image: PlatformImage) -> PlatformImage {
        guard let cg = cgImage(from: image) else { return image }
        let width = CGFloat(cg.width)
        let height = CGFloat(cg.height)
        guard width > 0, height > 0 else { return image }
        let side = min(width, height)
        let rect = CGRect(
            x: ((width - side) / 2).rounded(.down),
            y: ((height - side) / 2).rounded(.down),
            width: side,
            height: side
        )
        return cropped(image, cg: cg, rect: rect) ?? image
    }


    private static func cropFourByThreeLetterbox(_ image: PlatformImage) -> PlatformImage {
        guard let cg = cgImage(from: image) else { return image }
        let width = CGFloat(cg.width)
        let height = CGFloat(cg.height)
        guard height > 0 else { return image }
        let aspect = width / height
        // hqdefault family ~4:3. Always strip the standard 45/360 bars.
        guard aspect >= 1.20 && aspect <= 1.50 else { return image }
        let bar = (height * 45.0 / 360.0).rounded(.down)
        let cropHeight = height - bar * 2
        guard bar >= 1, cropHeight > 8 else { return image }
        return cropped(image, cg: cg, rect: CGRect(x: 0, y: bar, width: width, height: cropHeight)) ?? image
    }

    private static func cropRelativeLetterboxBars(_ image: PlatformImage) -> PlatformImage {
        guard let rgba = rgbaBytes(from: image) else { return image }
        let width = rgba.width
        let height = rgba.height
        let ptr = rgba.bytes
        guard width > 16, height > 24 else { return image }

        func rowLuma(_ y: Int) -> Double {
            var sum = 0.0
            let samples = min(64, width)
            let step = max(1, width / samples)
            var x = 0
            var count = 0
            while x < width && count < samples {
                let i = (y * width + x) * 4
                sum += Double(ptr[i]) + Double(ptr[i + 1]) + Double(ptr[i + 2])
                x += step
                count += 1
            }
            return sum / Double(max(1, count))
        }

        let midStart = height * 2 / 5
        let midEnd = height * 3 / 5
        var midSum = 0.0
        var midCount = 0
        var y = midStart
        while y < midEnd {
            midSum += rowLuma(y)
            midCount += 1
            y += 2
        }
        let mid = midSum / Double(max(1, midCount))
        guard mid > 48 else { return image }
        let threshold = max(30.0, mid * 0.32)

        var top = 0
        while top < height / 3 && rowLuma(top) < threshold { top += 1 }
        var bottom = 0
        while bottom < height / 3 && rowLuma(height - 1 - bottom) < threshold { bottom += 1 }

        let minBar = max(3, height / 50)
        guard top >= minBar && bottom >= minBar else { return image }
        let cropHeight = height - top - bottom
        guard cropHeight > height / 3, let cg = cgImage(from: image) else { return image }
        return cropped(image, cg: cg, rect: CGRect(x: 0, y: top, width: width, height: cropHeight)) ?? image
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
