import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@MainActor
public final class ImageLoader {
    public static let shared = ImageLoader()

    private let memory: NSCache<NSString, PlatformImage> = .init()
    private var inFlight: [String: Task<PlatformImage?, Never>] = [:]

    public init() {
        memory.countLimit = 256
        memory.totalCostLimit = 50 * 1024 * 1024
    }

    public func cachedImage(for url: URL) -> PlatformImage? {
        memory.object(forKey: (url.absoluteString + "#letterbox-v4") as NSString)
    }

    public func load(_ url: URL) -> Task<PlatformImage?, Never> {
        // Versioned so letterbox-strip algorithm upgrades invalidate stale cached thumbs.
        let keyStr = url.absoluteString + "#letterbox-v4"
        let key = keyStr as NSString
        if let hit = memory.object(forKey: key) {
            return Task { hit }
        }
        if let existing = inFlight[keyStr] { return existing }
        let task = Task<PlatformImage?, Never> { [self] in
            defer { Task { @MainActor in self.inFlight[keyStr] = nil } }
            let urls: [URL] = {
                if let id = YouTubeThumbnail.videoId(from: url) {
                    return YouTubeThumbnail.candidateURLs(videoId: id)
                }
                return [url]
            }()
            for candidate in urls {
                do {
                    let (data, response) = try await URLSession.shared.data(from: candidate)
                    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                        continue
                    }
                    #if canImport(UIKit)
                    guard !Task.isCancelled, let decoded = UIImage(data: data) else { continue }
                    #else
                    guard !Task.isCancelled, let decoded = NSImage(data: data) else { continue }
                    #endif
                    // Skip tiny YT error placeholders when a better candidate may exist.
                    if decoded.size.width < 120, candidate != urls.last { continue }
                    let img = YouTubeThumbnail.cropLetterboxIfNeeded(decoded, url: candidate)
                    let cost = data.count
                    self.memory.setObject(img, forKey: key, cost: cost)
                    return img
                } catch {
                    continue
                }
            }
            return nil
        }
        inFlight[keyStr] = task
        return task
    }
}

public struct CachedAsyncImage: View {
    let url: URL?
    var lowResURL: URL? = nil
    private let renderer: (PlatformImage) -> AnyView
    private let placeholderView: AnyView

    @State private var image: PlatformImage? = nil
    @State private var loadedIdentity: String?

    private var requestIdentity: String {
        "\(url?.absoluteString ?? "nil")#\(lowResURL?.absoluteString ?? "nil")"
    }

    public init(url: URL?,
                lowResURL: URL? = nil,
                content: @escaping (Image) -> some View,
                placeholder: @escaping () -> some View) {
        self.url = url
        self.lowResURL = lowResURL
        #if canImport(UIKit)
        self.renderer = { img in AnyView(content(Image(uiImage: img))) }
        #else
        self.renderer = { img in AnyView(content(Image(nsImage: img))) }
        #endif
        self.placeholderView = AnyView(placeholder())
    }

    public var body: some View {
        Group {
            if loadedIdentity == requestIdentity, let img = image {
                renderer(img)
            } else {
                placeholderView
            }
        }
        .task(id: requestIdentity) {
            guard let url else {
                image = nil
                loadedIdentity = nil
                return
            }

            if let hit = ImageLoader.shared.cachedImage(for: url) {
                image = hit
                loadedIdentity = requestIdentity
                return
            }

            var lowResTask: Task<PlatformImage?, Never>?
            if let low = lowResURL, low != url {
                if let hit = ImageLoader.shared.cachedImage(for: low) {
                    image = hit
                } else {
                    lowResTask = ImageLoader.shared.load(low)
                }
            }

            let fullTask = ImageLoader.shared.load(url)

            if let lowTask = lowResTask {
                let lowResult = await lowTask.value
                if !Task.isCancelled, image == nil, let lowResult {
                    image = lowResult
                }
            }

            let fullResult = await fullTask.value
            if !Task.isCancelled {
                if let fullResult {
                    image = fullResult
                    loadedIdentity = requestIdentity
                } else if image != nil {
                    loadedIdentity = requestIdentity
                }
            }
        }
    }
}
