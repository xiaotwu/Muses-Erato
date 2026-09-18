import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Ambient wash sampled from the playing cover, not from a title hash.
struct AmbientMeshBackground: View {
    let track: TrackSnapshot?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false
    @State private var palette: [Color] = AmbientMeshBackground.fallbackPalette

    var body: some View {
        GeometryReader { geo in
            ZStack {
                (palette.first ?? Color.black)
                    .ignoresSafeArea()
                if !reduceTransparency {
                    Circle()
                        .fill(palette[safe: 0, fallback].opacity(0.55))
                        .frame(width: geo.size.width * 1.25)
                        .blur(radius: 80)
                        .offset(x: animate ? -36 : 28, y: animate ? -50 : 16)
                    Circle()
                        .fill(palette[safe: 1, fallback].opacity(0.42))
                        .frame(width: geo.size.width * 1.1)
                        .blur(radius: 80)
                        .offset(x: animate ? 46 : -18, y: animate ? 8 : 70)
                    Circle()
                        .fill(palette[safe: 2, fallback].opacity(0.32))
                        .frame(width: geo.size.width * 1.3)
                        .blur(radius: 90)
                        .offset(x: animate ? -16 : 36, y: animate ? 110 : 36)
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.28),
                            Color.black.opacity(0.12),
                            Color.black.opacity(0.5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
            .task(id: track?.artworkUrl ?? track?.id.uuidString) {
                palette = await Self.palette(for: track)
            }
        }
    }

    private var fallback: Color { AmbientMeshBackground.fallbackPalette[0] }

    static let fallbackPalette: [Color] = [
        Color(red: 31 / 255, green: 31 / 255, blue: 31 / 255),
        Color(red: 48 / 255, green: 48 / 255, blue: 48 / 255),
        Color(red: 22 / 255, green: 22 / 255, blue: 22 / 255)
    ]

    static func palette(for track: TrackSnapshot?) async -> [Color] {
        #if canImport(UIKit)
        guard let urlString = track?.artworkUrl, let url = URL(string: urlString),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else {
            return fallbackPalette
        }
        let colors = AlbumArtworkExtractor.dominantColors(image, count: 3)
        if colors.isEmpty { return fallbackPalette }
        return colors.map { Color(uiColor: $0) }
        #else
        return fallbackPalette
        #endif
    }
}

private extension Array where Element == Color {
    subscript(safe index: Int, fallback: Color) -> Color {
        indices.contains(index) ? self[index] : fallback
    }
}
