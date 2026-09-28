# Native audio, confirmations and song display — 2026-09-28

## User decisions

- Confirm deletion/removal and explicit cloud synchronization before changing local information.
- Preserve the hero-card fan/swipe interaction; fill artwork edge to edge without letterboxed thumbnails or a solid black footer.
- Provide music-style Now Playing, a mini player, background audio and lock-screen transport controls. Preserve website playback.
- Show song title and artist/creator in queue and history. Do not expose opaque video identifiers as song labels.
- The user accepts an IPA distribution path when required by playback functionality. App Store/P6 completion is not implied by this work. Physical background/lock-screen verification is deferred by the user.

## Composition and distribution

| Configuration | Stream resolver | Background entitlement | Playback choice |
| --- | --- | --- | --- |
| Release | Local extraction call is compiled out | No `UIBackgroundModes` | Visible YouTube player and website entry |
| Debug / Native | YouTubeKit 0.4.9, local extraction only | `audio` in `Info-Native.plist` | Explicit Background audio option plus YouTube player and website |

The native option defaults off and persists only after the user selects it and accepts its disclosure. A prior native preference cannot enable the resolver in Release. `Native` is an optimized IPA build configuration; archive with the existing Muses scheme and `-configuration Native`. Signing/export still needs the appropriate Apple provisioning profile. TestFlight has its own review requirements and is not treated as an automatic alternative to those requirements.

YouTubeKit is pinned to tag 0.4.9 / e5b7d0396ce12bf3444f0d209e8436c83373b7af; its MIT license is bundled. Resolution uses `.local`, `useOAuth: false`, `allowOAuthCache: false`. Google OAuth credentials are never passed to the resolver; remote extraction servers are not enabled. Media URLs are used in memory by AVPlayer and never saved as an offline download. This is an experimental playback route, not a claim of App Store or YouTube policy acceptance.

## Playback implementation

- One session-owned AVPlayer; detach/tear down IFrame before native load, stop native audio before switching back.
- AVAudioSession `.playback` / `.longFormAudio`, background audio capability, Now Playing title/creator/artwork/progress/rate, MediaPlayer play/pause/toggle/previous/next/seek commands.
- Player presentation can minimize without stopping native audio. Website/IFrame playback keeps its visible-player lifecycle.
- Native end-of-item advances the existing occurrence-aware queue; removing upcoming entries leaves the current item playing. Next remote command is disabled when no next entry exists.
- Audio interruption resumes only when the system permits and the session was playing; headphone disconnection pauses. Stop clears pending interruption resume, media item and system command registrations.
- Resolution has a 25-second deadline. Cancellation and generation checks suppress late responses after a different track or Stop. Stream failures provide a usable website/player fallback.
- MediaPlayer artwork and remote-command callbacks and KVO observation callbacks are constructed outside MainActor and marshal state changes onto MainActor. This fixes the Swift 6 executor trap observed while the system read lock-screen artwork.
- Native music page has artwork, title/creator, favorite, progress slider, previous/play/next, system volume, audio output, queue and notebook entry. Mini player sits above tab navigation. Original queue, notes and bookmarks remain accessible.

## Confirmations and artwork

Queue menu removal/swipe deletion and playlist occurrence/swipe deletion stage occurrence IDs, then confirm the mutation. Queue IDs are rechecked at confirmation to avoid stale index deletion. Existing bulk clear, playlist deletion, saved-video deletion and notebook confirmations remain. Favorite removal now confirms in Details and both playback routes.

Explicit Refresh details and Library pull-to-refresh show Sync details confirmation. Import preview requires confirmation before saving the local copy. Routine account/Home browsing and temporary display-name hydration are reads, not remote playlist writes: automatic loading requested by the user remains. The app does not write Google playlists.

New destructive/sync dialogs use alerts with explicit Cancel actions, avoiding the platform's compact confirmation popovers that omit a visible Cancel action on some layouts.

Artwork prioritizes validated HTTP 200 `maxresdefault.jpg`, falling back to `mqdefault.jpg`. Both are filled/cropped into the card's actual bounds. `hqdefault.jpg` is avoided because it often includes baked-in letterboxing. The bottom readability scrim is lighter; titles can use two lines.

## Song metadata

