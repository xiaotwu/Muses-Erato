# P0 frozen cross-phase contracts and file ownership

**Contract revision:** P0.1, 2026-09-27. These are interface and behavior contracts for P1–P4, not claims that the packages already exist. The first package extraction should implement these value boundaries and add contract tests; implementation may change internal names only with a versioned ADR and affected-owner review.

## Shared value contracts (P2 owner)

| Value | Stable requirement |
| --- | --- |
| IDs | `VideoID`, `ChannelID`, `TrackID`, `ArtistID`, `ReleaseID`, `PlaylistID`, `CatalogID` are distinct, validated, Codable/Sendable value types; retain raw provider ID and provenance. A display title is never identity. |
| `PlaybackSource` | Tagged union: `youtubeVideo(VideoID)`, `localFile(BookmarkedFileID)`, `authorizedRemote(ProviderID, ResourceID)`. Public source policy can select only `youtubeVideo`; no stream URL in that case. |
| `ContentRights` + `DistributionCapabilities` | Immutable, injected at composition; origin, license evidence and distribution channel decide allowed adapters. Missing evidence fails closed. Avoid a single `appStore` boolean. |
| `PlaybackCapabilities` | Explicit flags for `seek`, `queueByID`, `backgroundAudio`, `audioProcessing`, `offlineMedia`, `rate`, `gapless`, `systemRemote`, and `videoVisible`. Capability is recomputed for source + adapter + runtime; UI observes it, does not infer from class names. |
| `PlaybackSnapshot` / `PlaybackEvent` | State `idle/loading/ready/playing/paused/buffering/ended/failed`, source, generation, intent, position/duration, capabilities and typed failure. Adapter events include generation and source identity. |
| `QueueSnapshot` | Current, ordered upcoming, history, source context, repeat, shuffle seed/order and monotonically increasing generation. Codable across restart, with no auto-play on restore. |
| Catalog values | `CatalogItem` is a provider result, separate from user-owned `Track`; page carries items, next token, completeness, source and fetched-at. API DTOs never enter Domain. |

## Ports and invariants

- `MusicCatalog.search/home/artist/release/playlist` takes typed requests and returns typed pages. P3 owns adapters; P2 owns request/page definitions. Incomplete pagination is explicit. Catalog cannot resolve streams.
- `PlaybackAdapter` exposes actual capabilities and event stream; `load(PlaybackSource, PlaybackIntent)`, `play`, `pause`, `seek`, `teardown`. The YouTube adapter accepts only `.youtubeVideo`, never calls `StreamResolver`, and owns a visible IFrame view handle. P1 owns this implementation. P4 owns the coordinator and decides when it is attached to UI.
- `PlaybackCoordinatorProtocol` is `@MainActor`, owns the sole audible adapter, exposes snapshot and `load/play/pause/seek/skip`. Every async command/event carries queue generation; stale results cannot overwrite a newer source or user intent. Pause during buffering remains the final intent. `ended` is accepted once per generation.
- `StreamResolver` and `ResolvedStream` are **conditional P5-only** ports for licensed native media. They must not appear in the public YouTube composition graph. No `URL` is synthesized for IFrame.
- Persistence repositories operate on snapshots/IDs, not SwiftData objects across actor boundaries. Migration preserves favorites, imports, notes, playlists, history, queue and settings; failure preserves a recoverable source store and never silently clears user truth.

## Ownership for concurrent branches

| Phase | Owns files/directories and outputs | Must avoid / handoff |
| --- | --- | --- |
| P1 | New `Platform/iOS/YouTubeIFrame/` (or `Sources/Muses/Platform/iOS/YouTubeIFrame/` until extraction), its adapter tests and P1 device evidence | Do not edit `Packages/MusesCore`, `Persistence`, Data API/OAuth, or the shared composition root. Supply an adapter factory and demo harness; P4 wires it into production after integration. Do not preserve native stream fallback. |
| P2 | New `Packages/MusesDomain/`, `Packages/MusesQueue/`, `Packages/MusesPersistence/` and migration/contract fixtures; mapping from legacy `Sources/Muses/Domain`/`Persistence` | Do not edit IFrame, OAuth, Data API, `MainTabView` or app composition. Publish compiling package products and mapping API before integration. |
| P3 | New `Packages/MusesCatalog/`, `Packages/MusesNetworking/` and `Platform/iOS/OAuth/` (or corresponding temporary `Sources/Muses/Services/YouTube` subfolders), fake HTTP fixtures, quota log and account data-deletion contract | Consume P2 ID/page contracts. Do not edit playback, queue state, `MainTabView` or app composition. Explicitly isolate legacy Innertube; no media URL resolution. |
| P4 | `Sources/Muses/App/AppComposition.swift`, `Sources/Muses/App/MusesApp.swift`, `Sources/Muses/Features/` shell/Now Playing/library/queue UI, design tokens; integration tests | Integrate P1/P2/P3 products and public capability policy. Own cross-branch Xcode project/project.yml wiring and resolve generated-project edits once, after package interfaces settle. |

Shared `project.yml`, `Muses.xcodeproj/project.pbxproj`, `README.md`, `Info.plist` and entitlements have one integration owner (P4/P6 as appropriate). Early P1/P2/P3 branches should document required changes rather than independently edit them. macOS `/Users/xiaotwu/Code/Muses` is read-only for P1–P4; P7 owns its migration. Never reset source-tree dirty files to make merges easy.

## Integration sequence and readiness

P1, P2 and P3 can start **in isolated branches/worktrees now** using this revision. P2 should publish the first compilable Domain package and contract tests early; P1/P3 may use private temporary types in their own modules until that product exists, then map at the boundary. The common API becomes source-frozen at P2's first reviewed package tag/commit. P4 starts production wiring only after P1 adapter events, P2 ID/queue/persistence contracts and P3 catalog/auth pages compile together. No phase may mark public release readiness before P6.
