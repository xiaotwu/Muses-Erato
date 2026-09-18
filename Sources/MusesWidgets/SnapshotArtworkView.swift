import SwiftUI
import UIKit

struct SnapshotArtworkView: View {
    let fileName: String?

    var body: some View {
        if let fileName,
           let data = NowPlayingSnapshotStore.shared.artworkData(fileName: fileName),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Color.white.opacity(0.12)
                Image(systemName: "music.note")
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}
