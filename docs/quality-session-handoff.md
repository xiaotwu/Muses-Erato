# Session/library/playback handoff

Implemented 2026-09-29. No commits, UI edits, project-manifest edits or external account changes in this workstream.

## Owned paths and allowlist

Existing composition/session: `Sources/Muses/App/PublicYouTubeApp.swift`. **New Public + Native source:** `Sources/Muses/App/PublicSessionControllers.swift` (coordinator/test stream adds allowlist). It contains independent library projection, operation state, checkpoint controller and process-shared device budget composition. Regression additions/updated expectations: `Tests/MusesTests/PublicYouTubeFlowTests.swift`. No persistence schema changes; existing transactions and migration protections are reused.

## Library semantics

`libraryTracks` contains all saved video Track references. Persisted Track records are created by explicit open/enqueue/import or migration. Catalog search/account display caches never create Track records; cache alone never enters Library. No new saved marker or speculative migration is needed.

`libraryFavorites` and `libraryHistory` are independent of playlist membership. UI history is newest-first and unique by video; every confirmed history record remains persisted until explicit history clear or saved-video deletion. Opening never creates confirmed history. Current player/video/generation identity guards remain enforced.

Clear scopes:
- Videos atomically deletes saved references plus favorite/history/notebook/queue/playlist memberships; playlist containers survive.
- Playlists removes containers only, retaining saved videos/favorites/history.
- Favorites atomically clears favorite flags/legacy records, retaining fresh display metadata in memory.
- History atomically removes every confirmed history record.
- Existing archive/deletion-journal/original-restore protection remains intact. Current-video deletion cancels pending status checks and resets checkpoint/player state.

## UI contract

Error aliases: `libraryFailureMessage`, `playbackFailureMessage`, `accountFailureMessage`, `metadataFailureMessage`, `deletionFailureMessage`. Short aliases `libraryError` etc also exist. Compatibility `failureMessage` remains; UI should use scoped values.

Settings uses `accountOperation`, `metadataRefreshOperation`, `localDataDeletionOperation` (`PublicOperationState`: isRunning, message, error, pendingRestart). Account running covers sign-in/sign-out/cleanup retry; metadata covers playlist-name/video metadata work; deletion covers active cleanup, with pendingRestart after incomplete cleanup or retained migration-file cleanup. Metadata refresh guards duplicate work before its first await. Unrelated operation success leaves other scoped errors intact.

Playback:
- `canRetryPlayback`, `retryPlayback()` recheck content status on an attached player. Restrictions remain enforced; request/player/queue/account identity fences discard stale responses. Detached surfaces first attach a new adapter.
- `playbackCheckpoint.failure`, `.pending`, `retryPlaybackCheckpoint()` expose failed saves and explicit retry.
- `checkpointPlayback(force: true)` is the lifecycle hook; UI now invokes it on scene inactivity. Time events use force false and save at most once per 15 seconds, including failed attempts. Pause/detach save immediately. Local defaults diagnostic keys: playbackCheckpointFailure and playbackCheckpointFailureDate.
- Cold restart restores queue/position paused, without automatic media load/playback. Attach rechecks status before preparing saved position. Native fresh selection/explicit Play retain autoplay; cold restoration remains paused.
- Initializer seams `checkpointNow`, `beforeQueueSave` enable deterministic throttle/failure tests without replacing repository transactions.

Search: read-only `submittedSearchQuery`, `submittedSearchKind`, `hasSubmittedSearch`; `searchSaved(_:)` submits saved-video search without catalog requests; `search(_:)` submits YouTube plus matching local videos; `retrySearch()` preserves submitted query/kind/scope despite edited fields; `nextSearchPage()` is a no-op for Saved scope; `clearSearchResults()` restores idle. Local playlists remain available through `playlists`. Scoped search error is `searchError`. Result deduplication now uses a Set of row identities.

Home: `loadHomeAccountPlaylists(refresh: Bool = false)` fetches one initial page, skips loaded/in-flight work, resets only accountPlaylistPages on refresh, and neither fetches subscriptions nor drains continuations. Explicit More calls `loadAccountPlaylists()` for one next page. The latter checks account epoch/sign-in/deletion after await alongside pager generation fencing. Settings/import retain `loadAccountCollections()` full-page behavior.

## Networking composition

