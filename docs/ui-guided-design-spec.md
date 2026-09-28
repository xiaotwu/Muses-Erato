# Muses UI/UX guided design decisions

## Accepted

- Global navigation follows the three-destination proposal B.
- Destinations are Home, Search, Library; Home replaces the proposal's Explore name and combines the existing Home/Discover content.
- Existing playlist hero-card design and its interactions are preserved during this round.
- Library uses proposal C: top Add menu contains Import/New Playlist; category-scoped clear stays next to the current collection count. Categories remain horizontal text with an active underline.
- Home uses proposal A: Continue playback, Recently played, Browse topics. The URL/ID input moves to a top action entry; browse topics use compact icon-plus-text controls for the existing explicit searches.
- Search uses proposal A: compact rows with a single overflow action; queue/channel actions use labeled menu items rather than a separate per-result button row. Search field and Videos/Playlists/Channels filters sit above results.
- Visual style uses proposal A: restrained gold, system fonts and semantic black/white surfaces. Light accent #785B2B, dark accent #D1AD70; playlist hero surfaces remain as currently accepted.
- Design proceeds through global navigation, per-screen layout, action/text placement and visual details, before unified product implementation.
- Settings uses proposal B: compact directory leading to Account/Library & data/Playback/Privacy & support detail pages. Replace the Muses account-summary heading with the actual authenticated YouTube channel ID, obtained from channels.list(mine=true, part=id); do not use OAuth subject, email or a placeholder ID. Show loading/unavailable/no-channel states honestly and clear the value when signing out.
- Preserve an explicitly labeled website playback entry in playback actions/settings. Stable background music playback is the user's primary playback requirement. Prefer the website route and App Store distribution if both can meet it; otherwise assess the native route and IPA distribution. Official embedded playback currently cannot be assumed to permit background playback under YouTube developer policies.
- Player uses proposal A: fixed playback area above vertically arranged queue, notes and time bookmarks. The layout choice does not lock the playback backend to the official player.
- Standalone Queue uses proposal A: compact rows and overflow menus in browsing mode; enter Edit for removal/reordering. Current playback is separate from upcoming items; Clear removes upcoming items only. Duplicate queue entries retain occurrence identity.
- Import uses proposal A: one page with Account Playlists / Playlist Link sources, automatic pagination of the account playlist catalog, selected-playlist item loading and confirmation; retain the original playlist name. Navigation title is exactly "Import Playlists", geometrically centered independently of leading/trailing controls. Use "Import" when available width or Dynamic Type cannot accommodate the full title; never shrink readable type to force it to fit.
- Track/video detail uses proposal A: compact thumbnail and metadata, one grouped row for Play/Favorite/Add to Playlist; overflow contains Play Next/Enqueue/Website Playback/Delete from Library. Notes and time bookmarks appear directly below, with separate add and scoped-clear controls. Bookmark selection pauses and cues the selected timestamp; this is distinct from starting playback.
- Note/bookmark editing uses proposal A: adaptive bottom sheet, expandable when the keyboard appears or content needs more room. Centered editor title, Cancel and Save actions, unsaved-change confirmation. Notes retain their existing text model. Bookmarks retain title/time editing and explicit current-position capture; require a valid player time before capture, and validate time format/range rather than fabricate a timestamp. iPad uses an appropriately sized sheet rather than stretching fields across the screen.
- Playlist management uses proposal A: retain the hero deck, show compact track rows directly, group Play/Enqueue/Add controls, enter Edit for occurrence-aware removal and ordering; Rename/Clear Tracks/Delete Playlist live in a labeled overflow menu. Clear retains the playlist record/name; deleting the playlist is a separate confirmed action. Imported playlists are local copies under the current read-only Google scope; these actions do not imply remote playlist mutation.
- Account detail uses proposal A: channel identity and complete copyable Channel ID, account collection navigation, separate visible account-management actions. Keep cleanup-pending recovery, unavailable OAuth, missing channel, loading and errors explicit. Distinguish local sign-out from Google permission revocation; do not label the existing combined revoke-and-delete behavior as merely sign-out.

## Pending

