# ADR 0004: public upgrade activation and explicit deletion

Status: implemented; automatically activate only after candidate verification. 2026-09-27.

The public `Muses` target now compiles an explicit list of the original 19 models, pure value helpers and the snapshot reader in their historical module. It does not compile legacy app composition, networking, playback, cookie-reading or device services. No model declaration was copied or changed. The independent baseline executable built by the process test obtains every model-bearing file directly from commit `dd6fabb`, checks its SHA-256 against fixture provenance, and has no dependency on the migration reader or persistence package.

## Authority and durable states

The upgrade never opens the original with SQLite or SwiftData. It first copies main/WAL/SHM with filesystem reads, checks that source and copied bytes match before/after copying, and refuses a changing source. SQLite then backs up only that disposable file set, incorporating committed WAL pages; only the backup reaches the exact old-model reader with `allowsSave: false`. Tests assert the original main, WAL **and SHM** bytes remain unchanged. The durable activation fingerprint excludes SHM locking metadata so independent rollback inspection alone does not count as a user edit. All source/default writes below occur only after the separate, explicit user deletion action.

Each candidate lives in a UUID directory under `muses-public-v1.sqlite.upgrade`. SQLite files are not renamed while Core Data owns them. The route is a small, versioned JSON file published atomically, synchronized along with its directory. Candidate main/WAL files and their directory are synchronized before activation. Unknown versions fail closed.

| State | Startup behavior |
| --- | --- |
| No legacy data or route | Open the existing public store or create the normal new-user store. Orphan sidecars fail closed. |
| Legacy data, no route | Refuse any un-routed public store; record a pending UUID and build a fresh isolated candidate. |
| Pending, incomplete attempt | Keep diagnostic files; prepare a new UUID from the original. Never reuse partial records. |
| Pending, prepared candidate | Reopen read-only, validate public data, route identity and original-archive digest, then activate. Source divergence blocks activation. |
| Active | Open only the selected candidate. Validate identity, immutable archive digest and public payloads. Public edits are allowed; the original import is never replayed. A changed original surfaces a recovery conflict. |
| Explicit deletion recorded | This takes precedence over every migration state. Never import the retained legacy store again. Open a new empty generation and complete old-file removal on the next process launch. |

Preparation first imports `LegacyCompleteBundle` in a SwiftData transaction and checks the full original receipt after reopening. A second transaction adapts public projections and writes a route identity. Another read-only reopen validates the adapted store before `prepared.json` is written last. The original receipt describes the original import; it is not incorrectly reused to reject subsequent public edits. The active route uses a digest over immutable track/queue/model/settings archives plus a database-local identity. Failed/corrupt candidates and damaged route files surface recovery instead of selecting an empty replacement.

## Readable public projections

`LegacyHistoryEvent` becomes `PlaybackHistoryEntry`, preserving event and track IDs and mapping `startedAt` to `date`. Events with no playable track remain in their complete original archive; no invented video ID is used. Queue-only tracks are materialized from their real archived queue snapshots when needed, without changing original archive records. Notes and bookmarks keep their existing `LegacyNote` and `LegacyBookmark` payloads for the separate notes UI integration.

`LocalPlaylist` remains backward compatible with existing public payloads. Its `trackIDs` editor projection is unique, but optional `occurrences` retain every original playlist-item UUID, repeated track and unavailable slot, in order. Playback uses `playbackTrackIDs`, so repeats are not lost. Renaming preserves order; removing a grouped video removes its occurrences; reordering groups repeats in the requested order. Original archives never change. The archive screen explains this behavior, shows all original occurrences and restores a separate playlist with repeats rather than overwriting edits. Empty names get a public fallback while their original value remains archived.

The migrated-library banner is attached at the App composition layer; `PublicRootView` and its keyboard, navigation, player and OAuth interactions are unchanged. It opens a read-only archive browser, complete versioned JSON export and explicit recovery/deletion actions. The archive includes original metadata, all model kinds and relationship IDs, raw queue JSON, settings and the import receipt. Consent/settings are not applied automatically. Existing IDs, favorites and user text are not replaced by API-derived metadata.

## Explicit deletion overrides rollback retention

The existing confirmed `deleteLocalData()` action also applies to migration originals. It first records a durable deletion generation, clears current records and hides archive access. A separate `externalCleanupComplete` stage remains false until all app-owned credentials and website/cache cleanup succeed. Every cleanup step is attempted even if another fails; errors retain the pending marker and show an accurate failure rather than claiming deletion. Startup resumes this asynchronous stage before permitting a public library to open.

