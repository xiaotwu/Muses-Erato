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

## Playback command acknowledgement follow-up (2026-09-30)

QA reported delayed play/pause feedback. Inspection found: the toggle used only the last confirmed state, so repeated Play taps before Playing would resend Play; host pause optimistically assigned Paused without iframe confirmation; JavaScript dispatch failures were discarded; a sticky host-pause flag kept intercepting later Playing from the iframe's own controls. The code had no intentional play/pause delay. External command execution and media-state confirmation remain asynchronous.

Implemented independent PublicPlaybackCommandController (existing source file, no new production allowlist entry). Its pending Request contains action, UUID and player generation. Dispatch success never means Playing/Paused; only matching real iframe events settle pending state. Rapid taps while pending cannot issue duplicate/conflicting commands. An eight-second confirmation deadline or dispatch failure produces a separate command error and explicit control-action retry without changing content restrictions, confirmed state or checkpoint error. Old dispatch callbacks/deadlines cannot affect a new request. Load, video switch, detach, failure and inactivity cancel pending work.

Player UI changes are local apply_patch edits in playerDetails after line 700; Home/Search layouts were untouched by this stream. APIs: togglePlayback(), playbackCommands.pending/failure, isPlaybackCommandPending, playbackToggleLabel, canRetryPlaybackCommand and retryPlaybackCommand(). Accessibility IDs: public.playbackToggle, public.playbackCommandPending, public.retryPlaybackCommand. Pending progress/Play requested/Pausing is separate from public.playbackState, which remains confirmed state.

suspendVisiblePlayback() resets pending work, actively pauses Public and saves pause intent without assigning confirmed Paused. Native only checkpoints. Coordinator wired RootView's actual inactive scenePhase branch to this API. Adapter still enforces foreground-only playback; foreground return never issues Play. Background suppression and unconfirmed host pause are independent; a foreground transition preserves an unacknowledged pause guard, while real Paused/cued or explicit Play/timeout cancellation ends the guard. Actual Playing also updates state.intent.

Adapter JavaScript play/pause returns a dispatch acknowledgement. Swift handles failure rather than swallowing it; acknowledgement does not synthesize playback. When the real player is already in the requested state, a getPlayerState() observation can emit that actual state without awaiting a nonexistent state transition. Existing ID/generation/origin/frame fences apply. onAutoplayBlocked directs users to visible iframe controls, retains generation/action metadata to clear its notice on later actual Playing, and does not offer an automatic retry or change autoplay/permission policy. Official semantics: https://developers.google.com/youtube/iframe_api_reference#Events . Completion handling stays inside the MainActor adapter; no raw Any/Error values are passed across actors. SDK 26.x compatibility remains for remote CI to confirm.

### Final validation and provenance

- **33 selected Public unit/flow tests passed**, zero failures: /tmp/muses-session-command-unit-2.xcresult; log /tmp/muses-session-command-unit-2.log. New deterministic cases cover rapid taps, dispatch ack not being playback, opposite/stale confirmation, timeout/retry/stale callbacks, blocked playback notice cleared by real Playing, background and foreground-before-pause-ack policy, and session host pause not forging Paused. Previous library/checkpoint/queue/search regressions remain passing.
- Standalone iframe contract checks passed: swiftc of YouTubeIFrameContract.swift plus Tests/YouTubeIFrameTests/ContractChecks.swift, binary /tmp/muses-session-iframe-contract. Added blocked-event origin/frame and stale-generation checks.
- **1 opt-in real service test passed, zero failures, zero skips**, using real external iframe events and no catalog/media fixtures: /tmp/muses-session-command-live-2.xcresult; log /tmp/muses-session-command-live-2.log. New file Tests/MusesPublicUITests/PublicLivePlaybackCommandUITests.swift is automatically included by the test directory source rule, defaults to XCTSkip without MUSES_RUN_LIVE_SERVICE_TESTS=1. It performs three actual Play/Pause cycles and then Playing -> press Home -> activate -> actual Paused, checking no unsolicited auto-resume. This tests the actual Root scenePhase entry, not just a directly called lifecycle method.
- Simulator A56CA8C7-5D13-4A53-AA3B-D35823B45A22, iPhone Air / iOS 26.5. Integrated Public build used original app identifier and the existing private xcconfig path, with no external account changes or credential values copied/printed. Generated live scheme passes the opt-in variable through its test environment; xcresult confirms the test executed rather than skipped.
- Source fingerprints before/after the final real run are unchanged for session/controllers/iframe/Root/player tests: .artifacts/session-command-live/final-source-start.json, final-source-end.json, final-source-changes.json (empty array). Summary and retained timing attachment: .artifacts/session-command-live/final-live-summary.json and attachments/.
- Observed real Play confirmation times: 1.631s, 1.555s, 1.583s; Pause: 1.600s, 1.777s, 1.694s. These include XCTest interaction/idle/predicate polling and are **not** pure media latency measurements. Pending feedback is immediate; no claim that external media confirmation was sped up.
- Owned-source/test diff check passed. Existing PublicLiveServiceUITests.swift helper changes remain owned by UI stream; this stream did not edit it. No Git commit or publication performed.