- Investigate interchangeable website/WebView and native stream playback adapters, including macOS resolver reuse. Data/catalog providers are separate from playback adapters. Native background playback, interruption handling, queue continuity and failure recovery require an iOS feasibility prototype before being represented as available features.
- Distribution remains App Store preferred, but the user accepts IPA or TestFlight if the desired playback experience conflicts with App Store requirements. External TestFlight remains subject to Apple beta review; IPA signing and device eligibility must be resolved before distribution.
- Demus/Lyra developer statements describe website/WebView playback; their exact current internals and claimed dual-route implementation have not been verified. Do not treat marketing or App Store availability as source-code evidence.
- All auxiliary-page layouts have been selected and the unified UI implementation has passed the simulator gates below. Physical-device acceptance remains pending.

These are accepted design requirements. Verified product progress is recorded below; P6 remains in the separate release thread.

## Implementation ownership

- Root: PublicRootView shell, Settings/Account, Player/Queue, playlist/video detail, Library category chrome, session changes and integration tests. Worktree erato-guided-ui, branch codex/erato-guided-ui, base 2716fed.
- Existing secondary UI task: PublicCatalogViews.swift, PublicPlaylistImportView.swift, PublicNotebookViews.swift, PublicServiceLinks.swift. Delivered source commit 1e6b41d and test commit ba9a967 from codex/guided-ui-secondary; integrated as 80f9e36 and 9519cdc. Do not edit the shared root, session, hero deck or project files.
- P6 release work stays in its own task. Original /Users/xiaotwu/Code/Muses-Erato has 65 dirty entries and must remain untouched. No upload, deployment or history rewrite is part of this UI change.

## Cross-page rules

- One title per page; remove redundant collection/device eyebrow text. Native navigation titles are inline and geometrically centered on iPhone; full Import Playlists falls back to Import for width/accessibility constraints. Each tab retains its navigation stack.
- Use icon-only controls for recognizable actions with accessible names and 44pt hit areas; use icon plus text for ambiguous actions and labeled menu commands. Group peer actions on one row, wrapping only for actual width/Dynamic Type constraints.
- Preserve system fonts, semantic contrast, Dynamic Type, Reduce Motion and keyboard dismissal. iPad uses appropriate content widths, sidebar and sheets; do not force iPhone layouts across an entire iPad.
- Keep destructive actions distinct: remove occurrence, remove saved track, clear scoped list, delete playlist, erase local data, revoke Google access. Confirmation names the scope and retained data accurately. Retained originals and cleanup failure notices remain accessible; required privacy/provider disclosures remain available.
- Loading: compact progress at the relevant content area, cancel/retry when supported. Empty collection: one concise message and a relevant import/search/add entry. Error: local actionable message with retry; never silently replace data or show a fictional ID. Authentication expiry directs to Settings/Account. Recovery must retain source data.
- Website playback must be explicitly labeled and operate through a real URL/player route; avoid an inert playback-mode toggle. Current official player remains visible. Background, system-remote and audio-processing options must reflect verified capabilities.

## Implementation and verification gates

1. Complete root shell and settings/account; update entry-point tests for Home link sheet, Library Add menu and compact Search actions.
2. Integrate secondary import/catalog/notebook changes; preserve automatic playlist pagination and original names. Confirm supported UI is usable at normal and largest accessibility sizes.
3. Complete Player A, Queue A and Detail A. Reuse notebook state across player/detail; stale track loads and duplicated queue/playlist entries keep existing identity safeguards.
4. Build the integrated branch and run focused UI flows for navigation, keyboard dismissal, queue clear/edit, import, notebook CRUD and paused bookmark cueing. Test account-channel success/empty/error/reset behavior with deterministic fixtures when needed.
5. Per the user’s updated acceptance order, complete iPhone/iPad Simulator checks first, then perform one unified physical-iPhone acceptance for playback/login/import/layout. Inspect actual screenshots rather than treating compilation as visual proof. Simulator/build success does not establish device or release acceptance.
6. Produce separate playback feasibility evidence for website and native routes: background and lock-screen continuity, interruption handling, next-track transitions, loading timeout, credentials/URL expiration and sole audible adapter. Release choices require observed results; TestFlight external review and IPA signing are independent distribution constraints.

## Current status

