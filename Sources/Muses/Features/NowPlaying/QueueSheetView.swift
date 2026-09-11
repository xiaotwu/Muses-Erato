import SwiftUI

/// Playing Next Up-Next Queue sheet for iOS.
struct QueueSheetView: View {
    @Bindable var queue: QueueService
    @Bindable var playback: PlaybackService
    @Environment(\.dismiss) private var dismiss

    init(queue: QueueService, playback: PlaybackService) {
        self.queue = queue
        self.playback = playback
    }

    var body: some View {
        NavigationStack {
            List {
                // Now Playing section
                if let current = playback.state.track {
                    Section(header: Text(tr("Now Playing", "正在播放")).font(.headline)) {
                        HStack(spacing: 12) {
                            artworkView(for: current)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(current.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(BrandColors.accent)
                                    .lineLimit(1)

                                Text(current.artist)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(BrandColors.textSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "waveform")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(BrandColors.accent)
                                .symbolEffect(.variableColor.iterative.reversing)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Playing Next section
                Section(header: HStack {
                    Text(tr("Playing Next", "接下来播放")).font(.headline)
                    Spacer()
                    if !queue.items.isEmpty {
                        Button(tr("Clear", "清空")) {
                            queue.clear()
                        }
                        .font(.subheadline)
                        .foregroundStyle(BrandColors.accent)
                    }
                }) {
                    if queue.items.isEmpty {
                        Text(tr("Queue is empty", "队列为空"))
                            .font(.subheadline)
                            .foregroundStyle(BrandColors.textSecondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(Array(queue.items.enumerated()), id: \.element.id) { index, item in
                            QueueItemRow(index: index, item: item) {
                                playback.play(item)
                            }
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { queue.remove(at: $0) }
                        }
                    }
                }
            }
            .navigationTitle(tr("Playing Next", "待播清单"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("Done", "完成")) {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(BrandColors.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func artworkView(for track: TrackSnapshot) -> some View {
        if let urlStr = track.artworkUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    Color.gray.opacity(0.3)
                }
            }
        } else {
            Color.gray.opacity(0.3)
        }
    }
}

private struct QueueItemRow: View {
    let index: Int
    let item: QueueItem
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(BrandColors.textTertiary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.track.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(BrandColors.textPrimary)
                    .lineLimit(1)

                Text(item.track.artist)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(BrandColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onPlay) {
                Image(systemName: "play.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(BrandColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