Persistent RequestBudget is integrated via PublicDeviceRequestBudgets: one actor per URL shared across session/catalog recreation. Production uses `Application Support/MusesDevice/device-request-budget.json`, outside account/library deletion. Explicit test stores use unique sibling budget files; UI test UUIDs each have their own sibling path. Catalog overrides/fixtures bypass production budget construction. Corrupt initialization surfaces metadataFailureMessage and blocks online service construction, without silent memory-reset fallback. Local/server quota messages come from Networking.

## Validation

**Integrated Public app compiled; 27 selected application regressions passed, zero failures.**

Generated project `.artifacts/session-recovery/MusesPublic.xcodeproj`, unit-only scheme MusesSessionRecovery. It builds the integrated production app and complete MusesTests bundle without requiring concurrently edited UI-test sources. Selected suites: PublicYouTubeFlowTests, PublicLocalLibraryFlowTests, PublicSongMetadataTests.

Reserved simulator Muses Session Recovery, iPhone Air/iOS 26.5: A56CA8C7-5D13-4A53-AA3B-D35823B45A22; separate from coordinator/CI devices.

```sh
xcodebuild -project .artifacts/session-recovery/MusesPublic.xcodeproj \
  -scheme MusesSessionRecovery \
  -destination 'platform=iOS Simulator,id=A56CA8C7-5D13-4A53-AA3B-D35823B45A22' \
  -derivedDataPath /tmp/muses-session-recovery-dd \
  -resultBundlePath /tmp/muses-session-recovery-tests-8.xcresult \
  -only-testing:MusesTests/PublicYouTubeFlowTests \
  -only-testing:MusesTests/PublicLocalLibraryFlowTests \
  -only-testing:MusesTests/PublicSongMetadataTests test
```

Log `/tmp/muses-session-recovery-test-8.log`; result `/tmp/muses-session-recovery-tests-8.xcresult`.

Coverage includes independent saved/favorite persistence after playlist clear, display cache exclusion, confirmed history across relaunch without playlist membership, throttle, periodic/pause/detach failures and explicit retry, simulated process loss before lifecycle save, restored position/paused intent, restored seek request bound to checked generation, transient status retry with restrictions enforced, operation error isolation, submitted local search identity/no network calls, budget actor sharing and visible corrupt-budget failure. Existing metadata placeholder assertion follows current “Video details unavailable” Domain terminology.

Owned-file git diff --check passed. This run does not claim UI screenshots/real iframe media playback, real OAuth, full Native playback or package-network validation; coordinating streams own those integration checks.

## Queue feedback follow-up

`queueFailureMessage` is now an independent `.queue` operation error. editQueue reports unavailable-store/save/mutation failure there and publishes proposed queue only after a successful save; a successful subsequent edit clears only queue error. `libraryFailureMessage` and `playbackFailureMessage` present queueFailureMessage first, then their underlying scoped error, so existing Home/Library/Player notices immediately show failed edits without destroying content-check/checkpoint/library errors. Raw libraryError/playbackError remain unchanged. Queue and catalog/search detail surfaces may read queueFailureMessage directly; shared UI ownership remains with UI/coordinator.

Search submitted source is now exposed as read-only `isSubmittedSearchLocal`, backed by the existing private submittedSearchIsLocal; UI should use it instead of a view-local submittedScope so rebuilding the view preserves Saved search identity. clearSearchResults resets the source flag.

Follow-up regression evidence: integrated Public build and **28 selected tests passed, zero failures** using the same unit-only scheme and simulator. Latest log `/tmp/muses-session-recovery-test-9.log`, result `/tmp/muses-session-recovery-tests-9.xcresult`. New deterministic failed-editQueue test injects write failure, verifies unchanged in-memory and persisted snapshots, confirms Home/Library/Player alias visibility, preserves the underlying content restriction, retains queue error through unrelated library success, and clears it only after a successful committed queue edit. Saved search test additionally verifies isSubmittedSearchLocal persists and resets on Clear. Owned-file diff check passed.

Coordinator has been messaged with the new queue/source APIs and UI integration locations. Player recovery actions must only accompany actual playback errors; queue-save notices should not offer content-status retry. Queue/VideoDetail currently retain legacy global error fallback; Search/catalog direct queue notices are UI stream work. Other legacy-global boundaries (restoreOriginalPlaylist, some metadata expiration/link validation flows) remain intentionally outside this narrow follow-up.