`MusesCatalog.CatalogItem` now carries optional `channelTitle`. Video/search parsing uses `snippet.channelTitle`; playlist entry parsing uses `snippet.videoOwnerChannelTitle`, not the playlist curator. Topic channel suffixes are normalized for display. This is creator/artist display information, not a guarantee of complete multi-artist music credits. When unavailable, the UI says Unknown artist.

The canonical local store intentionally contains references instead of durable API display metadata. A cold start therefore hydrates missing display information in batches of up to 50 video IDs, with request throttling and account/deletion/cancellation guards. It changes no playlist membership. User-authored titles are preserved; queue/history and other track surfaces share readable display fields. Missing metadata is labeled unavailable rather than displaying a technical ID. Native lock-screen metadata is updated after hydration or manual refresh.

Primary field references: [video resource](https://developers.google.com/youtube/v3/docs/videos#snippet.channelTitle), [playlist item resource](https://developers.google.com/youtube/v3/docs/playlistItems#snippet.videoOwnerChannelTitle). Resolver source: [YouTubeKit](https://github.com/alexeichhorn/YouTubeKit).

## Evidence and remaining acceptance

- Native resolver probe from this Mac: `dQw4w9WgXcQ` and `jNQXAC9IVRw` both yielded compatible audio streams; range requests returned HTTP 206 and 1,024 bytes. This is resolution evidence, not physical-device background acceptance.
- Catalog package: 28 tests passed after the optional creator-field change (`/tmp/erato-song-catalog-tests.log`).
- Native stale-response/Stop test passed with a real AVPlayer item and generated local silent audio. Cold-start song-name/creator hydration test passed without altering queue or playlist membership (`/tmp/erato-native-final-tests2.xcresult`).
- Import confirmation/cancellation, automatic paging and original playlist name retention passed in that same result bundle. That bundle also contains an earlier native UI failure and is not an overall passing suite.
- Queue and playlist swipe-removal Cancel/commit, favorites removal, relaunch, hero deletion and official Made for Kids restriction passed in `/tmp/erato-native-regression3.xcresult`. That bundle also contains an outdated ambiguous Cancel query in the import test; the corrected import test passed subsequently.
- Native UI acceptance passed in `/tmp/erato-native-ui-accepted.xcresult`: enabling mode after disclosure, generated-silent-audio AVPlayer controls, sync Cancel, usable Queue button, minimize/mini-player position and preserved website entry. Simulator screenshots were reviewed; their titles are deliberately isolated fixture data.
- Final Debug signed device build succeeded (`/tmp/erato-native-device-accepted-build.log`); the update was installed and launched on the user's connected iPhone without uninstalling or deleting its data.
- Final public Release simulator build and optimized Native signed device build succeeded (`/tmp/erato-public-release-final-build.log`, `/tmp/erato-native-release-build.log`). Built Info.plist inspection confirmed Release has no background audio mode; Debug/Native have `audio`.
- A live, bundle-identified Data API metadata request using the user's local configuration returned HTTP 200 and the real title `Rick Astley - Never Gonna Give You Up (Official Video) (4K Remaster)` / creator `Rick Astley`. No credentials were printed or committed.

Physical acceptance still required: audible YouTube native stream; desktop/background continuity; lock-screen artwork/title/progress; play/pause/previous/next/seek; automatic next song while locked; interruption and headphone disconnection. The user said they will test later. Do not report these as passed from simulator results or successful installation.

All edits are in the guided UI worktree. The original checkout's 65 dirty entries are untouched. No upload, publication, original-checkout reset or P6 acceptance was performed.

## Follow-up: stalled startup, direct playback and Liquid Glass

User reported partial tracks remaining in loading without an error. The old watchdog was canceled when a URL was assigned, before audio actually decoded. Startup now stays bounded through resolution (25 seconds) and decoding (15 seconds). A failed/stalled stream gets one attempt using a different compatible format where available; a second failure produces an actionable error. Actual advancing playback time, rather than AVPlayer's timeControlStatus alone, ends the startup watchdog. Loading shows Preparing/Retrying audio and an explicit Retry action. Seeking resets the progress baseline.

AVPlayer uses a two-second preferred forward buffer and immediate playback rather than automatic stall minimization. Compatible candidate URLs are held only in a bounded, five-minute process-memory cache. Automatic retries reject the failed format and select another audio/progressive candidate; explicit Retry refreshes the cache. Audio is never persisted. This reduces repeated extraction waits, but does not promise instant starts for uncached or unavailable tracks.

Audio-session activation moves before asynchronous extraction. Queue transitions keep the established session active. A finite UIKit background task covers startup/transition work and ends on decoded progress, paused readiness, Stop or failure. Expiration is generation-guarded and reports an error. These changes address a reproduced activation failure and the background transition gap; full locked-device continuity still requires physical acceptance.

Home shelves and collection/history rows now play immediately when tapped. Details remain available through the explicit info/overflow action. Queue and history use a shared, passive portrait hero cover. Validated artwork fills its bounds; a bounded paired-black-edge crop removes baked letterboxing while preserving uniformly dark covers. Playlist hero-card layout/gesture behavior is retained.

Design references reviewed: the SwiftUI Liquid Glass skill, the user-shared dickwu Apple Design skill (accessibility, layout, typography, color, designing for iOS, tab bars, toolbars, buttons, loading, materials and Liquid Glass), and Apple's [adoption guidance](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass), [custom-view guidance](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views), and [WWDC SwiftUI design session](https://developer.apple.com/videos/play/wwdc2025/323/). The bowen31337 skill targets web CSS/SVG; native SwiftUI APIs supply the iOS implementation.

- iOS 26.1+: system tab-view bottom accessory hosts the mini player, without nesting another glass background inside it.
- iOS 26 / iPad split layout: native glass floating mini player; prior systems use material/opaque fallback.
- Playback/action groups: native glass button styles inside GlassEffectContainer; Reduce Transparency uses borderless/opaque fallbacks.
- Library selection: a single native glass selection capsule; category navigation retains labels and minimum touch targets.
- Settings/navigation/sheets: standard system components, semantic typography and labeled section icons.
- Cover imagery and list content stay in the content layer.

A separate opt-in MusesNativeLive diagnostic scheme exercises actual public YouTube audio; it is excluded from the default offline suite. Initial physical baseline played Rick Astley. Before moving activation earlier, a three-track run failed with audio-session activation errors. After that change all three actual streams (Adele, Rick Astley, The Weeknd) decoded and advanced on the connected iPhone, approximately 9–11 seconds from cold start (`/tmp/erato-native-live-device-v4.xcresult`). This is foreground stream-start evidence, not audible/locked/background acceptance. `/tmp/erato-glass-ui-v1.xcresult` passed native controls and the three engine/artwork unit tests with generated fixture audio. A first direct-play UI run reached Home playback and queue artwork but failed on an incorrect test-only dismissal label (Close queue instead of Done); the test selector was corrected.

Final follow-up evidence:

- Repeated live tests also reproduced intermittent AVPlayer URL failures on Adele and The Weeknd (`/tmp/erato-native-live-final.xcresult`, `/tmp/erato-native-alternates-live-v2.xcresult`); these are failed suites, not acceptance evidence. The final adapter supplies an explicit User-Agent through the public AVURLAssetHTTPUserAgentKey API, retains alternative candidates and rejects failed format IDs on retry. The error includes sanitized domain/code chains and status without exposing signed stream URLs. The exact cause of every intermittent CDN failure is not established.
- Final real iPhone run passed all three foreground stream-start cases (`/tmp/erato-native-useragent-live.xcresult`): Adele 11.5 seconds, Rick Astley 8.1 seconds, The Weeknd 9.3 seconds. Network/extractor behavior may still vary by track, availability and region; this sample does not certify the entire catalog.
- Final engine/artwork unit suite passed all three cases (`/tmp/erato-stream-fallback-unit.xcresult`). Direct Home/history-to-player navigation, queue/history hero-cover screenshots, native control/mini-player placement and cloud-sync Cancel passed (`/tmp/erato-direct-play-ui-v2.xcresult`, two UI tests plus three engine/artwork unit tests). Generated silent fixture audio was used only for those simulator UI tests. Exported queue/history screenshots were visually reviewed and show portrait covers without letterbox padding.
- Final signed Debug device build passed (`/tmp/erato-startup-glass-final-device-build.log`); normal app was reinstalled on the connected iPhone without uninstalling it or deleting user data. Public Release build also passed (`/tmp/erato-release-glass-final-build.log`).
- Remaining user acceptance: previously stalled real tracks, actual audible output, background/locked continuity and next-track behavior, plus visual preference on device. No physical background/lock-screen gate is marked complete.
