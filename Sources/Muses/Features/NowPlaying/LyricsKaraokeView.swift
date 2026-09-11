import SwiftUI

/// High-precision real-time synchronized karaoke lyrics view.
public struct LyricsKaraokeView: View {
    let lyrics: String?
    let currentPosition: Double
    let onSeek: (Double) -> Void

    @State private var lines: [ParsedLyricLine] = []

    public init(lyrics: String?, currentPosition: Double, onSeek: @escaping (Double) -> Void) {
        self.lyrics = lyrics
        self.currentPosition = currentPosition
        self.onSeek = onSeek
    }

    public struct ParsedLyricLine: Identifiable, Equatable {
        public let id = UUID()
        public let time: Double
        public let text: String
    }

    public var body: some View {
        Group {
            if lines.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.white.opacity(0.35))
                    Text(tr("No Lyrics Available", "暂无歌词"))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 26) {
                            // Top padding so first line can scroll to center
                            Color.clear.frame(height: 120)

                            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                                let isActive = index == activeLineIndex

                                Button {
                                    triggerHapticFeedback()
                                    onSeek(line.time)
                                } label: {
                                    Text(line.text)
                                        .font(.system(size: isActive ? 26 : 22, weight: isActive ? .bold : .semibold, design: .rounded))
                                        .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.38))
                                        .scaleEffect(isActive ? 1.04 : 1.0, anchor: .leading)
                                        .shadow(color: isActive ? Color.white.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 0)
                                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isActive)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .id(line.id)
                            }

                            // Bottom padding so last line can scroll to center
                            Color.clear.frame(height: 200)
                        }
                        .padding(.horizontal, 28)
                    }
                    .onChange(of: activeLineIndex) { _, newIndex in
                        if newIndex >= 0 && newIndex < lines.count {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                proxy.scrollTo(lines[newIndex].id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            parseLyrics()
        }
        .onChange(of: lyrics) { _, _ in
            parseLyrics()
        }
    }

    private var activeLineIndex: Int {
        guard !lines.isEmpty else { return -1 }
        var result = -1
        for (i, line) in lines.enumerated() {
            if line.time <= currentPosition {
                result = i
            } else {
                break
            }
        }
        return result
    }

    private func parseLyrics() {
        guard let text = lyrics, !text.isEmpty else {
            lines = []
            return
        }

        var parsed: [ParsedLyricLine] = []
        let rawLines = text.components(separatedBy: .newlines)

        for raw in rawLines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Match [mm:ss.xx] or [mm:ss]
            if let openBracket = trimmed.firstIndex(of: "["),
               let closeBracket = trimmed.firstIndex(of: "]"),
               openBracket < closeBracket {
                let tag = String(trimmed[trimmed.index(after: openBracket)..<closeBracket])
                let lyricText = String(trimmed[trimmed.index(after: closeBracket)...]).trimmingCharacters(in: .whitespaces)

                if let timeSec = parseTimestamp(tag), !lyricText.isEmpty {
                    parsed.append(ParsedLyricLine(time: timeSec, text: lyricText))
                }
            } else {
                // Plain text line
                parsed.append(ParsedLyricLine(time: 0, text: trimmed))
            }
        }

        self.lines = parsed.sorted { $0.time < $1.time }
    }

    private func parseTimestamp(_ tag: String) -> Double? {
        let parts = tag.components(separatedBy: ":")
        guard parts.count == 2,
              let minutes = Double(parts[0]),
              let seconds = Double(parts[1]) else { return nil }
        return minutes * 60.0 + seconds
    }

    private func triggerHapticFeedback() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
}
