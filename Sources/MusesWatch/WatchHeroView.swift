import SwiftUI
import UIKit

struct WatchHeroView: View {
    @Bindable var session: WatchRemoteSession
    @State private var showQueue = false
    @State private var pendingCenterTap: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack {
                Color.black.ignoresSafeArea()
                if session.state.queue.isEmpty && !session.state.hasTrack {
                    emptyState
                } else {
                    deck(width: width, height: geo.size.height)
                }
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture(count: 2).onEnded { handleDoubleTap() }
            )
            .gesture(swipeGesture)
            .onTapGesture { location in
                handleTap(x: location.x, width: width)
            }
        }
        .navigationTitle("Muses")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showQueue) {
            WatchQueueView(session: session, isPresented: $showQueue)
        }
        .onDisappear { pendingCenterTap?.cancel() }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "applewatch.and.arrow.forward")
                .font(.title)
                .foregroundStyle(.white)
            Text(wtr("Waiting for iPhone", "正在连接 iPhone"))
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(wtr(
                "Opening this app starts Muses on iPhone. Play a song there, then control it here.",
                "打开手表会同时启动 iPhone 上的 Muses。先在手机播放，再用手表遥控。"
            ))
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.65))
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 10)
    }

    private func deck(width: CGFloat, height: CGFloat) -> some View {
        let cardWidth = min(width * 0.72, height * 0.58)
        return ZStack {
            if let previous = session.state.previousItem {
                peekCard(item: previous, width: cardWidth)
                    .scaleEffect(0.78)
                    .offset(x: -cardWidth * 0.62)
                    .opacity(0.45)
                    .allowsHitTesting(false)
            }
            if let next = session.state.nextItem {
                peekCard(item: next, width: cardWidth)
                    .scaleEffect(0.78)
                    .offset(x: cardWidth * 0.62)
                    .opacity(0.45)
                    .allowsHitTesting(false)
            }
            heroCard(width: cardWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(heroAccessibilityLabel)
        .accessibilityHint(wtr(
            "Tap for the queue. Double tap to pause or play. Swipe or tap the sides for previous and next.",
            "轻点打开队列。双击暂停或继续。左右滑动或点两侧切歌。"
        ))
        .accessibilityAddTraits(.isButton)
    }

    private func heroCard(width: CGFloat) -> some View {
        VStack(spacing: 8) {
            artwork
                .frame(width: width, height: width)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .white.opacity(session.state.isPlaying ? 0.28 : 0.12), radius: 10)
                .overlay(alignment: .bottomTrailing) {
                    if session.state.isPlaying {
                        Image(systemName: "waveform")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(8)
                    }
                }
            Text(session.state.title.isEmpty ? "Muses" : session.state.title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .shadow(color: .white.opacity(0.22), radius: 6)
            Text(session.state.artist.isEmpty
                 ? wtr("Not Playing", "未在播放")
                 : session.state.artist)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
        }
        .frame(width: width)
    }

    private func peekCard(item: WatchQueueItemSnapshot, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.12))
            .frame(width: width, height: width)
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: "music.note")
                        .foregroundStyle(.white.opacity(0.8))
                    Text(item.title)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
    }

    @ViewBuilder
    private var artwork: some View {
        if let artworkJPEG = session.artworkJPEG,
           let image = UIImage(data: artworkJPEG) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                Image(systemName: "music.note")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.2 else { return }
                pendingCenterTap?.cancel()
                if value.translation.width < 0 {
                    session.next()
                } else {
                    session.previous()
                }
            }
    }

    private func handleTap(x: CGFloat, width: CGFloat) {
        let ratio = width == 0 ? 0.5 : x / width
        if ratio < 0.28 {
            pendingCenterTap?.cancel()
            session.previous()
            return
        }
        if ratio > 0.72 {
            pendingCenterTap?.cancel()
            session.next()
            return
        }
        pendingCenterTap?.cancel()
        pendingCenterTap = Task {
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            showQueue = true
        }
    }

    private func handleDoubleTap() {
        pendingCenterTap?.cancel()
        session.toggleOrPause()
    }

    private var heroAccessibilityLabel: String {
        let title = session.state.title.isEmpty ? "Muses" : session.state.title
        let artist = session.state.artist
        let playing = session.state.isPlaying
            ? wtr("Playing", "正在播放")
            : wtr("Paused", "已暂停")
        if artist.isEmpty { return "\(title), \(playing)" }
        return "\(title), \(artist), \(playing)"
    }
}

func wtr(_ en: String, _ zhHans: String) -> String {
    let language = Locale.current.language.languageCode?.identifier ?? "en"
    return language == "zh" ? zhHans : en
}
