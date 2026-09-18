import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Karaoke lyrics stage — centered lines in a laser glass card, matching NP chrome.
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
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(BrandColors.hairline.opacity(0.55), lineWidth: 0.6)
                .allowsHitTesting(false)
        }
        .laserStroke(cornerRadius: 28, lineWidth: 1.0, opacity: 0.70)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onAppear { parseLyrics() }
        .onChange(of: lyrics) { _, _ in parseLyrics() }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "quote.bubble")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 72, height: 72)
                .musesGlass(in: Circle(), tint: Color.white.opacity(0.10), role: .compactControl)
                .laserStrokeCircle(lineWidth: 0.9, opacity: 0.55)
            Text(tr("No Lyrics Available", "暂无歌词", zhHant: "暫無歌詞"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
            Text(tr("Tap cover art to return", "点按封面返回", zhHant: "點按封面返回"))
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.42))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var lyricsScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .center, spacing: 22) {
                    Color.clear.frame(height: 72)

                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        let isActive = index == activeLineIndex
                        let isNear = abs(index - activeLineIndex) == 1

                        Button {
                            triggerHapticFeedback()
                            onSeek(line.time)
                        } label: {
                            VStack(spacing: 8) {
                                Text(line.text)
                                    .font(.system(
                                        size: isActive ? 24 : (isNear ? 18 : 16),
                                        weight: isActive ? .bold : .semibold,
                                        design: .rounded
                                    ))
                                    .foregroundStyle(
                                        isActive
                                            ? Color.white
                                            : Color.white.opacity(isNear ? 0.55 : 0.28)
                                    )
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .shadow(
                                        color: isActive ? Color.white.opacity(0.28) : .clear,
                                        radius: isActive ? 10 : 0
                                    )

                                // Laser underline for the singing line.
                                Capsule()
                                    .fill(
                                        AngularGradient(
                                            colors: BrandColors.laserSpectrum.map {
                                                $0.opacity(isActive ? 0.85 : 0)
                                            },
                                            center: .center
                                        )
                                    )
                                    .frame(width: isActive ? 48 : 0, height: 2)
                                    .opacity(isActive ? 1 : 0)
                            }
                            .padding(.vertical, isActive ? 6 : 2)
                            .animation(
                                reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.78),
                                value: isActive
                            )
                        }
                        .buttonStyle(.plain)
                        .id(line.id)
                        .accessibilityLabel(line.text)
                        .accessibilityAddTraits(isActive ? .isSelected : [])
                    }

                    Color.clear.frame(height: 120)
                }
                .padding(.horizontal, 22)
            }
            .onChange(of: activeLineIndex) { _, newIndex in
                guard newIndex >= 0, newIndex < lines.count else { return }
                withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82)) {
                    proxy.scrollTo(lines[newIndex].id, anchor: .center)
                }
            }
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}
