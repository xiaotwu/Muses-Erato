# Muses UI/UX guided design decisions

## Accepted

- Global navigation follows the three-destination proposal B.
- Destinations are Home, Search, Library; Home replaces the proposal's Explore name and combines the existing Home/Discover content.
- Existing playlist hero-card design and its interactions are preserved during this round.
- Library uses proposal C with corrected membership: all track collections are projections of the deduplicated union of local-playlist members, rather than of cached/opened videos. Favorites and history intersect that union; subscriptions belong to Account. Clearing all playlists leaves these Library track collections empty, including Videos. Metadata retention is separate from membership.  top Add menu contains Import/New Playlist; category-scoped clear stays next to the current collection count. Categories remain horizontal text with an active underline.
- Home uses proposal A, expanded after real-device feedback: local Muses shelves and cloud YouTube Music recommendations, alongside Continue playback, Recently played and Browse topics. The URL/ID input moves to a top action entry; browse topics use compact icon-plus-text controls for the existing explicit searches.
- Search uses proposal A: compact rows with a single overflow action; queue/channel actions use labeled menu items rather than a separate per-result button row. Search field and Videos/Playlists/Channels filters sit above results.
- Visual style uses proposal A: restrained gold, system fonts and semantic black/white surfaces. Light accent #785B2B, dark accent #D1AD70; playlist hero surfaces remain as currently accepted.
- Design proceeds through global navigation, per-screen layout, action/text placement and visual details, before unified product implementation.
- Settings uses proposal B: compact directory leading to Account/Library & data/Playback/Privacy & support detail pages. User correction: the account-summary heading means the human-readable YouTube channel nickname, not the technical Channel ID. Show the real channel title and avatar; keep the technical ID only inside collapsed Channel details. Account playlists and subscriptions expand inline on Account, with automatic playlist pagination. Keep loading/unavailable/no-channel states honest and clear account display on sign-out.
- Preserve an explicitly labeled website playback entry in playback actions/settings. Stable background music playback is the user's primary playback requirement. Prefer the website route and App Store distribution if both can meet it; otherwise assess the native route and IPA distribution. Official embedded playback currently cannot be assumed to permit background playback under YouTube developer policies.
- Player uses proposal A: fixed playback area above vertically arranged queue, notes and time bookmarks. The layout choice does not lock the playback backend to the official player.
- Standalone Queue uses proposal A: compact rows and overflow menus in browsing mode; enter Edit for removal/reordering. Current playback is separate from upcoming items; Clear removes upcoming items only. Duplicate queue entries retain occurrence identity.
- Import uses proposal A: one page with Account Playlists / Playlist Link sources, automatic pagination of the account playlist catalog, selected-playlist item loading and confirmation; retain the original playlist name. Navigation title is exactly "Import Playlists", geometrically centered independently of leading/trailing controls. Use "Import" when available width or Dynamic Type cannot accommodate the full title; never shrink readable type to force it to fit.
- Track/video detail uses proposal A: compact thumbnail and metadata, one grouped row for Play/Favorite/Add to Playlist; overflow contains Play Next/Enqueue/Website Playback/Delete from Library. Notes and time bookmarks appear directly below, with separate add and scoped-clear controls. Bookmark selection pauses and cues the selected timestamp; this is distinct from starting playback.
- Note/bookmark editing uses proposal A: adaptive bottom sheet, expandable when the keyboard appears or content needs more room. Centered editor title, Cancel and Save actions, unsaved-change confirmation. Notes retain their existing text model. Bookmarks retain title/time editing and explicit current-position capture; require a valid player time before capture, and validate time format/range rather than fabricate a timestamp. iPad uses an appropriately sized sheet rather than stretching fields across the screen.
- Playlist management uses proposal A: retain the hero deck, show compact track rows directly, group Play/Enqueue/Add controls, enter Edit for occurrence-aware removal and ordering; Rename/Clear Tracks/Delete Playlist live in a labeled overflow menu. Clear retains the playlist record/name; deleting the playlist is a separate confirmed action. Imported playlists are local copies under the current read-only Google scope; these actions do not imply remote playlist mutation.
- Account detail uses proposal A with the user’s correction: nickname/avatar identity, technical Channel ID under collapsed details, inline account collections and separate account-management actions. Keep cleanup-pending recovery, unavailable OAuth, missing channel, loading and errors explicit. Distinguish local sign-out from Google permission revocation; do not label the existing combined revoke-and-delete behavior as merely sign-out.

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

