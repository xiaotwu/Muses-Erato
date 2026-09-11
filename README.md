# Muses-Erato 🎵

<p align="center">
  <strong>An exquisitely crafted iOS music streaming player designed with Apple's Liquid Glass Design System.</strong><br>
  <em>Ported from <a href="https://github.com/xiaotwu/Muses">Muses for macOS</a> to iOS 18+ (iOS 26 HIG compliant).</em>
</p>

---

## ✨ Overview

**Muses-Erato** (named after *Erato*, the Greek muse of lyric poetry and love songs) brings the powerful streaming capabilities and audiophile control of the macOS desktop player to the palm of your hand, reimagined from the ground up for iOS with Apple's **Liquid Glass Design System** (WWDC 2025/2026 guidelines).

---

## 💎 Design Philosophy: Apple Liquid Glass

Muses-Erato follows strict Apple Human Interface Guidelines for iOS:

1. **Restrained Hierarchy**: Liquid Glass is reserved for interactive floating layers—never for standard background sheets or solid reading content.
   - **Floating Translucent Capsule Tab Bar**: Glides above scrolling content with ultra-thin specular borders, ambient blur, and spring physics.
   - **MiniPlayer Floating Capsule**: Smooth interactive pill featuring dynamic play/pause transitions, progress ring, and interactive drag-to-expand.
   - **Full-Screen Now Playing**: Dynamic chromatic ambient mesh derived from live album artwork palettes (`CIImage` + `CIFilter` extraction) combined with real-time word-by-word synchronized LRC lyrics and subtle interactive glow.
2. **Apple Music Restraint**:
   - Signature accent `#FA586A` (Restrained Apple Music Pink) calibrated for high contrast across both Light and Dark dynamic appearances.
   - Dynamic Type typography hierarchy utilizing Apple SF Pro & SF Pro Rounded.
3. **Tactile Haptic Feedback**: Every scrub, volume change, and playback mode toggle produces fine-tuned sensory feedback using `UIImpactFeedbackGenerator` / `UISelectionFeedbackGenerator`.

---

## 🛠 Features

- 🎧 **Pure Swift InnerTube YouTube Streaming Engine**:
  - Direct client-side stream resolution without relying on external desktop binaries or CLI tools.
  - Complete iOS sandboxing compliance with background audio capabilities (`AVAudioSessionCategoryPlayback`).
- 🎚️ **Tactile 32-Band Audiophile Equalizer**:
  - Parametric 32-band EQ with silky iOS interactive sliders, real-time audio shaping via `AVAudioUnitEQ`, and audio quality indicator badges (Lossless, Hi-Res, Dolby Atmos).
- 📜 **Synced Live Lyrics**:
  - Precise LRC and dynamic synced lyric rendering with auto-scrolling, spring highlighting, and fluid background blurring.
- 📋 **Next-Gen Queue Management**:
  - Interactive "Playing Next" sheet with reordering, quick removal, swipe gestures, and intelligent history playback.
- 💾 **SwiftData Offline & Persistence**:
  - Native SwiftData models for offline track snapshots, listening history, smart playlists, and YouTube catalog sync.
- 🔍 **Universal Search & Discovery**:
  - Unified search across library tracks, albums, artists, and live online streaming catalogues with debounced query resolution.

---

## 🏗 Architecture

```
Sources/Muses/
├── App/
│   ├── MusesApp.swift             # App entrypoint, SwiftData container injection
│   ├── MainTabView.swift          # Floating Liquid Glass tab bar & sheet hosts
│   ├── GlassSurface.swift         # Reusable Liquid Glass modifier & shaders
│   └── AppLogger.swift            # OSLog structured logging
├── Domain/
│   ├── Track.swift                # Track entity & snapshot representations
│   ├── Playlist.swift             # Smart playlist & collection models
│   ├── QueueState.swift           # Queue state machine & history models
│   ├── EQBand.swift               # 32-Band EQ models & presets
│   └── LyricsModels.swift         # Synced LRC line & word timing models
├── Features/
│   ├── Home/                      # Discovery feed, recently played, shortcuts
│   ├── Browse/                    # Curated categories, charts, genres
│   ├── Library/                   # Local library, playlists, favorites
│   ├── Search/                    # Unified global search
│   ├── NowPlaying/                # Fullscreen Now Playing, Synced Lyrics, Ambient Mesh
│   ├── PlayerBar/                 # Floating MiniPlayer capsule
│   ├── EQ/                        # 32-band Tactile Equalizer sheet
│   └── Settings/                  # Playback quality, cache management, audio routes
├── Infrastructure/
│   ├── YouTubeResolver.swift      # InnerTube player extraction & stream resolver
│   ├── ArtworkCache.swift         # LRU image & palette caching
│   └── AudioInfoPanel.swift       # Audiophile bit-depth / sample rate inspector
├── Persistence/
│   ├── MusesSchema.swift          # SwiftData schema definition
│   └── MusesModelContainer.swift  # ModelContainer factory & migrations
└── Services/
    ├── Playback/
    │   ├── PlaybackService.swift  # High-level playback coordinator
    │   └── PlayerEngine.swift     # AVQueuePlayer & audio graph management
    ├── Queue/
    │   └── QueueService.swift     # Queue state & priority FIFO orchestration
    └── System/
        ├── NowPlayingManager.swift # MPNowPlayingInfoCenter & MPRemoteCommandCenter
        └── ContextService.swift   # Audio route & environment awareness
```

---

## 🚀 Building & Running

### Requirements
- macOS 15.0+
- Xcode 16.0+ (iOS 18.0+ SDK)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Getting Started

1. **Clone the repository**:
   ```bash
   git clone https://github.com/xiaotwu/Muses-Erato.git
   cd Muses-Erato
   ```

2. **Generate the Xcode project**:
   ```bash
   xcodegen generate
   ```

3. **Build the project via CLI**:
   ```bash
   xcodebuild -project Muses.xcodeproj -scheme Muses -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 17" build
   ```

4. **Or open with Xcode**:
   ```bash
   open Muses.xcodeproj
   ```
   Select your target simulator or physical device and press **⌘ + R**.

---

## 📄 License

This project is licensed under the terms of the MIT license. Ported and adapted from [Muses](https://github.com/xiaotwu/Muses).
