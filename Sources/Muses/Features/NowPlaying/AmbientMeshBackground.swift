import SwiftUI

/// Dynamic animated ambient chromatic background that breathes with the music.
struct AmbientMeshBackground: View {
    let track: TrackSnapshot?
    @State private var animate = false

    init(track: TrackSnapshot?) {
        self.track = track
    }

    public var body: some View {
        GeometryReader { geo in
            let palette = derivePalette(for: track)

            ZStack {
                // Base obsidian background
                Color.black.ignoresSafeArea()

                // Animated Color Blob 1 (Top Leading)
                Circle()
                    .fill(palette[0].opacity(0.45))
                    .frame(width: geo.size.width * 1.2)
                    .blur(radius: 80)
                    .offset(x: animate ? -40 : 30, y: animate ? -60 : 20)

                // Animated Color Blob 2 (Center Trailing)
                Circle()
                    .fill(palette[1].opacity(0.40))
                    .frame(width: geo.size.width * 1.1)
                    .blur(radius: 80)
                    .offset(x: animate ? 50 : -20, y: animate ? 10 : 80)

                // Animated Color Blob 3 (Bottom)
                Circle()
                    .fill(palette[2].opacity(0.35))
                    .frame(width: geo.size.width * 1.3)
                    .blur(radius: 90)
                    .offset(x: animate ? -20 : 40, y: animate ? 120 : 40)

                // Subtle dark vignette layer to guarantee typography contrast
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.35),
                                Color.black.opacity(0.15),
                                Color.black.opacity(0.55)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea()
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
        }
    }

    /// Derives a 3-color palette deterministically from the track title/artist hash.
    private func derivePalette(for track: TrackSnapshot?) -> [Color] {
        guard let track else {
            return [
                Color(red: 0.98, green: 0.35, blue: 0.42),
                Color(red: 0.52, green: 0.22, blue: 0.85),
                Color(red: 0.15, green: 0.45, blue: 0.88)
            ]
        }

        let seed = abs(track.title.hashValue ^ track.artist.hashValue)
        let hue1 = Double(seed % 360) / 360.0
        let hue2 = Double((seed + 120) % 360) / 360.0
        let hue3 = Double((seed + 240) % 360) / 360.0

        return [
            Color(hue: hue1, saturation: 0.75, brightness: 0.8),
            Color(hue: hue2, saturation: 0.70, brightness: 0.75),
            Color(hue: hue3, saturation: 0.65, brightness: 0.7)
        ]
    }
}
