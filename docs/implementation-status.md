# Muses Erato iOS implementation status

Updated: 2026-09-27. Integration branch: `codex/erato-integration-base`.

This file records verified evidence, not completion claims. The original checkout at
`/Users/xiaotwu/Code/Muses-Erato` remains untouched and contains the user's active edits.

| Phase | Integrated result | Verification | Remaining gate |
| --- | --- | --- | --- |
| P0 | Source baseline, capability matrix and migration plan | macOS 671 tests; core 3 tests; original iOS baseline had two known failures | Keep parity matrix current |
| P1 | Visible official YouTube IFrame adapter | Swift typecheck, simulated public UI flow and physical iPhone video playback | Next, embedding error, navigation and interruption on device |
| P2 | Domain, queue, V1 persistence and lossless legacy archive contracts | Package tests pass; legacy archive 14 tests pass | Archive provenance/retention release gate; full device upgrade acceptance |
| P3 | Official Data API catalog, OAuth with PKCE, quota ledger and caching | Package tests pass; Google sign-in succeeded on physical iPhone | Restricted-key device catalog acceptance and production quota evidence |
| P4 | Public app shell, iPhone/iPad navigation, local history/favorites and visible player route | iPhone simulator app/UI tests pass; iPad layout visually inspected; signed app installed and launched on iPhone | Merged hero/notebook/catalog device acceptance and broader accessibility audit |
| P6 | Public source allowlist and signed Release archive static audit | Latest merged Release archive passes endpoint/capability/entitlement checks; it uses development provisioning | Final-version distribution export, privacy/review packet, TestFlight and App Review |

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

## Integrated implementation and verification

- Local playlists, favorites, queue editing, top-level Clear Up Next, notes and time bookmarks are integrated. Twenty-two hosted app unit tests pass on the merged version. Actual YouTube bookmark capture/cue remains a device gate.
- Official playlist/channel browsing, explicit paging, account collections and bundle identity headers are integrated. New API display metadata is kept in memory; durable rows preserve selections and proven user labels. Thirty-five persistence tests pass, including raw stored-payload checks and deletion rollback.
- Library now has horizontally scrollable categories, adaptive macOS-inspired hero cards, icon actions, per-item removal and scoped list clear controls. Music/audio-only playback classification is not invented from ordinary video data; the official visible player remains the supported playback route.
- The original 19-model SwiftData fixture, read-only preparation, durable atomic activation, recovery routing, deletion tombstones and external-cleanup retry are integrated. Ten root migration/routing tests pass. The independent baseline executable and eight process termination boundaries pass after integration; original source sidecars remain protected.
- All fifteen merged iPhone Simulator UI scenarios now have passing evidence across the first suite and targeted repair reruns. The first run exposed outdated heading/button selectors and scroll assumptions in five scenarios; those failures were repaired, not counted as passes. Keyboard, queue clear, empty playlist, playlist editing/reorder/relaunch, notebook CRUD/bookmarks, catalog, hero/dynamic type, privacy agreement and smoke navigation are covered. The latest merged Debug build is installed on the phone; the owner identified the missing YouTube Music/account playlist import as a core gap. Import is now the current priority; device acceptance remains open. Simulator/package evidence does not establish physical or release acceptance.

## Current priority: account / YouTube Music playlist import

The owner identified a core gap during device acceptance: browsing a playlist is not adding it to Library. Direct Library account-playlist selection with OAuth and music.youtube.com share-link import are now integrated. One action reads remaining pages (at most 100 pages / 5,000 entries), with cancellation, retry and atomic local commit. Repeated entries display, delete and reorder by occurrence UUID; queues preserve their order. The official account endpoint guarantees owned playlists, not the whole YouTube Music library. API display names remain memory-only; the local playlist uses the user's chosen name. Integrated iPhone import UI and two hosted import tests pass; the worker also verified iPad import. The signed Debug build including imports, occurrence editing and secondary icon controls is installed and launched on the phone. The owner confirmed account reading, imported counts and playback work. They requested automatic all-page loading immediately after selection and retaining the original playlist name. Those refinements are the active priority and need a new device build; automatic API naming must retain explicit provenance and the memory-only display boundary.

## Privacy and release preparation

- GitHub Issues is the owner-selected public support channel and is enabled. Settings now provides support/provider policy/permissions icon links.
- The bundled, versioned policy and pre-feature agreement gate are implemented. The app session is constructed after agreement, avoiding account refresh and artwork requests before consent. Simulator UI testing verified the disabled continue state, one-tap agreement, feature access afterwards and persistence across relaunch. Debug fixture libraries can bypass this gate; the bypass is excluded from Release. The new gate is installed on the physical phone; owner acceptance is pending.
- Repository-managed homepage, terms and privacy HTML are prepared by `scripts/build-privacy-site.py`; static HTML/local-link/policy consistency checks pass. They have not been published. Final deletion behavior, Google embedded processing/App Privacy answers, domain/consent verification and owner/platform contacts must be reconciled before publication.
- OAuth token-store load/delete failures now still attempt private-cache removal and report a storage failure rather than falsely claiming successful deletion. Four OAuth tests pass including failure injection.
- Initial Cloud restriction acceptance failed (all three identity variants returned HTTP 200). After the owner configured restrictions, correct identity returned HTTP 200 and wrong/missing identities returned HTTP 403. The identity restriction negative cases now pass. API allowlist settings and production project quota still need release evidence; the key value is not recorded.

## Latest archive evidence

- The merged signed Release archive at `/tmp/erato-public-release.xcarchive` built successfully and passed `scripts/audit-public-artifact.py` against its actual app. Expected official endpoints and bundled privacy resources are present; inherited stream routes and obsolete background/extension entitlements are absent.
- Its provisioning profile is a development wildcard profile, with signed application identifier `9URWGD9Q86.com.xiaotwu.muses.erato` and `get-task-allow = true`. This is **not** an App Store distribution artifact or evidence of TestFlight/App Review acceptance. A separate App Store export was subsequently verified as described below; the archive itself retains development signing.

- App Store export for code commit `0488b85` succeeded under team `9URWGD9Q86`. Exported IPA SHA-256: `554d7d07aa253f180506a9b3621fc913c0d878f0e070748682dba502da44e8be`. The exported app has the matching explicit application identifier, `get-task-allow = false`, no provisioned-device/all-device profile, verified signature and passing static audit. Version/build: `1.0.0` / `1`. It has **not** been uploaded. New automatic loading/original-name changes remain in progress and will need a fresh final export.
- Reproduce the export audit with `python3 scripts/audit-distribution-ipa.py <exported.ipa> --team 9URWGD9Q86`. This verifies the exported IPA rather than assuming archive signing matches distribution signing. It does not establish OAuth production, App Privacy, TestFlight or App Review acceptance.

## Release decision

**NO GO** for public distribution. The remaining gates above require implementation and evidence. Migration activation and process recovery now have integrated test evidence. Public release still requires the archive provenance/retention lifecycle, embedded-provider privacy declarations, verified policy/consent domain, owner/platform configuration, final signed artifact and physical acceptance. See `docs/release/privacy-inventory.md` and `docs/release/privacy-domain-check.md`; a successful build is not P6 acceptance.