All page-layout choices above have been selected by the user. The unified UI implementation and focused simulator acceptance are complete for this round; physical-device acceptance remains pending. Background playback is requested and pending verification; App Store/P6 readiness is not established.

- Secondary UI commit 1e6b41d integrated as 80f9e36; import source segmented control added during integration to match the selected A layout.
- Integrated simulator build passed. Focused keyboard-dismissal and privacy-gate UI tests passed (2 tests); OAuth package passed 20 existing tests covering local cleanup and revocation. These results do not establish physical-device acceptance.
- Original hero deck remains unchanged. Original source repository retains its 65 dirty entries.

### Simulator acceptance evidence (2026-09-28)

- iPhone simulator: Erato-Notebook-iPhone, iPhone 17e, iOS 26.5, UDID 1C58A5F6-6867-4BA3-9A14-AF17AEB07BB7.
- iPad simulator: Erato Compact Actions iPad, iPad mini (A17 Pro), iOS 26.5, UDID C0E767C3-C087-47FF-A701-398C898E5AD8; Home/sidebar visually inspected.
- `/tmp/erato-guided-navigation-tests.xcresult`: keyboard dismissal and privacy gate, 2 tests passed.
- `/tmp/erato-guided-feature-retest2.xcresult`: notebook CRUD, editing, scoped clear, restart persistence and paused bookmark cue; account/link playlist auto-pagination, original name and import-title geometric centering, 2 tests passed.
- Account collections/channel identity test passed in `/tmp/erato-guided-feature-tests.xcresult`. That earlier bundle had other failures and is not an overall passing suite: outdated tests expected list-detail controls while Library defaulted to Cards, and measured a native menu row against the former custom-button constraint. Tests now select List explicitly and measure the custom 44pt Add control; the subsequent focused retest passed.
- Original playlist hero deck source remains unchanged. A duplicated Songs/Videos count in the surrounding Library shelf was removed after accessibility-size screenshot inspection.
- Simulator catalog/account checks use deterministic DEBUG fixtures in isolated test libraries. They do not demonstrate production Google authorization, API quota, audible playback or background continuity.
- Signed physical-device Debug build succeeded, but the attempted install failed with a device connection reset. Per the user’s instruction, further physical installation is deferred until simulator acceptance is complete.
- Physical acceptance still must cover production Google login and Channel ID, actual imported account playlists, audible playback, queue next/clear behavior, keyboard, layouts and system interruption behavior. Native background playback feasibility is a separate pending gate; the current visible official player retains its existing background behavior.

- `/tmp/erato-guided-queue-playlist-tests.xcresult`: 3 tests passed. Covers Library/player queue clear retaining current playback, playlist and queue occurrence ordering/deletion, playlist renaming, favorites and restart persistence; maximum accessibility-size import-title centering, card/list switching and browsing without unintended playback.
- `/tmp/erato-guided-search-playback-tests.xcresult`: 2 tests passed. Covers explicit search pagination, retry retaining existing rows, and the labeled website-playback entry under an unsupported embedded-video restriction. The website was not launched by this test.
- Across these runs, 10 distinct focused UI tests passed, plus the 20 OAuth package tests. The earlier failed test bundles are retained above; only the named passing cases/bundles establish the recorded results.
- Next acceptance step: one unified physical-iPhone run when the user is ready. Do not request repeated installation/unlock actions while the agreed simulator-first phase is running.

### Physical-iPhone acceptance started (2026-09-28)

- User reconnected the iPhone and explicitly authorized the unified physical-device run.
- Rebuilt commit d7ad174 as a signed Debug iOS app using the private local xcconfig; build succeeded. Verified the bundle contains a configured YouTube API key, iOS OAuth client and redirect scheme without exposing their values.
- Installed successfully on the paired iPhone 15 Pro (00008130-001A30E93E81001C), bundle com.xiaotwu.muses.erato, and launched successfully with devicectl. Installation updated the existing app; the app was not uninstalled.
- Installation and launch are confirmed. Production login/Channel ID, audible playback/Next/queue clear, account import and cross-page UI/UX acceptance are awaiting the user’s actual-device observations. No physical-device acceptance or background-playback completion is claimed yet.
- UI feedback is expected to drive further revisions; the simulator pass does not close the user’s design acceptance gate.
