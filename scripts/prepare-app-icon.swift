#!/usr/bin/env swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Re-encode the existing 1024px artwork over its white background for Apple's
// App Icon format requirement. This is an explicit, local release preparation step.
guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: swift scripts/prepare-app-icon.swift path/to/icon.png")
}
let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      image.width == 1024, image.height == 1024,
      let space = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(data: nil, width: image.width, height: image.height,
                              bitsPerComponent: 8, bytesPerRow: image.width * 4,
                              space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("Expected a readable 1024 × 1024 icon")
}
let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
context.setFillColor(CGColor(gray: 1, alpha: 1))
context.fill(bounds)
context.interpolationQuality = .none
context.draw(image, in: bounds)
guard let opaqueImage = context.makeImage() else { fatalError("Could not create opaque image") }
let temporaryURL = sourceURL.appendingPathExtension("opaque.png")
defer { try? FileManager.default.removeItem(at: temporaryURL) }
guard let destination = CGImageDestinationCreateWithURL(temporaryURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Could not create PNG destination")
}
CGImageDestinationAddImage(destination, opaqueImage, nil)
guard CGImageDestinationFinalize(destination),
      let check = CGImageSourceCreateWithURL(temporaryURL as CFURL, nil),
      let decoded = CGImageSourceCreateImageAtIndex(check, 0, nil),
      [.none, .noneSkipFirst, .noneSkipLast].contains(decoded.alphaInfo) else {
    fatalError("PNG encoding retained an alpha channel")
}
try Data(contentsOf: temporaryURL).write(to: sourceURL, options: .atomic)
print("Prepared opaque RGB App Icon: \(sourceURL.lastPathComponent)")