### Real-device feedback revision

- Settings now follows the supplied Apple Music reference: avatar and nickname at the top, inset grouped directory rows, system headline/body/footnote hierarchy, semantic grouped surfaces and an explicit close icon. The app follows system light/dark appearance instead of forcing dark appearance. Existing playlist hero decks remain unchanged.
- Account playlists and subscriptions are inline. Automatic playlist pagination removes the former account-collections navigation step. Clear-display buttons live beside section headings; paging and retry use short visible labels when necessary.
- Library Videos, Songs, Favorites and History now share the local-playlist membership scope. Clearing playlists retains cached metadata and current playback state, while these collections become empty. Scoped Videos/Favorites/History clear actions no longer include unrelated cached tracks.
- Home now renders playlist-based local shelves, authorized YouTube playlists and server-titled Music recommendation shelves. Details, auth evidence and release implications are in `docs/music-home-ios-adaptation.md`.
- Regression bundle `/tmp/erato-feedback-regression-tests.xcresult`: 2 unit and 2 UI tests passed for playlist-union scope/restart, endpoint normalization/auth evidence, nickname/inline account display and clearing all playlist collections.
- A subsequent simulator run hit a test-runner preflight Busy error before test execution. The scoped simulator was booted and the already-built tests were retried; this infrastructure failure is not counted as a passing run.

- `/tmp/erato-feedback-account-retest.xcresult`: 4 UI tests passed after simulator recovery: direct account playlist → player routing, nickname and inline account layout, largest accessibility text, and notebook CRUD/persistence after explicitly adding saved videos to a playlist. Source tests now distinguish saved metadata from playlist membership rather than relying on opened links appearing in Library.
- Settings/Account normal and largest-text screenshots were exported and inspected from `/tmp/erato-feedback-account-attachments/`; the new grouped surfaces follow the supplied Apple Music example. Fixture screenshots contain no user account data.
- Signed device revision build and install succeeded. The app started on the paired iPhone; actual Music account response and the user’s visual acceptance are pending. A credential-free Debug diagnostic reports only authentication-confirmed boolean and shelf count. Bundled privacy version is 2026-09-28.1, requiring renewed agreement before the changed Home requests run.

### 2026-09-28 — confirmations and experimental music playback

The user requested deletion/cloud-sync confirmation, edge-to-edge hero artwork, music-style playback controls, background/lock-screen playback, and readable song/creator labels in queue/history. The native IPA prototype now has an explicit playback choice; public Release keeps its visible-player route. Implementation boundaries, tests and remaining physical acceptance are maintained in `docs/native-audio-and-confirmation-acceptance.md`. Physical background testing was deferred by the user; it must not be marked passed.

## Latest feedback: direct playback and native Liquid Glass

Home, history and list-row taps initiate playback, while details are secondary info/menu actions. Queue/history artwork uses passive portrait hero covers with filled, black-edge-trimmed imagery. Playlist hero deck composition remains intact.

Functional chrome adopts native Liquid Glass: tab bottom accessory for the mini player on iOS 26.1+, floating glass mini player on other iOS 26 layouts, glass action groups/playback buttons, and a single glass Library selection capsule. Standard settings/navigation/sheets follow the current system appearance. Prior-system and Reduce Transparency fallbacks remain supported. Full-image surfaces remain content rather than glass.

See native-audio-and-confirmation-acceptance.md for startup/transition fixes and evidence. Foreground audio startup tests do not close the pending background/lock-screen acceptance gate.
