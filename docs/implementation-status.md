# Muses Erato iOS implementation status

Updated: 2026-09-27. Integration branch: `codex/erato-integration-base`.

This file records verified evidence, not completion claims. The original checkout at
`/Users/xiaotwu/Code/Muses-Erato` remains untouched and contains the user's active edits.

| Phase | Integrated result | Verification | Remaining gate |
| --- | --- | --- | --- |
| P0 | Source baseline, capability matrix and migration plan | macOS 671 tests; core 3 tests; original iOS baseline had two known failures | Keep parity matrix current |
| P1 | Visible official YouTube IFrame adapter | Swift typecheck and simulated public UI flow | Real video playback, error, navigation and interruption on device |
| P2 | Domain, queue, V1 persistence and lossless legacy archive contracts | Package tests pass; legacy archive 14 tests pass | Physical old SwiftData fixture, app reader, rollback proof |
| P3 | Official Data API catalog, OAuth with PKCE, quota ledger and caching | Package tests pass; Google sign-in succeeded on physical iPhone | Guest Data API key, live catalog result and quota measurements |
| P4 | Public app shell, iPhone/iPad navigation, local history/favorites and visible player route | iPhone simulator app/UI tests pass; iPad layout visually inspected; signed app installed and launched on iPhone | Playlists, notes, queue UX, broader parity and accessibility audit |
| P6 | Public source allowlist and unsigned archive audit | Release archive audit found no inherited stream resolver/Innertube/Piped/yt-dlp or obsolete background/extension capabilities | Signed release archive, privacy/review packet, TestFlight and App Review |

## Local device evidence

- A paired iPhone 16,1 accepted the signed Debug app under `com.xiaotwu.muses.erato` using Apple team `9URWGD9Q86`.
- The iOS OAuth plist supplied by the user matches the bundle ID and supplies a registered reverse-client-ID URL scheme. The user confirmed Google sign-in succeeded on device. The plist contains no YouTube Data API key.
- The app can now use OAuth for public read endpoints when no API key is configured. Package tests cover authorization headers, cache clearing and absence of a key in the request URL. Live signed-in search and video playback still need device confirmation.
- No key or token is committed to the repository. The local OAuth `.xcconfig` is outside the checkout under `/tmp`.

## Active work

- Public local library, playlist and queue flows are being implemented in a separate worktree.
- A physical fixture of the inherited 19-model SwiftData store and a production-safe migration reader are being developed in a separate worktree. Until verified, the public app stops at a recovery screen when it detects legacy store files.

## Release decision

**NO GO** for public distribution. The remaining gates above require implementation and evidence. In particular, the existing-user migration cannot be treated as complete from archive package tests alone. The public app may be exercised on a new install but must not replace an existing user's store without rollback proof.