Post-validation UI consistency review: updated only the Player icon condition to playing OR buffering, matching the already-validated toggle action and accessibility label. Pending remains disabled with separate progress. This one-line visual correction followed the frozen real test above; a fresh configured Public build passed (`/tmp/muses-session-command-icon-build.log`). It does not change the dispatch/confirmation/lifecycle logic covered by the 33+1 tests. Prior freeze records remain evidence of that real-test run, not a claim that Root is unchanged after this later icon correction.

## Queue relocation checkpoint — paused at user request (2026-09-30)

Latest requested scope: remove global navigation Queue, place a single-hop Queue button in player controls, retain discoverability through MiniPlayer. Implemented through local apply_patch only:

- Library toolbar Queue removed. Home/Search toolbar removals belong to UI stream and their calls are now absent; unused queueToolbar helper removed.
- PublicWebPlayer controls include 44pt player.queue. Control-row spacing is 16 to accommodate the extra target on smaller widths.
- Shared PublicQueueControl (existing Root source, no new production allowlist) is a 44pt Button -> local Queue sheet, no extra menu step. Queue page retains its existing Clear Up Next confirmation and scoped deletion behavior. Close Queue uses player.queue.close, so it does not conflict with the list's Edit/Done control.
- Public MiniPlayer keeps the cover/title's player.mini.open region plus Queue/public.queue and Next; removed its duplicate apparent Play/Pause control that only opened the player. Native MiniPlayer keeps its real Play/Pause plus Queue and Next; Native full-player Queue entry/sheet remain.
- Both fallback/split layouts and iOS26 tabViewBottomAccessory include queued-only state (hasNext without current). Queued-only title is Up next; Next's accessible label is Open queued video and explicitly promotes the first queue entry then opens the visible player for content verification, without synthesizing Playing or adding autoplay.
- Added optional PublicQueueView.onOpenPlayer callback. Shared Queue control first dismisses its sheet, then onDismiss requests Now Playing; when already in the player it simply closes Queue. Native's existing Queue sheet uses its callback to return to its player. This addresses the new sheet-versus-fullScreenCover collision risk.
- New directory-included test: Tests/MusesPublicUITests/PublicQueuePlacementUITests.swift. Existing Smoke queue adapters were locally updated to direct sheet entry (no Open Queue menu tap), the selected Smoke method did not execute; see test-selection limitation below.

### Last allowed check completed

Current minimal command finished; no further checks started after pause instruction. Public app/UI bundle compiled and three Queue placement tests actually executed on the dedicated iPhone Air/iOS26.5 Session Recovery simulator. **2 passed / 1 failed / 0 skipped**. Maximum Dynamic Type bounds/navigation and queued-only entry/promotion passed. Ordinary placement reported a strict floating-point bounds assertion at test line 26: actual height 43.99999999999994 compared with 44.0. No other assertions failed, but this is an overall failed run, not a layout acceptance pass. The nominal 44pt target needs an appropriate pixel/tolerance comparison in the next authorized turn.

The requested Smoke method selection executed **zero** methods (class suite present). Current source still contains the requested method name; the cause of the selector/built-bundle mismatch is unverified and should be inspected next turn before revalidation. The running test binary predated the later Queue->Open visible player dismissal callback/test assertion changes. Those latest presentation changes are saved but not claimed verified.

