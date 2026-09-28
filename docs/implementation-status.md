# Muses Erato iOS implementation status

Updated: 2026-09-27. Integration branch: `codex/erato-integration-base`.

This file records verified evidence, not completion claims. The original checkout at
`/Users/xiaotwu/Code/Muses-Erato` remains untouched and contains the user's active edits.

| Phase | Integrated result | Verification | Remaining gate |
| --- | --- | --- | --- |
| P0 | Source baseline, capability matrix and migration plan | macOS 671 tests; core 3 tests; original iOS baseline had two known failures | Keep parity matrix current |
| P1 | Visible official YouTube IFrame adapter | Simulator regressions; owner confirmed physical video playback, Next and stop on dismissal/background | Embedding-error and broader interruption/device matrix |
| P2 | Domain, queue, V1 persistence and lossless legacy archive contracts | Package tests pass; legacy archive 14 tests pass | Archive provenance/retention release gate; full device upgrade acceptance |
| P3 | Official Data API catalog, OAuth with PKCE, quota ledger and caching | Package tests; physical sign-in/search/account import; correct bundle header 200 and wrong/missing headers 403 | OAuth public production/verification, API allowlist and quota evidence |
| P4 | Public app shell, compact Library, local collections and visible player route | Integrated phone/tablet and maximum-text flows; owner confirmed current physical UI functions | Layout refinement deferred by owner; manual accessibility and broader device acceptance |
| P6 | Public source allowlist, signed Release archive and local App Store IPA | eb36a02 archive/export pass static and distribution-signing audits; IPA not uploaded | Privacy/retention, domain/OAuth approval, release packet, TestFlight and App Review |

## Current UI delivery (2026-09-27)

The compact Library rebuild is installed and launched on the physical iPhone. Songs now shows the union of playlist membership, with a macOS-style fan deck and compact list; all playlists appear as vertical blocks of lazy horizontal hero occurrences. Related actions share rows; ambiguous import, account, support and policy actions have visible labels. The interface retains one native page title.

Account playlists and selected playlist entries load every page automatically, with cancellation/error/limit handling. Source names refresh in memory and default to the original name; actual custom names retain user-input provenance. Songs and playlist playback establish full previous/current/remaining collection context while preserving explicit Up Next. Clearing Songs targets only playlist membership.

Integrated phone and tablet import/swipe/list/restart flows, the maximum text-size flow, collection playback/scoping tests and repaired keyboard dismissal passed. The owner confirmed functional behavior on the physical iPhone; further layout refinement is deferred for a later discussion. Details and intermediate failures are in [library-ui-validation.md](library-ui-validation.md); this does not close P6 or declare public App Store readiness.

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

- Local playlists, favorites, queue editing, top-level Clear Up Next, notes and time bookmarks are integrated. Twenty-six hosted app unit tests pass on the merged version. Actual YouTube bookmark capture/cue remains a device gate.
- Official playlist/channel browsing, explicit paging, account collections and bundle identity headers are integrated. New API display metadata is kept in memory; durable rows preserve selections and proven user labels. Thirty-five persistence tests pass, including raw stored-payload checks and deletion rollback.
- Library now has horizontally scrollable categories, adaptive macOS-inspired hero cards, icon actions, per-item removal and scoped list clear controls. Music/audio-only playback classification is not invented from ordinary video data; the official visible player remains the supported playback route.
- The original 19-model SwiftData fixture, read-only preparation, durable atomic activation, recovery routing, deletion tombstones and external-cleanup retry are integrated. Fourteen root migration/routing/successor tests pass. The independent baseline executable and eight upgrade process termination boundaries pass; the runnable successor also passes five integrated SIGKILL boundaries. Twenty-six hosted app unit tests pass after successor/import integration. Original source sidecars and unique copies remain protected; the successor does not automatically retire them.
- All fifteen merged iPhone Simulator UI scenarios now have passing evidence across the first suite and targeted repair reruns. The first run exposed outdated heading/button selectors and scroll assumptions in five scenarios; those failures were repaired, not counted as passes. Keyboard, queue clear, empty playlist, playlist editing/reorder/relaunch, notebook CRUD/bookmarks, catalog, hero/dynamic type, privacy agreement and smoke navigation are covered. The latest merged Debug build is installed on the phone; the owner identified the missing YouTube Music/account playlist import as a core gap. Import is now the current priority; device acceptance remains open. Simulator/package evidence does not establish physical or release acceptance.

## Account / YouTube Music playlist import history

The owner identified a core gap during device acceptance: browsing a playlist is not adding it to Library. Direct Library account-playlist selection with OAuth and music.youtube.com share-link import are now integrated. One action reads remaining pages (at most 100 pages / 5,000 entries), with cancellation, retry and atomic local commit. Repeated entries display, delete and reorder by occurrence UUID; queues preserve their order. The official account endpoint guarantees owned playlists, not the whole YouTube Music library. API display names remain memory-only; the local playlist uses the user's chosen name. Integrated iPhone import UI and two hosted import tests pass; the worker also verified iPad import. The signed Debug build including imports, occurrence editing and secondary icon controls is installed and launched on the phone. The owner confirmed account reading, imported counts and playback work. They requested automatic all-page loading immediately after selection and retaining the original playlist name. Those refinements were subsequently integrated and installed; the owner confirmed current functional behavior. See Current UI delivery and library-ui-validation.md. API-name provenance and memory-only display boundaries remain enforced.

