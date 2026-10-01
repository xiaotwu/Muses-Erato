# Content classification interface — 2026-09-30

Interface reserved for player integration: `Track.contentKind: Track.ContentKind?`, `CatalogItem.contentKind: CatalogItem.ContentKind?`; both nested raw String enums expose `.music` / `.video`. Nil means unknown; default player presentation is Video. Use `Track.ContentKind(rawValue: item.contentKind.rawValue)` to map across package boundaries without adding a Catalog-to-Domain dependency.

A fresh, single-request `catalog.videoPlaybackMetadata(id)` will return `VideoPlaybackMetadata` with `embeddingStatus`, `contentKind`, and `fetchedAt`. The existing `videoEmbeddingStatus(id)` remains compatible and delegates to the same method. Player owner should replace its status call with this metadata call, rather than making a second request; only a unique matching video supplies classification. No title/channel/Topic heuristics.

Classification and player integration are implemented. The ownership notes below record the narrow interfaces used by the workstreams.

Minimal interface implemented now. The concrete type spelling is `MusesDomain.Track.ContentKind` and `MusesCatalog.CatalogItem.ContentKind` (independent nested enums; map by rawValue). Production initialization remains source compatible via trailing defaulted `contentKind: nil`. `videoPlaybackMetadata` is available now and returns classification with the existing fresh embedding permission check. Player owner owns the replacement call in `loadCurrent` and any open/enqueue argument forwarding; UI owner can pass CatalogItem classification if desired, but missing search category remains unknown until the existing playback lookup.

## Implemented mapping and lifecycle

- Domain Models.swift: optional Codable `Track.contentKind` with default nil, older Track JSON decodes unchanged. YouTube classification is removed by `localPersistenceSnapshot`, including tracks with user-authored display titles. Expiry/force clear removes classification while preserving user-authored fields and collection relationships.
- Catalog.swift: categoryId `"10"` maps to Music; other positive integer category identifiers map to Video. Missing/null/invalid/wrong-typed category fields return nil. Nonvideo catalog items do not classify. No title, artist or Topic inference.
- `VideoPlaybackMetadata`: `embeddingStatus`, optional `contentKind`, `fetchedAt`; one fresh existing `id,snippet,status` request; wrong/duplicate/missing video IDs yield unknown permission and nil classification. Existing `videoEmbeddingStatus` delegates for compatibility.
- PublicYouTubeApp.swift: narrow additions in `hydrateDisplayMetadata`, `refreshSavedMetadata`, `saveImportedPlaylist` copy category by rawValue during the existing metadata application. Unknown category clears previous classification on these refresh paths. No edits in search ownership range or queue selection/status-check ownership range.

## Verification

Commands completed on host macOS with isolated scratch paths:

- `swift test --package-path Packages/MusesDomain --scratch-path /tmp/muses-quality-content-domain`: **12 passed**.
- `swift test --package-path Packages/MusesCatalog --scratch-path /tmp/muses-quality-network-catalog-build`: **34 passed**.
- `swift test --package-path Packages/MusesPersistence --scratch-path /tmp/muses-quality-content-persistence`: **40 passed** (existing deprecated-import warnings).

New tests cover legacy Codable compatibility; API classification expiry/force clear/local snapshot; preserving user title/favorite; exact category parsing with missing/invalid/nonvideo cases; no title/Topic inference; single-request playback metadata and unmatched/duplicate IDs; classification absent from reopened durable payload including user-title tracks.

Updated app integration tests (passed in the final coordinator-owned Public 61 / Native 63 unit runs): `PublicLocalLibraryFlowTests.testSavedMetadataRefreshUsesBatchesAndPreservesUserTitles`, `PublicSongMetadataTests.testColdQueueAndHistoryReferencesHydrateSongNameAndCreatorWithoutChangingMembership`, `PublicPlaylistImportTests.testImportedTitlesVisibleInMemoryButAbsentFromStoredPayload`. They assert classification mapping with unchanged batch count and no classification in saved tracks.

Completed player integration consumes `videoPlaybackMetadata` in place of the status-only call, maps its contentKind to the current Track, treats nil as Video and keeps user mode override separate. Classification is not a permission grant. No commits or pushes by this workstream.
