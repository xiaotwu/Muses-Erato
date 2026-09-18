import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Borderless karaoke lyrics — typography-first, no glass card or laser frame.
public struct LyricsKaraokeView: View {
    let lyrics: String?
    let currentPosition: Double
    let onSeek: (Double) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                emptyState
            } else {
                lyricsScroll
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { parseLyrics() }
        .onChange(of: lyrics) { _, _ in parseLyrics() }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text(tr("No Lyrics Available", "暂无歌词", zhHant: "暫無歌詞"))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(.white.opacity(0.78))
            Text(tr("Use the cover button to return", "点按左上角返回封面", zhHant: "點按左上角返回封面"))
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.38))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    private var lyricsScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .center, spacing: 0) {
                    Color.clear.frame(height: 88)

                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        let distance = abs(index - max(activeLineIndex, 0))
                        let isActive = index == activeLineIndex

                        Button {
                            triggerHapticFeedback()
                            onSeek(line.time)
                        } label: {
                            Text(line.text)
                                .font(font(for: distance, active: isActive))
                                .tracking(isActive ? 0.6 : 0.2)
                                .foregroundStyle(foreground(for: distance, active: isActive))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, isActive ? 14 : 10)
                                .shadow(
                                    color: isActive && !reduceMotion
                                        ? Color.white.opacity(0.22)
                                        : .clear,
                                    radius: isActive ? 12 : 0
                                )
                                .scaleEffect(isActive ? 1.02 : 1.0)
                                .animation(
                                    reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.82),
                                    value: isActive
                                )
                        }
                        .buttonStyle(.plain)
                        .id(line.id)
                        .accessibilityLabel(line.text)
                        .accessibilityAddTraits(isActive ? .isSelected : [])
                    }

                    Color.clear.frame(height: 140)
                }
                .padding(.horizontal, 28)
            }
            .onChange(of: activeLineIndex) { _, newIndex in
                guard newIndex >= 0, newIndex < lines.count else { return }
                withAnimation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.84)) {
                    proxy.scrollTo(lines[newIndex].id, anchor: .center)
                }
            }
        }
    }

    private func font(for distance: Int, active: Bool) -> Font {
        if active {
            return .system(size: 28, weight: .bold, design: .rounded)
        }
        switch distance {
        case 1:
            return .system(size: 20, weight: .semibold, design: .rounded)
        case 2:
            return .system(size: 17, weight: .medium, design: .rounded)
        default:
            return .system(size: 15, weight: .regular, design: .rounded)
        }
    }

    private func foreground(for distance: Int, active: Bool) -> Color {
        if active { return Color.white }
        switch distance {
        case 1: return Color.white.opacity(0.52)
        case 2: return Color.white.opacity(0.30)
        default: return Color.white.opacity(0.16)
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
        for raw in text.components(separatedBy: .newlines) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if let openBracket = trimmed.firstIndex(of: "["),
               let closeBracket = trimmed.firstIndex(of: "]"),
               openBracket < closeBracket {
                let tag = String(trimmed[trimmed.index(after: openBracket)..<closeBracket])
                let lyricText = String(trimmed[trimmed.index(after: closeBracket)...])
                    .trimmingCharacters(in: .whitespaces)
                if let timeSec = parseTimestamp(tag), !lyricText.isEmpty {
                    parsed.append(ParsedLyricLine(time: timeSec, text: lyricText))
                }
            } else {
                parsed.append(ParsedLyricLine(time: 0, text: trimmed))
            }
        }

        lines = parsed.sorted { $0.time < $1.time }
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
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
