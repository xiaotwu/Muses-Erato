# P1 official YouTube IFrame prototype

This folder is the P1-owned, iOS-only playback adapter. It uses the official `https://www.youtube.com/iframe_api` inside a visible `WKWebView`. The player keeps its controls, attribution, and ads. The adapter accepts only validated 11-character video IDs; it never returns or caches a media URL.

## P4 integration contract

1. Add these three Swift files to the iOS target when updating `project.yml` and the Xcode project. P1 intentionally does not modify those shared files. `YouTubeIFrameFactory.make()` creates an adapter on the main actor.
2. Attach `adapter.view` to a **visible** playback screen, with at least a 200×200 player viewport and enough room for controls. Then call `load(IFrameVideoID)`. Do not call `load` in a hidden mini player. Keep this adapter alive while the screen owns the visible player.
3. Map P2's `.youtubeVideo(VideoID)` to `IFrameVideoID`. Map `IFrameEvent` to P2's playback events with `generation` and source identity intact. `load` returns the adapter generation; P4 must also apply its queue generation and drop stale results. A `ready` event means the IFrame is ready, not that playback has started. `play()` requires `ready`; a `playing` event confirms actual playback. `pause()` and `seek(to:)` use the Player API.
4. On a visible screen transition or dismissal, call `teardown()` before removing the view. Background entry pauses automatically. A torn-down adapter cannot be reused; create a new one for the next visible screen. The coordinator must guarantee only one audible adapter. Do not resume on foreground automatically.
5. Map `.embeddingDisabled` (YouTube errors 101/150), `.unavailableVideo` (100), `.missingClientIdentity` (153), `.network`, and other typed failures to visible UI. Offer `IFrameVideoID.watchURL` as **Open in YouTube** for an embedding error. Do not fall back to a native stream or hidden audio player.

For a temporary P4 route, present `YouTubeIFrameDemoViewController(first:next:)` with two known IDs. It has Play, Pause, Seek, Next, an event label, and an Open in YouTube action when embedding is blocked. Its source typechecks against the iOS 18 simulator SDK, but no production route is wired in P1.

## Verification

Run the pure bridge/generation checks from the repository root:

```sh
swiftc Sources/Muses/Platform/iOS/YouTubeIFrame/YouTubeIFrameContract.swift Tests/YouTubeIFrameTests/ContractChecks.swift -o /tmp/erato-p1-contract-checks
/tmp/erato-p1-contract-checks
```

Typecheck the iOS adapter and demo without changing the shared project:

```sh
xcrun swiftc -swift-version 6 -strict-concurrency=complete -typecheck -target arm64-apple-ios18.0-simulator -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" Sources/Muses/Platform/iOS/YouTubeIFrame/*.swift
```

No physical iPhone or iPad was available in P0. The required device evidence remains: actual visible play and audio, Next in the same WebView, leave screen, background/return, offline/network loss, blocked embedding, controls and attribution on both iPhone and iPad. Simulator typechecking and bridge checks do not establish those outcomes or App Store acceptance.

Official API references: [IFrame Player API](https://developers.google.com/youtube/iframe_api_reference), [embedded player requirements](https://developers.google.com/youtube/player_parameters), and [iOS helper guidance](https://developers.google.com/youtube/v3/guides/ios_youtube_helper).
