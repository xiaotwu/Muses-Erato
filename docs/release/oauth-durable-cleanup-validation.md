# Durable OAuth cleanup intent and startup retry

Date: 2026-09-27. Baseline `458e2cf`. This follow-up closes the known in-memory-only cleanup-intent defect. P6 remains **NO GO**.

## Implemented behavior

- Production composition injects `FileOAuthCleanupJournal` at the stable public destination URL plus `.oauth-cleanup.json`. The marker contains only `version` and `pending`, with no token or account identifiers. It is independent of active/successor store selection.
- Deletion records pending intent before reading credentials, sending revocation, or deleting credentials/private cache. Atomic replacement, file synchronization and parent-directory synchronization precede cleanup. Missing marker means no recorded operation; unreadable, corrupt or unsupported markers fail closed.
- Token access and authorization-code completion check this journal before reading existing credentials or sending a token request. Startup retries pending **local** token/private-cache deletion and does not restore the old account. A failed retry keeps the marker pending; successful cleanup persists completion before reporting success. Concurrent cleanup is rejected so one operation cannot clear another's pending intent.
- Settings exposes account cleanup retry and blocks new sign-in while cleanup remains pending. Retry participates in the session's outstanding-operation accounting used by full local-data deletion. An explicit retry can replace a damaged marker with fresh deletion intent; ordinary token access/login cannot silently ignore it.
- Remote revocation errors remain distinct: successful local cleanup completes the marker even if Google revocation fails. Startup retry does not send the surviving grant to Google. The existing Google account access link remains the route for reviewing provider permission.

## Verification

`swift test --package-path Platform/iOS/OAuth` passes **20 tests**, including the previous 14 generation tests and six journal tests. Log: `/tmp/erato-oauth-durable-tests.log`.

| Journal scenario | Verified result |
| --- | --- |
| Marker round trip, corrupt JSON and unsupported version | Reopened file preserves intent; only the two control fields are stored; invalid records report storage failure. |
| Failed token deletion followed by a new client using the same file | Surviving credentials are never loaded or sent; retry stays pending until deletion succeeds, then account remains signed out. |
| Private-cache deletion failure after tokens were removed | Pending intent survives; a new client retries cache cleanup and completes the marker. |
| Corrupt marker during token access or new exchange | Neither token-store read nor HTTP request occurs. |
| Intent/completion write failures | No success is reported; failed intent write prevents deletion from starting. |
| Overlapping cleanup while private cleanup is suspended | Second operation is rejected and cannot clear pending intent; completion follows the first operation. |

Signed generic iOS Release build passed: `/tmp/erato-oauth-durable-release.log`. Public artifact static audit passed: `/tmp/erato-oauth-durable-release-audit.log`. Code-signature verification passed: `/tmp/erato-oauth-durable-signature.log`. The loose app output at `/tmp/erato-content-status-release` now reflects this follow-up; prior logs retain their original source scope.

## Boundaries

File-backed tests reopen the journal with a new client; they do **not** terminate a real iOS process during writes, simulate device power loss, or exercise locked physical Keychain/filesystem behavior. Durable APIs and fail-closed sequencing are implemented, but those final-device interruption and Settings acceptance cases remain required evidence. The containing app-support directory exists before production journal use.

The marker does not delete retained authorized playlist/video IDs, memberships, recovery copies, WebKit state or Google browser state. Those field-level retention/deletion and provider privacy gates remain open. No device install, new archive/export, TestFlight upload, website publication, Search Console proof or Google Cloud change occurred. The phone remains on `7065a17`; the historical `79eff2e` IPA cannot represent this source. Google Audience remains Testing/unverified. The owner-selected `xiaotwu.github.io` host-root verification still requires the actual Search Console verification HTML file and platform completion.
