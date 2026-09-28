# Automatic playlist loading and original display names

Baseline: `0569f58`. Selecting an account playlist or submitting a playlist share link now reads metadata and every item page automatically. The existing 100-page/5,000-entry ceiling, cancellation, cursor-preserving retry, and explicit final save remain. The screen shows the playlist name, loaded entry count and progress rather than a raw ID. After a complete read, the original name is prefilled and the save icon is enabled without typing. Renaming is optional.

## Name provenance and persistence boundary

`LocalPlaylist.remoteSource` records the user-selected YouTube playlist ID and whether authorized reads are required. An unchanged default name is remote display metadata, not a user label. `rename` promotes a remote name to a user-authored label only when the trimmed value actually changes. A custom name survives refresh, expiry and restart.

The API name and its fetch timestamp exist only in memory. `LocalPlaylist.localPersistenceSnapshot` replaces the API name with `Imported YouTube playlist`; custom `Encodable` enforces the same boundary even for generic or future graph encoders. Repository generic `.localPlaylist` writes, imports and graph deletion also use the sanitized snapshot explicitly. Old local/migrated playlists decode without the new optional fields and preserve their existing names.

On startup/foreground maintenance, Library appearance, successful OAuth restoration, sign-in, and manual metadata refresh, source IDs restore original names into memory. Automatic attempts are throttled to one minute; fresh names are normally refreshed after a day and expire after 29 days. No membership is synchronized during name refresh. Sign-out's existing forced metadata expiry also clears remote names. Access-denied/not-found responses discard affected remote names. Offline or signed-out account playlists use the understandable placeholder with a Library explanation. Existing user-authored names are never overwritten. Video deletion preserves valid in-memory names while writing only sanitized graph snapshots.

## Remaining P6 / authorization-data boundary

Persisted remote playlist IDs, the authorized-read marker, selected video IDs and membership are still remote-derived/account-associated identifiers retained as user-selected local library state. The current work does **not** claim that this settles YouTube authorized-data retention, account unlinking/revocation, refresh/deletion obligations or full API-policy compliance. That P6 review remains open, including what identifiers must be removed on account disconnection and how different accounts should scope retained playlist references. No account ID/token or API playlist name is written into the playlist payload. This change does not add nonofficial endpoints or cloud mutations.

## Validation

- Catalog package: 22 tests passed (`/tmp/erato-auto-catalog.log`), including one-call metadata/all-page loading, failure cursor retry and a noncooperative response after task cancellation never becoming importable.
- Persistence package: 36 tests passed (`/tmp/erato-auto-persistence.log`), including real file-backed SQLite Record payload checks through import, generic put, savePlaylist and graph deletion; original name absent; unchanged-name confirmation retains remote provenance; explicitly renamed text persists; fresh container reads return the offline placeholder.
- Dedicated iPad mini (A17 Pro), iOS 26.5 simulator `438BB4B7-165B-4AF8-BD70-2F523044A805`: updated UI test verifies automatic account selection and Music-link pagination, prefilled original name, save enabled without keyboard entry, and original-name recovery after restart. First run passed: `/tmp/erato-auto-ios.log`.
- Hosted tests additionally cover original name immediately visible in memory but absent from persisted payloads; restart plus normal maintenance restores the original name; forced expiry clears it; a custom name survives restart, refresh and forced expiry; partial failed/cancelled reads cannot create tracks or playlists.
- No shared project files changed. New reader source and tests are in auto-discovered package directories. Existing app/test source entries remain unchanged.

This branch's validation uses fixtures and an iPad simulator. The user had already validated the preceding account import/count/playback on a physical device; this refinement still needs installation and a real-account check by the integration task. No repeat Google setup is needed.

## Concurrent successor integration (`04e8211`)

That later integration commit introduces `saveUserNamedPlaylist` and explicit-input flags in session create/edit. It is not in this branch's requested `0569f58` baseline. Apply the accompanying `remote-playlist-successor-integration.patch` when integrating: the method must delegate remote-default names to ordinary `savePlaylist` without creating user-name hash evidence. The custom LocalPlaylist encoder already sanitizes its payload; the extra guard protects the separate authorship-evidence record. Preserve the later create/edit signatures and pass explicit-input=true only for actual user-authored names. An unchanged API-prefilled rename remains `usesRemoteName == true`, so the repository guard is authoritative even if a caller mistakenly passes true. The optional custom name during import is persisted as a user label, but this branch does not manufacture successor evidence through a method absent from its baseline.

Final verification: `/tmp/erato-auto-final.log`: four hosted tests and one iPad UI test passed. Domain package: nine tests passed (`/tmp/erato-auto-domain.log`).

Release simulator build and public artifact static audit passed (`/tmp/erato-auto-release.log`, `/tmp/erato-auto-audit.log`). The companion evidence-guard patch passed `git apply --check` against `04e8211`; it must be applied in that integration branch and its successor tests rerun there.