Result: /tmp/muses-session-queue-placement-1.xcresult; log: /tmp/muses-session-queue-placement-1.log; machine-readable summary: .artifacts/session-queue/validation-summary.json. Current saved source hashes: .artifacts/session-queue/paused-source-freeze.json. Owned UI/test diff check passed. No new production playback command/session/iframe logic changed during this Queue relocation.

Pending after resume: compile latest callback version, fix only the bounds precision assertion, exercise MiniPlayer -> Queue -> Open visible player against actual player presentation, reselect Smoke clear/reorder/delete adapters, and verify Native MiniPlayer geometry plus narrow-screen bounds. No real iPhone tests were run. No new live, iPad or full regression was started after the pause request.

Two dedicated additional simulators were created before pause, but no test/build was started against them: Muses Queue Native D13684D7-CFE9-4DF3-95B0-42B25B4A76E5 and Muses Queue Narrow 3CE2AD8E-BA69-4268-AE55-5242E1975B68. Native project generation failed because its output directory had not been created; this was not retried after pause. No commits/push/publication/account changes performed. Work is paused awaiting user instruction.

## Queue relocation resumed — final targeted validation (2026-09-30)

The pause was lifted for latest-source targeted Queue checks and Native mini geometry. Production Root/player sources stayed frozen throughout this resumed work. Tests received only a 0.000001pt tolerance for AX floating-point representations of 44pt and a Native helper fix that caches the valid mini-player frame seen by its wait predicate before tapping its center. This avoids a subsequent transient empty AX-frame read after Settings dismissal; real Native controls still must appear.

- **Public: 4 executed, 4 passed, 0 failures.** PublicQueuePlacementUITests (3) plus PublicLocalLibraryUITests/testClearUpNextFromMiniPlayerAndPlayer (1). Result `/tmp/muses-session-queue-placement-3.xcresult`; log `/tmp/muses-session-queue-placement-3.log`. Covers direct full/mini Queue sheets, 44pt bounds and separate cover/title open region, maximum Dynamic Type, queued-only Library entry/promotion, mini Queue -> Open visible player -> actual iframe surface, and confirmed Clear Up Next. The earlier zero-method Smoke selection was my wrong class name: this method belongs to PublicLocalLibraryUITests, not PublicSmokeTests.
- **Native: 1 executed, 1 passed, 0 failures.** PublicNativePlayerUITests/testNativeControlsMinimizeAndCloudSyncConfirmation. Result `/tmp/muses-session-queue-native-geometry-2.xcresult`; log `/tmp/muses-session-queue-native-geometry-2.log`. Uses fixture catalog/generated silent audio; confirms full Native controls, mini above tab bar, Queue >=44pt/on-screen/no title-region overlap, direct Queue sheet, and return to actual Native player. Screenshots retained as xcresult attachments.
- First Native run recorded one failure in the preexisting post-wait mini.open empty-frame helper assertion; its Queue assertions and later Native controls passed. That run hung after test-suite completion and my own xcodebuild process was terminated. `/tmp/muses-session-queue-native-geometry-1.log` is diagnostic evidence, not a passing/fully finalized result. The helper was fixed and the second run completed successfully.
- The old Session simulator had been removed; initial resumed destination lookup failed without tests. Recreated dedicated **Muses Session Recovery, DB72AE01-F026-4B37-984B-83014818984D**, iPhone Air/iOS26.5; all resumed runs used it. Native generation required an ignored isolated specification to resolve Info.plist paths relative to the generated project directory. Shared project manifests were not edited.
- Source evidence: `.artifacts/session-queue/resume-source-start.json`/`resume-source-end.json` were identical before the Native helper correction; `.artifacts/session-queue/final-source-start.json`/`final-source-end.json` are identical for the final Native run (`final-source-changes.json` is empty). `resume-validation-summary.json` records final counts. Owned-source/test diff check passed.

No resumed live-service, physical iPhone, iPad, separate narrow-screen simulator, or full regression test was performed. These targeted iPhone Air checks do not claim those validations; coordinator retains physical QA/integration ownership. No production playback/session/iframe logic changed during resumed validation, and no Git commit/push/publication was performed. Queue workstream targeted validation is complete; production freeze remains in effect.
