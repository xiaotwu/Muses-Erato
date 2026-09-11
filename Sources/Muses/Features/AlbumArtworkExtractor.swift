import Foundation
import CoreGraphics
import SwiftUI
#if canImport(UIKit)
import UIKit
public typealias PlatformColor = UIColor
#else
import AppKit
public typealias PlatformColor = NSColor
#endif

public enum AlbumArtworkExtractor {
    public static func dominantColors(_ image: PlatformImage, count: Int = 3) -> [PlatformColor] {
        guard count > 0 else { return [] }
        #if canImport(UIKit)
        guard let cg = image.cgImage else { return [] }
        #else
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
        #endif

        let targetSize = 32
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: targetSize * targetSize * 4)
        guard let context = CGContext(
            data: &rawData,
            width: targetSize,
            height: targetSize,
            bitsPerComponent: 8,
            bytesPerRow: targetSize * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }

        context.draw(cg, in: CGRect(x: 0, y: 0, width: targetSize, height: targetSize))

        var pixels: [(r: Double, g: Double, b: Double)] = []
        pixels.reserveCapacity(targetSize * targetSize)
        for i in 0..<(targetSize * targetSize) {
            let offset = i * 4
            let a = Double(rawData[offset + 3]) / 255.0
            if a > 0.5 {
                let r = Double(rawData[offset]) / 255.0
                let g = Double(rawData[offset + 1]) / 255.0
                let b = Double(rawData[offset + 2]) / 255.0
                pixels.append((r, g, b))
            }
        }
        guard !pixels.isEmpty else { return [] }

        let k = min(count, pixels.count)
        let centers = kmeans(pixels: pixels, k: k, iterations: 10)

        let colors: [PlatformColor] = centers.map { c in
            #if canImport(UIKit)
            UIColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: 1.0)
            #else
            NSColor(srgbRed: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: 1.0)
            #endif
        }.sorted { a, b in
            saturation(a) > saturation(b)
        }

        return Array(colors.prefix(count))
    }

    private static func kmeans(pixels: [(r: Double, g: Double, b: Double)],
                               k: Int, iterations: Int) -> [(r: Double, g: Double, b: Double)] {
        var centers: [(r: Double, g: Double, b: Double)] = []
        let step = max(1, pixels.count / k)
        for i in 0..<k {
            centers.append(pixels[i * step % pixels.count])
        }

        for _ in 0..<iterations {
            var clusters: [[Int]] = Array(repeating: [], count: k)
            for (idx, px) in pixels.enumerated() {
                var bestCluster = 0
                var bestDist = Double.infinity
                for (ci, c) in centers.enumerated() {
                    let d = (px.r - c.r) * (px.r - c.r)
                            + (px.g - c.g) * (px.g - c.g)
                            + (px.b - c.b) * (px.b - c.b)
                    if d < bestDist {
                        bestDist = d
                        bestCluster = ci
                    }
                }
                clusters[bestCluster].append(idx)
            }

            for (ci, cluster) in clusters.enumerated() {
                guard !cluster.isEmpty else { continue }
                var sumR: Double = 0, sumG: Double = 0, sumB: Double = 0
                for idx in cluster {
                    sumR += pixels[idx].r
                    sumG += pixels[idx].g
                    sumB += pixels[idx].b
                }
                let n = Double(cluster.count)
                centers[ci] = (sumR / n, sumG / n, sumB / n)
            }
        }

        return centers
    }

    private static func saturation(_ color: PlatformColor) -> CGFloat {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        #else
        color.usingColorSpace(.sRGB)?.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        #endif
        return s
    }
}
