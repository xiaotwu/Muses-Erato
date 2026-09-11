import Foundation
#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#else
import AppKit
public typealias PlatformImage = NSImage
#endif

/// YouTube thumbnail URLs and letterbox stripping.
public enum YouTubeThumbnail {
    /// Canonical stored URL (hqdefault). Display crops letterbox.
    public static func urlString(videoId: String) -> String {
        "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg"
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
            || path.hasSuffix("/default.jpg")
            || path.hasSuffix("/default.webp")
    }

    /// Crop 4:3 YouTube letterbox (45/360 = 12.5% each edge). 16:9 images pass through.
    public static func cropLetterboxIfNeeded(_ image: PlatformImage, url: URL? = nil) -> PlatformImage {
        if let url, !isLetterboxed(url) { return image }
        #if canImport(UIKit)
        guard let cg = image.cgImage else { return image }
        #else
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }
        #endif
        let width = CGFloat(cg.width)
        let height = CGFloat(cg.height)
        guard height > 0 else { return image }
        let aspect = width / height
        guard aspect >= 1.22 && aspect <= 1.48 else { return image }
        let bar = (height * 45.0 / 360.0).rounded(.down)
        let cropHeight = height - bar * 2
        guard bar > 0, cropHeight > 8 else { return image }
        let rect = CGRect(x: 0, y: bar, width: width, height: cropHeight)
        guard let cropped = cg.cropping(to: rect) else { return image }
        #if canImport(UIKit)
        return UIImage(cgImage: cropped)
        #else
        return NSImage(cgImage: cropped, size: NSSize(width: rect.width, height: rect.height))
        #endif
    }
}
