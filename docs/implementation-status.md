# Muses Erato iOS implementation status

Updated: 2026-09-27. Integration branch: `codex/erato-integration-base`.

This file records verified evidence, not completion claims. The original checkout at
`/Users/xiaotwu/Code/Muses-Erato` remains untouched and contains the user's active edits.

| Phase | Integrated result | Verification | Remaining gate |
| --- | --- | --- | --- |
| P0 | Source baseline, capability matrix and migration plan | macOS 671 tests; core 3 tests; original iOS baseline had two known failures | Keep parity matrix current |
| P1 | Visible official YouTube IFrame adapter | Swift typecheck, simulated public UI flow and physical iPhone video playback | Next, embedding error, navigation and interruption on device |
| P2 | Domain, queue, V1 persistence and lossless legacy archive contracts | Package tests pass; legacy archive 14 tests pass | Physical old SwiftData fixture, app reader, rollback proof |
| P3 | Official Data API catalog, OAuth with PKCE, quota ledger and caching | Package tests pass; Google sign-in succeeded on physical iPhone | Guest Data API key, live catalog result and quota measurements |
| P4 | Public app shell, iPhone/iPad navigation, local history/favorites and visible player route | iPhone simulator app/UI tests pass; iPad layout visually inspected; signed app installed and launched on iPhone | Playlists, notes, queue UX, broader parity and accessibility audit |
| P6 | Public source allowlist and unsigned archive audit | Release archive audit found no inherited stream resolver/Innertube/Piped/yt-dlp or obsolete background/extension capabilities | Signed release archive, privacy/review packet, TestFlight and App Review |

## Local device evidence

- A paired iPhone 16,1 accepted the signed Debug app under `com.xiaotwu.muses.erato` using Apple team `9URWGD9Q86`.
- The iOS OAuth plist supplied by the user matches the bundle ID and supplies a registered reverse-client-ID URL scheme. The user confirmed Google sign-in succeeded on device. The plist contains no YouTube Data API key.
- The app can now use OAuth for public read endpoints when no API key is configured. Package tests cover authorization headers, cache clearing and absence of a key in the request URL. The user confirmed live signed-in search returned correct results on the physical iPhone.
- The first device playback attempt stayed loading. The embedded HTML now uses the app's Bundle ID as its HTTPS client origin, validates bridge messages against that origin, and permits its own local HTML navigation. After reinstall, the user confirmed video playback works. The WebView retains visible YouTube controls and the app does not resolve media streams.
- The user reported that tapping outside a text field did not dismiss the keyboard. A window tap recognizer now dismisses input without cancelling controls or taps inside text fields. Home and Search UI regression tests pass, and the user confirmed the fix on device.
- Integration regression exposed alert buttons moving before touch-up when the global keyboard gesture ended editing. The gesture now skips UIControls and UIAlertController responder chains. Home/Search outside-tap dismissal, one-tap empty playlist creation, and the full playlist/favorite/queue editing/relaunch scenario passed on iPhone 17e / iOS 26.5 Simulator. One intervening run was killed during shared simulator installation and was rerun after isolating task devices; it is not counted as a product pass.
- The user supplied a separate project API key file. A live `videos.list` request returned HTTP 200 and the expected video; the signed device build includes the key. No key or token is committed to the repository. The owner-private Google build configuration is at `~/.config/muses-erato/Local.xcconfig`.
- After the latest signed device install, the user confirmed queue Next, clearing upcoming items while the current video continues, stopping playback on player dismissal/background, and finding the Library top-level Clear Up Next entry all work.

## Background music request

The user now wants songs to continue playing in the background. This is a pending product requirement, not a verified or delivered capability. The previously accepted App Store priority and YouTube-only source remain in force. YouTube Developer Policies III.I.7 and III.I.9 prohibit audio isolation and background players for the current embedded route, including music videos. A Data API key, OAuth login, music category or a different distribution package does not provide the missing permission. Background music in Muses requires an explicitly authorized playback source or separate permission from Google; do not silently enable hidden IFrame playback or add an unapproved source. The existing external View on YouTube action does not transfer Muses' queue or promise background playback.

Reference: https://developers.google.com/youtube/terms/developer-policies#i-additional-prohibitions

## Active work

- Local playlists, favorites, queue editing and top-level Clear Up Next are integrated. Notes and time bookmarks are being implemented in a separate worktree.
- Official playlist/channel browsing, account paging, bundle identity headers and API metadata retention are integrated. Ten hosted app tests passed after integration. A signed Debug build was installed and launched on the paired iPhone; the new catalog flows still need device acceptance.
- Compact Library categories, macOS-style hero cards, icon actions and per-list clear/delete controls are being implemented in the catalog task's next branch.
- A physical fixture of the inherited 19-model SwiftData store and read-only migration preparation are integrated. Activation, rollback and deletion recovery are being developed in a separate worktree. Until verified, the public app stops at a recovery screen when it detects legacy store files.

## Privacy and release preparation

- GitHub Issues is the owner-selected public support channel and is enabled. Settings now provides support/provider policy/permissions icon links.
- The bundled, versioned policy and pre-feature agreement gate are implemented. The app session is constructed after agreement, avoiding account refresh and artwork requests before consent. Simulator UI testing verified the disabled continue state, one-tap agreement, feature access afterwards and persistence across relaunch. Debug fixture libraries can bypass this gate; the bypass is excluded from Release. The new gate has not yet been installed/accepted on the physical phone.
- Repository-managed privacy HTML is prepared by `scripts/build-privacy-site.py`; it has not been published. Final deletion behavior, Google embedded processing/App Privacy answers, domain/consent verification and owner/platform contacts must be reconciled before publication.
- OAuth token-store load/delete failures now still attempt private-cache removal and report a storage failure rather than falsely claiming successful deletion. Four OAuth tests pass including failure injection.
- Cloud restriction acceptance failed: correct, wrong and missing iOS identity headers all returned HTTP 200. The owner has been asked to restrict the project key; the key value is not recorded. This is a release gate, not a reason to disable ongoing engineering.

## Release decision

**NO GO** for public distribution. The remaining gates above require implementation and evidence. In particular, the existing-user migration cannot be treated as complete from archive package tests alone. The public app may be exercised on a new install but must not replace an existing user's store without rollback proof.