Cleanup tears down the iframe, cancels/waits for prior sign-in and Foundation network work, clears catalog caches, removes all types in the app's default `WKWebsiteDataStore`, clears the shared `URLCache` and `HTTPCookieStorage`, and removes the retired app's dedicated `Library/Caches/Muses` namespace (including artwork/feed/media caches). Website record removal is verified with the WebKit data-store API. App request epochs prevent pre-deletion responses from repopulating the new library. Current and inherited app-owned OAuth Keychain services are deleted last, after requests can no longer store a refresh token. TokenStore/Keychain or WebKit errors keep cleanup pending. No legacy cache/network classes are linked. A hosted test seeds a separate persistent WebKit data store, a Foundation cache and inherited artwork files and verifies their removal; another injects credential failure and proves website cleanup is still attempted and restart completes the pending phase.

This does not delete the YouTube account, external browser cookie files, or Safari/ASWebAuthenticationSession's browser profile. Old app preference keys are cleared once and synchronized; new preferences created after deletion are preserved. The exact non-personal `muses.privacy.acceptedVersion` policy-version flag is retained so AppStorage does not replace the running Session with the consent page mid-cleanup. Non-legacy-prefixed flags are also retained. This exception does not preserve old web/account consent or credentials.

Core Data may close handles asynchronously, so retained physical files are removed on the next **process** launch, before any old-generation container is opened. The UI states: “Library cleared. Restart Muses to finish removing retained migration files.” It does not claim physical deletion is already complete. On that launch, startup removes original main/WAL/SHM, the obsolete default public store, every old candidate/snapshot directory, and old pending/activation markers. Only a non-personal deletion UUID/completion marker and the user's new generation remain. A same-process Session recreation also selects the empty generation, but does not unlink possibly live databases. Failure/termination during cleanup leaves the deletion marker authoritative and cleanup retries without resurrection. A deletion recorded after a new public generation has been used supersedes that generation too. The new generation has its own durable initialization flag and identity; once initialized, a missing or damaged new store fails closed instead of silently creating another empty library. Process tests preserve new post-deletion edits across restart and then remove the synthetic new store to verify this failure boundary.

The archive browser also exposes this confirmed all-local-data removal path. User-exported copies saved elsewhere remain under the user's control. File removal is not a claim of forensic secure erase or erasure of external backups.

## Evidence and limits

Run `python3 scripts/test-legacy-process-upgrade.py`. It builds an independent original-schema executable, kills the upgrade with actual SIGKILL at snapshot, before legacy save, after legacy save, after projection, prepared-marker and activation-marker boundaries, and restarts each attempt. It checks original main/WAL/SHM hashes, both original occurrences, public edits across restart, and original-schema **writable** reopen plus continued edits after failed and successful upgrades. Re-entering the public app after baseline edits is rejected as source divergence. It also kills deletion after its marker and after file removal; both recover to an empty generation with old files/archives removed. Reports and independent binary sources are in `.artifacts/legacy-process-proof`.

The baseline executable is compiled from fixed original source; it is not an archived, previously shipped App Store executable. The kill points bound transactions and activation but do not claim every instruction during SQLite commit was interrupted. Read-only save rejection is tested separately; disk-full hardware/power-failure combinations remain unverified. Production signing/entitlements, deployment-floor hardware and final store review remain release validation work. These limitations do not bypass per-library integrity checks: unsupported or malformed legacy state still shows recovery and leaves originals intact.

### Validation recorded on 2026-09-27

| Check | Result |
| --- | --- |
| Root `swift test` (macOS physical fixtures and public routing) | 10 tests passed |
| `swift test --package-path Packages/MusesDomain` | 5 tests passed |
| `swift test --package-path Packages/MusesPersistence` | 18 tests passed |
| `MusesTests`, hosted in the public app, iPhone 17e / iOS 26.5 simulator | 11 tests passed |
| `MusesLegacyMigrationProof`, same simulator | 10 tests passed |
| `python3 scripts/test-legacy-process-upgrade.py` | All eight SIGKILL boundaries, writable original rollback, external-cleanup pending gate, post-deletion edits and missing-generation failure passed |
| Generic iOS Release build, signing disabled | Build passed |
| `scripts/audit-public-artifact.py` on that Release `.app` | Static audit passed; signed entitlements explicitly unverified |

These are synthetic fixture tests. The source physical store, app defaults and Keychain of a real user were not used. The website cleanup test uses an isolated persistent WebKit store and injected cache directory. Runtime OAuth/network conformance is outside the static artifact audit.

## Integration qualifications

The immutable source/archives intentionally retain data until explicit all-local deletion. Individual public playlist/history/note edits or deletions do not erase their rollback/archive originals. Unknown source provenance and old API-derived or authorized data need the P6 release review's classification and expiry policy; the technical migration proof is not approval for indefinite retention. This branch does not invent fresh API-fetch timestamps or erase uncertain-origin user text. The integration branch's newer `catalogMetadata` / 30-day expiry APIs were not in this branch's starting HEAD; merge must preserve their conservative unknown-provenance handling, while keeping original IDs/favorites and archive truth. Notes/bookmarks retain their original payloads for the separate feature branch. Root privacy documents under `docs/release` are not modified here.
