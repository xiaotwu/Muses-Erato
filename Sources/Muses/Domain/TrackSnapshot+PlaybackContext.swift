import Foundation

extension TrackSnapshot {
    /// Sibling queue for a YouTube result set. The playing snapshot keeps its library id;
    /// other rows are ephemeral `youTubeId` snapshots so Next/Previous has collection context.
    static func playbackContext(
        playing: TrackSnapshot,
        youTubeEntries: [YTDlpBridge.YTDlpPlaylistEntry]
    ) -> [TrackSnapshot] {
        guard !youTubeEntries.isEmpty else { return [playing] }
        let mapped = youTubeEntries.map { entry -> TrackSnapshot in
            if playing.youTubeId == entry.id { return playing }
            return TrackSnapshot(
                id: UUID(),
                title: entry.title,
                artist: entry.uploader ?? "",
                albumTitle: nil,
                durationSeconds: entry.duration ?? 0,
                youTubeId: entry.id,
                artworkUrl: YouTubeThumbnail.urlString(videoId: entry.id),
                sampleRate: nil, bitDepth: nil, codec: nil, isLossless: false
            )
        }
        if mapped.contains(where: { $0.youTubeId == playing.youTubeId }) {
            return mapped
        }
        return [playing] + mapped
    }

}
