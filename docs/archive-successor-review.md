# Runnable archive successor — engineering review, not destruction approval

Base: `c754fff` (integration including lifecycle ADR 0006). Branch: `codex/archive-successor`. This extends [ADR 0006](adr/0006-archive-provenance-lifecycle.md) with an executable candidate and an external activation barrier. It does not enable automatic retirement of originals or close P6-ARCHIVE.

## Evidence and preserved data

[archive-source-contracts.json](archive-source-contracts.json) pins the reviewed old models, service writers and editor source by SHA-256. The process proof checks those hashes before running. `LegacyUserFieldContracts` recognizes only note `content` and bookmark `title`/`note` as user input. Model UUIDs, owner relationships, creation/edit timestamps and selected bookmark position are retained as local structural/interaction data, not relabeled API content.

- `NotesService.setTrackNote` writes the dedicated note field; `TrackNotesSheet` presents the note TextEditor. The historical sheet in this snapshot does **not** itself call `setTrackNote`; this review does not invent a working historical autosave path. There is no production remote-data writer to `TrackNote.content` in the inspected source. Existing persisted dedicated note content is preserved. Public notebook editors/repository own subsequent edits.
- `NotesService.addBookmark` / `updateBookmark` receive title/note text from the optional title field and edit sheet. The fields are not filled from the video title. The original `createdAt` value omitted by the earlier compact bookmark adapter is carried forward for a still-present bookmark; current payload timestamps take precedence. Deleted bookmarks are never reconstructed for this purpose.
- The `Playlist` model's “created manually” comment is insufficient evidence for its name: `YouTubePlaylistSyncService.restoreAsCopy` writes `snapshot.title` into a detached local playlist. Therefore all old unproven names stay unresolved. The session accepts an explicit `nameIsExplicitUserInput` argument before it calls `saveUserNamedPlaylist`, which saves both the name and a matching name digest in one save. Generic `createPlaylist`/`editPlaylist` calls default to false: neither an automatically filled import name nor a changed string proves user authorship. The integration owner must connect this explicit flag only to actual manual naming controls, alongside the catalog branch’s remote-title provenance contract; this branch does not change `PublicRootView` call sites. Reorder/add/remove and archive restore do not attest a name. An unproven later name change invalidates the digest. Existing names without evidence become **Recovered playlist** in the candidate; original bytes remain in protected copies for user review.
- Current track IDs/playback sources/provenance, favorites, history IDs/dates, playlist membership and repeated occurrence IDs/order/unavailable slots, queue entry IDs/order and playback position are carried as operational relationships. Explicit `.user` track display edits survive. API/unknown display fields use existing placeholders; there is no new fetch date. Queue context strings and raw queue JSON are not copied. This does **not** classify video IDs, provider references or history as user-authored text or establish a retention exemption for them.
- The current mutable note/bookmark/playlist projections are the authority. User edits and deletions win over old originals. Surviving legacy playlist pin choices are recorded in successor identity metadata; the present public UI does not provide a pin editor. The candidate does not silently backfill any deleted entity from archives.

The archive sheet identifies an activated successor as a reviewed library with retained original files. It shows the preservation record and does not offer an empty export falsely described as a complete original archive. Original-file retirement review still needs the separately retained parent and concrete file manifest.

The successor contains no `legacyTrack`, `legacyQueue`, `legacyModel`, import/sync/revision payloads or archived settings. Unrecognized notebook additions are not treated as proven input; their originals remain retained. Orphan note/bookmark owners and unmapped staged field exclusions fail preparation instead of dropping content. Supporting those cases requires a reviewed orphan/exclusion representation before their libraries can activate a candidate.

`RunnableArchiveSuccessor.records` is a typed, runnable preservation projection, with a separate versioned `SuccessorIdentity`. The historical `legacy-complete-v1` receipt is copied unchanged as lineage. Its count/hash still describe the old complete import, never the smaller candidate. The successor has its own initial content digest, parent digest, source-contract references, excluded original entity keys, unresolved-name IDs and preserved pin values. These linkable identifiers/digests are not claimed to be anonymous or policy-exempt.

## Activation, editing and restore behavior

`PublicArchiveSuccessorRouter.prepareAndActivate` is an explicit engineering API used by disposable fixtures/harnesses. No startup, timer or UI handler invokes it automatically. A freshly generated candidate is restored using `installRunnableArchiveSuccessor` into a **pristine** repository, committed, reopened read-only and compared payload-for-payload to the plan. It runs through the existing `PublicYouTubeSession` and repository; hosted tests edit notes, rename playlists and enqueue repeated occurrences through current public behavior.

| Boundary | Authority / failure behavior |
| --- | --- |
| Before intent | Existing verified public route |
| `successor-pending.json` | Binds the old generation UUID and exact logical projection digest. Normal startup refuses fallback until explicit retry resolves preparation. Originals and partial candidates stay intact. |
| Candidate save / independent verification | Fresh UUID store; failure or SIGKILL does not mutate the parent. Retry uses a fresh candidate, only if the bound parent is unchanged. |
| Before activation | Recheck parent projection digest, sync candidate main/WAL and directory. A parent edit during preparation blocks publication. |
| `successor-active.json` | Atomic fsynced external pointer containing successor identity; takes priority over old pending/active migration routes. Missing, corrupt or unknown-version successor fails closed. No reimport. |
| Subsequent public edits/deletes | Current generation is mutable. Initial preservation records are never replayed. Identity/receipt and current typed graph are validated without comparing edits against the frozen initial digest. |
| Explicit whole-app deletion | Existing `deleted.json` takes precedence. After the authorized restart cleanup, old successor control files are removed along with obsolete generations. |

