# ADR 0001 — Public iOS YouTube capability and API boundary

**Status:** Accepted for the public iOS architecture, 2026-09-27. **Scope:** App Store candidate with YouTube as its only content source. This is an engineering release gate, not a statement that Apple or YouTube has approved the app.

## Decision

1. The primary YouTube playback adapter is a **visible official IFrame Player** in `WKWebView`. Keep the video and its YouTube controls, attribution, advertisements and interactions available. The iOS surface must satisfy the IFrame's minimum 200×200 viewport and be large enough for controls. The JS bridge reports ready, state, time, end and error; it accepts only validated YouTube IDs. When the surface is no longer visible, pause/teardown per the verified lifecycle policy. If embedding is blocked, explain the reason and offer **Open in YouTube**.
2. Metadata, search, channels, subscriptions and authorized playlist/account access use documented **YouTube Data API** endpoints. The Data API does not imply access to YouTube Music's private catalog or personalized Home. Use local user state for organization and history, with source/provenance retained.
3. A source-and-distribution capability decision at the composition root selects adapters. For public YouTube video, it yields `iframeVideo=true` and `nativeMediaURL`, `audioProcessing`, `offlineMedia`, `backgroundAudio`, `carPlayAudio`, `watchRemoteAudio` all false. UI actions and system registrations follow those capabilities. A local/expressly licensed media adapter may be designed separately, but is outside the YouTube-only public target.
4. No Innertube parser, yt-dlp, Piped/Invidious mirror, stream URL cache, audio extraction, proxy or Media Gateway is a fallback after IFrame failure. They do not enter the public YouTube playback dependency graph. A successful technical prototype or Ad Hoc IPA does not alter this gate.

## Why and options

The current `AppComposition` injects `YouTubeStreamEngine`; the existing `YouTubeVideoOverlay` only pauses that native engine while its secondary embed plays. Keeping that graph would expose non-public stream resolution and audio separation in the public release. A hidden IFrame would preserve an audio-only UI but still violate the visible-player rule. The chosen visible IFrame path limits native DSP, offline and background features, but matches the documented player model. Native AVPlayer/AVAudioEngine remains a conditional design for media with explicit applicable rights.

Official policy prohibits undocumented API access without express permission, downloading/caching YouTube audiovisual content without prior written approval, separating audio/video, and playback from a player absent from the current screen. The IFrame reference specifies the viewport and Player API. Apple requires permission for third-party service content and explicit authorization to save/convert/download media. These are independent gates: compliance with one does not guarantee App Review approval.

## Interface and account consequences

- IFrame loads `VideoID`, never `ResolvedStream` or a direct media URL. It publishes event generation and actual player state. `PlaybackCoordinator` drops stale JS events and never infers sound from `load` success.
- Catalog accepts documented Data API DTOs behind a mapping layer and tracks endpoint/request counts. No parser DTO crosses into Domain. Quota exhaustion is a visible error, never a silent private-interface retry.
- Separate iOS OAuth client with native callback and per-request PKCE; request scopes only when the current feature needs them. Tokens in Keychain. Revocation deletes authorized data according to policy and clears private UI state. Current loopback-only desktop config is not an iOS release contract.
- In a public YouTube-only target, remove/disable claims and controls for lossless/Hi-Res/Dolby, native EQ/spectrum, offline media, background sound, CarPlay/Watch remote audio and lock-screen transport. Review the current plist/entitlements and README before any archive.

## Quota planning snapshot

Google's current published default is 100 `search.list` calls/day in a separate bucket (1 quota per call), 100 `videos.insert` calls/day, and 10,000 units/day combined for other endpoints. Each pagination request is another call. This is a planning default; the project's actual Cloud console allocation must be checked before traffic estimates or launch.

| User action | Endpoint and call estimate | Default bucket / budget rule | Failure behavior |
| --- | --- | --- | --- |
| Submitted online search | `search.list`, 1 per first page + 1 per requested next page | 100 search calls/day; local query, debounce and dedupe first | Stop querying; show local results and quota-reset explanation |
| Known video/playlist link | Parse ID locally; `videos.list` or `playlists.list` only for metadata, typically 1 | Other-endpoint 10,000 unit pool; 1 per list request | Keep the valid link, show metadata unavailable |
| Account startup | `channels.list` 1; `playlists.list`/`subscriptions.list` 1 per page | Other-endpoint pool; compute pages and cache hit rate | Partial-page status, no silent completeness claim |
| Open playlist | `playlistItems.list` 1 per page; `videos.list` batched as needed | Other-endpoint pool; cap pages and report incomplete | Preserve already read items and retry intentionally |
| Home | Local history/favorites free; subscribed channel reads as above | Never simulate private Music Home | Label available sources and freshness |

At 100 searches/day, even 20 DAU × 5 uncached search pages exhausts the default search bucket; product design or official quota extension is required. Record actual DAU, calls/action, pages, cache hit rate, errors and official allocation in P3. Do not multiply Cloud projects or ask users for developer keys to bypass the quota.

## Release gate and validation

P1 must demonstrate known link → visible play → Next → leave page stops sound on an iPhone and iPad, including unembeddable and network failures. P3 must validate real OAuth, pagination, quotas and deletion. P6 checks final entitlement, privacy, copy and App Review evidence. This ADR changes only through documented policy/permission evidence and a new review; no runtime flag alone grants rights.

## Primary sources checked 2026-09-27

- [YouTube API Developer Policies](https://developers.google.com/youtube/terms/developer-policies), especially III.D.7, III.E.1 and player-integrity restrictions.
- [YouTube IFrame Player API](https://developers.google.com/youtube/iframe_api_reference) and [embedded player parameters](https://developers.google.com/youtube/player_parameters).
- [YouTube Data API quota calculator](https://developers.google.com/youtube/v3/determine_quota_cost) and [native OAuth with PKCE](https://developers.google.com/identity/protocols/oauth2/native-app).
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), especially 5.2.2–5.2.3.
- [Apple CarPlay entitlement request](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements); a plist key alone is not managed-capability approval.
