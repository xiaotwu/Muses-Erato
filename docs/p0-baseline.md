# P0 repository and engineering baseline

Captured 2026-09-27 in `/Users/xiaotwu/.codex/worktrees/94a2/Muses-Erato`. Status means source evidence only unless a test result is explicitly recorded in `p0-verification.md`. This is a snapshot of mutable working trees, not a clean-release claim.

## Provenance and preservation

| Repository | Checkout / ref at capture | Working state | Role |
| --- | --- | --- | --- |
| Muses-Erato | `/Users/xiaotwu/Code/Muses-Erato`, `feat/bw-laser-ui-normalize`, `3e0ffa5` | 65 porcelain entries: 57 modified tracked files and 8 untracked paths | Source working tree; never edited by P0 |
| Muses-Erato P0 | this managed worktree, copied from the above working tree at `3e0ffa5`; branch `codex/p0-ios-baseline` | Same 65 source entries before P0 documents; tracked binary diff SHA-256 `676960a8ae1d4a372372582299d819e6e0f85703e42209a447bc89982734265f` matched source | P0 documentation only; original modifications remain uncommitted |
| Muses | `/Users/xiaotwu/Code/Muses`, `main`, `86ba9e3` | 27 porcelain entries: 24 modified tracked files and 3 untracked paths | macOS product reference; read only |

The matching diff hash covers tracked modifications. The source's nine untracked files were also compared file by file using SHA-256; there were zero mismatches. The copied `docs/ios-port-research-plan.md` content was not edited; it is committed on this P0 branch so subsequent branches inherit the authoritative plan, while the source checkout's untracked file remains untouched. P0's own documents are separate files. Before later rebases/merges, compare against the source again and handle conflicts explicitly. Neither remote history nor the macOS tree was changed.

## Repository and module inventory

| Area | macOS Muses | iOS Erato | Evidence / consequence |
| --- | --- | --- | --- |
| Build system | SwiftPM, macOS 14+, `Muses` executable, `MusesWebHomeHelper`, WebHome protocol/core and tests | XcodeGen `project.yml`, generated `Muses.xcodeproj`; iOS 18+, watchOS 11+; `Muses`, `MusesWidgets`, `MusesWatch`, `MusesTests`, local `MusesCore` package | `Package.swift`, `project.yml`, Xcode target list. The target graph is not yet the plan's package layout. |
| Application shell | `RootView`/`SidebarView` with Home, New, Search, ten library destinations and Settings | `MainTabView` with Home, Browse, Library, Search; Now Playing cover and Settings sheet | Source entrypoints; no route/UI acceptance run in P0. |
| Catalog | YouTube Data API plus YouTube Music/Innertube, web helper, yt-dlp discovery | Data API account client, Innertube discovery/search, playlist imports, cache | `Services/YouTube`, `Services/Discovery`; source presence does not establish public-release permission. |
| Playback | `PlaybackService` → `YouTubeStreamEngine` with yt-dlp stream resolution and AVPlayer/AVAudioEngine | `AppComposition` → `YouTubeStreamEngine`; Innertube/other resolver paths; IFrame in secondary `YouTubeVideoOverlay` | Current iOS main path conflicts with public YouTube decision; P1 must replace it for public build. |
| User data | SwiftData, queue/history/notes/playlists/imports/podcasts, store cutover work in progress | SwiftData `MusesSchema`, `MusesModelContainer`, queue/history/notes/playlists/imports | Schema compatibility with old iOS data has not been demonstrated. P2 owns fixtures and migration. |
| System integrations | menu bar, desktop lyrics, updater, global shortcuts, browser-cookie helper | Now Playing/remote commands, Spotlight, Widget/Live Activity, Watch, CarPlay scene | iOS `Info.plist` declares `UIBackgroundModes=audio`, Live Activities, CarPlay scene; app entitlement declares CarPlay Audio and App Group. Presence is not approval or device validation. |
| Tests | SwiftPM test target, including macOS store/queue/podcast coverage | `MusesCore` 3 unit methods; app test bundle has playback, parsers, queue, CarPlay, Watch and UI-agnostic checks | Many iOS tests encode the current non-public playback path; keep only behaviorally valid tests during migration. |

## Release claims and concrete blockers

The iOS README currently claims direct InnerTube streaming, background audio, 32-band EQ on YouTube and Lossless/Hi-Res/Dolby quality badges. Those are unverified as end-user claims and incompatible with the decided public YouTube path. P4/P6 must replace the public-facing copy before release. `Sources/Muses/Resources/Info.plist` still enables background audio and a CarPlay scene; `Muses.entitlements` requests CarPlay Audio. P1/P6 must remove or isolate these from a YouTube-only public target unless a separately authorized source and entitlement review exists. Simulator signing disabled cannot validate them.

The current iOS OAuth config defaults to `http://127.0.0.1:53682/` and requires loopback; the plist also registers a `muses-erato` URL scheme. This mismatch is a P3 blocker. The desktop OAuth design must not be treated as an iOS configuration merely because it compiles. The public iOS client needs its own Google native OAuth registration, callback validation, PKCE, and device tests.

`Muses/AGENTS.md` was read for the macOS reference. It describes macOS product invariants and confirms that macOS intentionally uses yt-dlp/stream playback; it is not an iOS public-build authorization. No `AGENTS.md` was found in the Erato worktree.

## Change-control baseline

P0 documents the source and does not change runtime wiring. Public build routing, entitlements, README claims, and migration are **open blockers**, not hidden by the passing compilation of old behavior. See `p0-feature-matrix.md`, `adr/0001-public-youtube-capabilities.md`, `p0-contracts-and-ownership.md`, and `p0-verification.md`.
