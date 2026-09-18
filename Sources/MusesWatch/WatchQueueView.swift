import SwiftUI

struct WatchQueueView: View {
    @Bindable var session: WatchRemoteSession
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            Group {
                if session.state.queue.isEmpty {
                    ContentUnavailableView(
                        wtr("Queue is empty", "队列是空的"),
                        systemImage: "music.note.list",
                        description: Text(wtr(
                            "Play a song on iPhone. The queue appears here.",
                            "在 iPhone 上播放后，队列会显示在这里。"
                        ))
                    )
                } else {
                    List {
                        ForEach(Array(session.state.queue.enumerated()), id: \.element.id) { index, item in
                            Button {
                                session.playIndex(index)
                                isPresented = false
                            } label: {
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
                                        Text(item.artist)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    if index == session.state.currentIndex {
                                        Image(systemName: session.state.isPlaying ? "waveform" : "pause.fill")
                                            .foregroundStyle(.primary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(
                                index == session.state.currentIndex
                                    ? Color.white.opacity(0.12)
                                    : Color.clear
                            )
                        }
                    }
                }
            }
            .navigationTitle(wtr("Queue", "队列"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(wtr("Close", "关闭")) {
                        isPresented = false
                    }
                }
            }
        }
    }
}