## Privacy and release preparation

- GitHub Issues is the owner-selected public support channel and is enabled. Settings now provides support/provider policy/permissions icon links.
- The bundled, versioned policy and pre-feature agreement gate are implemented. The app session is constructed after agreement, avoiding account refresh and artwork requests before consent. Simulator UI testing verified the disabled continue state, one-tap agreement, feature access afterwards and persistence across relaunch. Debug fixture libraries can bypass this gate; the bypass is excluded from Release. The gate is installed on the physical phone. The subsequent owner response confirmed current UI functions; detailed privacy/third-party and manual accessibility release evidence remains separate.
- Repository-managed homepage, terms and privacy HTML are prepared by `scripts/build-privacy-site.py`; static HTML/local-link/policy consistency checks pass. They have not been published. Final deletion behavior, Google embedded processing/App Privacy answers, domain/consent verification and owner/platform contacts must be reconciled before publication.
- OAuth token-store load/delete failures now still attempt private-cache removal and report a storage failure rather than falsely claiming successful deletion. Four OAuth tests pass including failure injection.
- Initial Cloud restriction acceptance failed (all three identity variants returned HTTP 200). After the owner configured restrictions, correct identity returned HTTP 200 and wrong/missing identities returned HTTP 403. The identity restriction negative cases now pass. API allowlist settings and production project quota still need release evidence; the key value is not recorded.

## Scene authority

The public composition owns one playback adapter, account cache and store projection per scene. The inherited Info.plist advertised multiple simultaneous scenes without a shared playback/deletion authority. The public build now declares a single scene; iPad adaptive layouts and system multitasking remain supported. Re-enable multiple scenes only after shared store/account invalidation and explicit player ownership are implemented. The artifact audit enforces this declaration. Earlier export hashes above predate this change and must be replaced for final release.

## Latest archive evidence

- The merged signed Release archive at `/tmp/erato-public-release.xcarchive` built successfully and passed `scripts/audit-public-artifact.py` against its actual app. Expected official endpoints and bundled privacy resources are present; inherited stream routes and obsolete background/extension entitlements are absent.
- Its provisioning profile is a development wildcard profile, with signed application identifier `9URWGD9Q86.com.xiaotwu.muses.erato` and `get-task-allow = true`. This is **not** an App Store distribution artifact or evidence of TestFlight/App Review acceptance. A separate App Store export was subsequently verified as described below; the archive itself retains development signing.

- App Store export for code commit `0488b85` succeeded under team `9URWGD9Q86`. Exported IPA SHA-256: `554d7d07aa253f180506a9b3621fc913c0d878f0e070748682dba502da44e8be`. The exported app has the matching explicit application identifier, `get-task-allow = false`, no provisioned-device/all-device profile, verified signature and passing static audit. Version/build: `1.0.0` / `1`. It has **not** been uploaded. This export is historical and predates the single-scene and compact Library delivery; use the eb36a02 export below for current artifact evidence.
- Reproduce the export audit with `python3 scripts/audit-distribution-ipa.py <exported.ipa> --team 9URWGD9Q86`. This verifies the exported IPA rather than assuming archive signing matches distribution signing. It does not establish OAuth production, App Privacy, TestFlight or App Review acceptance.

## Current distribution artifact (eb36a02)

- Release archive: `/tmp/erato-release-eb36a02.xcarchive`; log: `/tmp/erato-release-eb36a02.log`. Local App Store export: `/tmp/erato-app-store-eb36a02/Muses.ipa`; export log: `/tmp/erato-app-store-eb36a02-export.log`.
- `audit-public-artifact.py` passed on the archive. `audit-distribution-ipa.py` passed on the actual exported app: explicit bundle/team identity, valid signature, `get-task-allow = false`, distribution profile without device lists, single scene and public-source/capability checks. Audit log: `/tmp/erato-app-store-eb36a02-audit.log`.
- IPA SHA-256: `079bc78eb985f36ffcabb9a7e8eedd0200268b9e23513946efe2c68357690842`; version/build `1.0.0` / `1`. No upload, TestFlight acceptance or App Review acceptance occurred. This artifact can be superseded by later product or release-configuration changes.
- Generated public pages still pass `build-privacy-site.py --check`; they remain unpublished and this check performs no remote verification.

## Release decision

**NO GO** for public distribution. The remaining gates above require implementation and evidence. Migration activation and process recovery now have integrated test evidence. Public release still requires the archive provenance/retention lifecycle, embedded-provider privacy declarations, verified policy/consent domain, owner/platform configuration, final signed artifact and physical acceptance. See `docs/release/privacy-inventory.md` and `docs/release/privacy-domain-check.md`; a successful build is not P6 acceptance.
