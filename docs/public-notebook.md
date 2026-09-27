# Public video notebook

Branch: `codex/public-notebook`, based on integration `be57df9`. Root keyboard fix `d1c7977` is carried as prerequisite cherry-pick `3164b39`; it is not a new notebook change. Startup migration, Discover/Search/Account and Library category layout are unchanged. `PublicNotebookViews.swift` and `PublicNotebookModel.swift` are explicit public target entries; regenerate the Xcode project after combining allowlists from concurrent work.

## User behavior

Video details contain local notes and time bookmarks. Both lists support create, edit, individual confirmed deletion, and separately confirmed clear-for-this-video. Clear is visible but disabled for an empty list. Add/edit/delete/save/cancel controls use icons and accessibility labels; editable fields and destructive confirmations retain text. Draft sheets close only after a successful save; failed saves/deletes/clears retain existing content and show an error. Time edits reject negative, nonfinite and nonrepresentable positions.

The player can capture a bookmark at its latest accepted current-video clock. The action is disabled until a current-video time event exists, captures that value once, and pauses before presenting its editor. Selecting a bookmark opens the visible IFrame and waits for the matching ready event. A request belongs to a queue occurrence, video ID, adapter instance and generation. Close, failure, normal open and Next cancel obsolete requests; duplicate/stale ready callbacks cannot reposition another video.

YouTube documents that `seekTo` starts a cued video. The ready-only bookmark command therefore uses `seekTo` only for an already paused player; otherwise it uses `cueVideoById` with `startSeconds`. It never issues `playVideo`; the user must choose Play. Reference: [official IFrame API](https://developers.google.com/youtube/iframe_api_reference). No background mode, media stream, unofficial endpoint or hidden playback is added.

## Persistence and migration contract

- Domain types are `VideoNote` and `VideoTimeBookmark`, avoiding legacy SwiftData `TrackNote` / `TrackBookmark` names.
- `.note` stays wire-compatible with `LegacyNote`: UUID `id`, `trackId`, verbatim `content`, original `createdAt`, edited `updatedAt`.
- `.bookmark` stays wire-compatible with `LegacyBookmark`: UUID `id`, `trackId`, Double `timestampMs`, optional `title`, optional `note`. Millisecond fractions and unchanged nil/empty distinctions are retained.
- Explicit adapters read legacy projections. Edits merge known fields into the original V1 payload, retaining unrecognized additive fields (including an optional projected bookmark `createdAt`). Unknown payload versions are rejected, and failed saves roll back.
- Original `.legacyModel` archives and `.migration` receipts are immutable source-import evidence and are never changed by notebook edits/deletions. A full-import receipt is a receipt for the original source, not a digest of the subsequently edited live notebook. Do not rerun `importLegacyComplete` to validate edited projections: its preexisting idempotency check intentionally detects differences. Startup migration integration must distinguish a completed migration from a fresh import; this work does not alter that integration.

### Saved-video deletion integration

`SwiftDataSnapshotRepository` offers:

- `deleteVideoNotes(trackID:)` / `deleteVideoBookmarks(trackID:)`: clear one list for one video in one save, rollback on failure.
- `deleteVideoNotebook(trackID:)`: standalone clear of both projection lists in one save, rollback on failure.
- `stageVideoNotebookDeletion(trackID:)`: validate first and mark only matching `.note`/`.bookmark` rows for deletion **without saving**. Use this inside the owner’s saved-video deletion operation, then save track/playlist/queue/notebook changes together; roll back the context if any step fails. Do not call the standalone saving convenience halfway through a larger deletion operation.

After the owner's transaction commits, call `session.notebook.forget(trackID)` (or `reset()` for an all-library reset) to invalidate notebook UI snapshots. These helpers do not remove the saved track itself, source SQLite, migration receipts, `.legacyTrack` or `.legacyModel` recovery archives.

## Verification

Tests run on a dedicated simulator `Erato-Notebook-iPhone` (`1C58A5F6-6867-4BA3-9A14-AF17AEB07BB7`, iPhone 17e, iOS 26.5), not the integration owner's simulator.

- Domain: 5 tests passed, including time validation and edit identity.
- Persistence: 23 tests passed, including legacy projection edit/reopen/delete, preserved extra fields, ownership/future-version rejection, immutable migration receipt/archive, staged deletion rollback and scoped list clearing.
- App unit tests cover rejected write/delete/clear snapshots, ready-before-bind, wrong generation/entry/video, retry, duplicate ready, cancellation, stale adapter-instance callbacks and session disk reopen.
- `node Tests/YouTubeIFrame/bookmark-command.test.cjs` executes the shipped JavaScript command bridge against a player spy. It verifies paused seek versus cue, no play command, invalid-time rejection and stale-generation rejection without live networking.
- UI coverage: one-tap note/bookmark save, CRUD, relaunch persistence, bookmark route and visible player, scoped clear/cancel/empty disabled states. Final results are appended after verification. Earlier UI runs exposed offscreen alert anchoring and a zero-size icon action; these were fixed rather than counted as passes.

Commands:

```sh
swift test --package-path Packages/MusesDomain
swift test --package-path Packages/MusesPersistence
node Tests/YouTubeIFrame/bookmark-command.test.cjs
xcodebuild -project Muses.xcodeproj -scheme Muses \
  -destination 'platform=iOS Simulator,id=1C58A5F6-6867-4BA3-9A14-AF17AEB07BB7' \
  -derivedDataPath /tmp/erato-notebook-build \
  -only-testing:MusesTests -only-testing:MusesPublicUITests/PublicNotebookUITests test
```

Real-device verification of the actual YouTube seek/cue response, keyframe placement, unavailable/private videos and current-time bookmark capture remains necessary. Simulator navigation and the deterministic command tests do not establish those live outcomes. Notes/bookmarks are local and do not sync to a YouTube account.

Final verification (2026-09-27): 11 App unit tests passed (including clear failure-state checks); the complete notebook UI test passed with CRUD, one-tap Save, scoped clear/cancel/disabled state and two relaunches. Result: `/tmp/erato-notebook-build/Logs/Test/Test-Muses-2026.09.27_16-54-44--0700.xcresult`. Final Release simulator rebuild and `scripts/audit-public-artifact.py` passed against `/tmp/erato-notebook-release/Build/Products/Release-iphonesimulator/Muses.app`; this remains an unsigned simulator artifact, not a signed archive verification.