Current app restoration entry points are guarded: `restoreOriginalPlaylist`, complete and deprecated legacy imports, repeated projection, and successor install over a nonempty repository cannot replay old data into an activated successor. Restart and repeated explicit successor preparation select the same edited generation. Deleting a saved video removes its current notes/bookmarks and playlist/queue references; archive recovery cannot revive them. Tests also retain a pre-deletion plan and reject replay over the used repository.

The external pointer protects app-controlled startup/restore routes. Replacing the **entire** app directory including control files from an older OS/user backup, or opening the untouched original in an older binary, is outside that authority. No cross-install remote ledger or control over user-exported copies has been established. Such restoration remains an external-backup release question; this work does not claim permanent erasure of retained bytes. Plans and provenance assertions are internal trusted engineering products, not an untrusted JSON import feature.

## Concrete candidates and destruction decision inventory

Run `python3 scripts/test-archive-successor-process.py`. It leaves an intact `reviewable-candidate-<UUID>` under `.artifacts/archive-successor-process`, separate from deliberately damaged fault fixtures. `report.json` identifies its `candidate-review.json` and current SQLite path. That review file contains the active route identity, runnable candidate summary and per-file path, byte size, SHA-256, role and destruction impact. All data is synthetic; no private library was sampled. Generated reports are local artifacts, not published policy evidence.

`retainedCopyInventory` reads original/default main/WAL/SHM and enumerates the entire owned upgrade directory. Enumeration failures throw. Symlinks are unresolved, not traversed or approved for deletion. The inventory performs no SQLite opens on originals and no file removal. It lists physical copies, not a complete semantic origin classification for every byte.

| Concrete app-owned scope | Destroying it would mean | Decision status |
| --- | --- | --- |
| Original `muses-youtube-native.sqlite`, `-wal`, `-shm` | Lose old-app rollback and any unique unresolved title/lyrics/name, old text or advanced state | Protected; no automatic destruction authorized |
| Each retained `<UUID>/legacy.snapshot.sqlite` and sidecars; interrupted `snapshot-input-*` file sets | Lose physical recovery snapshots, including fields not present in the successor | Protected; enumerate actual files and verify accepted successor/user review first |
| Every old `<UUID>/muses-public-v1.sqlite` and sidecars, including partial attempts | Lose archived raw tracks/queue/models/settings and older public edits | Protected; whole-file retirement is necessary for physical cleanup, not just logical row deletion |
| `<UUID>/prepared.json`, old `active.json` / `pending.json` | Lose historical routing/provenance and rollback references | Review alongside corresponding stores, never remove current authority implicitly |
| Current successor directory | Lose verified preserved data and post-activation edits | Retain; it is not a cleanup target |
| `successor-active.json`, `successor-pending.json`, `deleted.json` | Could remove the anti-resurrection / deletion authority | Retain or transition through a reviewed protocol; never treat as disposable metadata |
| User exports, device/OS backups, external copies | Outside the enumerated app-owned set; may preserve all original content | No deletion claim or permission inferred; identify controllability and restore semantics separately |

Before a real user's final retirement choice, show that user's concrete manifest and runnable successor, identify every unresolved name/field and supported/unsupported relation, and allow review of the effects. This commit does not request or assume that choice on synthetic evidence. Ordinary policy-required deletion does not require a new Google permission. Only a strategy relying on a retention exception or disputed archival interpretation needs an external platform determination. User approval of backup retirement cannot waive applicable platform rules. Rename, encryption, hiding and omission from the active UI are not deletion.

## Validation and remaining gates

The automated proof covers five real SIGKILL boundaries (`intent`, `beforeSave`, `saved`, `verified`, `activated`), independent restart, preserved current user edits/repeated occurrences, unchanged original main/WAL/SHM hashes, parent retention, post-activation deletion, no fallback on missing successor, and whole-app deletion taking precedence. Unit/integration tests cover save failure rollback, stale name evidence, unknown raw data, unsupported orphan/exclusion failure, all app restore adapters, and parent edits made during preparation.

Recorded validation on 2026-09-27:

| Check | Result |
| --- | --- |
| Persistence package | 36 tests passed |
| Root macOS physical migration suite | 14 tests passed |
| iOS isolated physical migration suite | 14 tests passed, iPhone 17e / iOS 26.5 simulator |
| Public-app hosted `MusesTests` | 24 tests passed, including generic API-filled names remaining unproven |
| Successor process harness | Five SIGKILL boundaries plus explicit whole-app deletion precedence passed |
| Generic iOS Release build and static artifact audit | Passed; production signing, entitlements and live network behavior are separate validation |

Remaining gates are not hidden by the successful fixture: real-library contract coverage, unknown historical names/metadata, orphan/exclusion support, user decision for unique recovery copies, complete external-backup/retention semantics, production physical retirement and crash-proof completion accounting. No automatic original destruction, exception approval, policy publication or P6 completion is asserted.
