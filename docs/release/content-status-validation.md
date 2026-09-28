# Embedded-video content status — P6 implementation and evidence

Date: 2026-09-27. Integration baseline `d411c14`; the accompanying commit contains the implementation. This supersedes only the CONTENT-STATUS source gap in the historical/current-source snapshot. Public P6 remains NO GO.

## Official requirement and chosen boundary

[Google's current guide](https://developers.google.com/youtube/v3/guides/made_for_kids_status) requires a `videos.list` lookup with `id,status` before embedding and inspection of `status.madeForKids`. [Developer Policies III.E.4.10](https://developers.google.com/youtube/terms/developer-policies) additionally require appropriate tracking/data-collection controls for Made For Kids embeds. These requirements apply to embedded videos independently of whether the app itself targets children. A child-directed app has a separate designation obligation under III.J; intended audience and the appropriate platform declarations remain an owner/release decision.

**Current product decision:** embed only a video whose fresh response explicitly says `madeForKids=false` and `embeddable=true`. Made For Kids, missing/ambiguous status, missing resource, prohibited embedding, quota/network/auth failure all leave a local blank surface and an actionable message. The existing external YouTube link remains an explicit user action. No automatic redirect, stream fallback or unsupported tracking-disable parameter is introduced. MFK playback inside Muses is unsupported pending effective provider/privacy controls. This is a restricted-content decision, not an ATT/privacy compliance certification.

## Implementation

- `Packages/MusesCatalog/.../Catalog.swift`: `videoEmbeddingStatus` validates one ID, requests `part=id,snippet,status`, bypasses the actor response cache, and maps the response explicitly. Exactly one matching video is required; missing fields never imply false. `snippet` is included for the existing catalog mapper. Results are not cached or written to the local store. Existing coalescing, cancellation, restriction headers, OAuth fallback, bounded retries and quota accounting still apply.
- `PublicYouTubeSession.loadCurrent`: removes the previous player before asynchronous validation. The only public session path calling `adapter.load` now requires `.permitted`. Direct links, saved items, collections, queue Next and bookmark/restart attachment converge here. Check UUID, current occurrence identity, adapter identity and cancellation reject stale results, including repeated selections of the same ID. While checking/blocked, playback events and app Play cannot be accepted and capabilities remain empty.
- `YouTubeIFrameAdapter.clear`: invalidates the old video/generation, destroys the player, stops loading and shows a local blank document. Each new document has a nonce for its API-ready message, so an older document cannot grant API readiness after a new check. The adapter remains reusable for a subsequent allowed video. Official visible controls, ads and foreground behavior are preserved for allowed content.
- Policy/agreement version `2026-09-27.2`, terms and homepage describe the content restriction. Generated policy HTML matches the bundled text.

## Verified evidence

| Evidence | Result and limits |
| --- | --- |
| Catalog selected test run | 28 tests passed, including fresh changed status, absent fields, wrong/missing/duplicate IDs and identity header assertions. `/tmp/erato-content-status-catalog.log`. The Swift filter matched the module's existing classes as well as CatalogTests. |
| Hosted iPhone 17e / iOS 26.5 test run | 18 tests passed: 15 PublicLocalLibraryFlowTests and 3 PublicNotebookTests. `/tmp/erato-content-status-hosted-final.log`, result under `/tmp/erato-content-status-derived/Logs/Test/`. Covers known MFK/unknown/nonembeddable blocking; no accepted fake playback/history; delayed allowed response after restricted selection or detach; collection Next clearing/rechecking; changed status after file-backed restart; stale notebook adapter; history/queue preservation. Uses injected HTTP fixtures, not live Google player behavior. Expected corrupt-store recovery logs belong to the existing failure test; the suite passed. |
| Live read-only API probe | Owner's existing restricted key, expected iOS identity, two already-used public demonstration videos: HTTP 200, both `madeForKids=false`, `embeddable=true`. No key, title, account data or full URL recorded. Confirms field availability for these videos; no live MFK or production OAuth validation is claimed. |
| Targeted UI | Policy agreement/relaunch scenario passed in `/tmp/erato-content-status-ui.log`; MFK message visibility, enabled external action, disabled Play and Close passed in `/tmp/erato-content-status-ui-final.log`. The initial two MFK UI runs failed because the global notice query assumed a unique/hittable label while both presenting Home and player display the session failure. The test now checks a visible matching label; product restriction and controls were preserved. Initial failed runs are not counted as passes. |
| Final Catalog checks | Both new status tests passed after the final networking/cache-policy edit, `/tmp/erato-content-status-catalog-final.log`. |
| IFrame contract executable | Clear/reload rejects old same-video messages and preserves increasing generations; executable checks passed. Compiled with `swiftc` from the contract plus `Tests/YouTubeIFrameTests/ContractChecks.swift`. |
| Final Release build and static audit | Signed generic iOS Release build passed in `/tmp/erato-content-status-release-final.log`; public-source/single-scene artifact audit passed in `/tmp/erato-content-status-release-final-audit.log`. This is a development-signed app build, not an App Store archive/export. |
| Physical installation | That Release app installed and launched successfully on the paired iPhone; logs `/tmp/erato-content-status-device-install.log` and `/tmp/erato-content-status-device-launch.log`. Owner functional acceptance of this gate is still pending. |
| Static site | `build-privacy-site.py --check` passed after generation: policy parity, three passive pages, semantics and local links. No deployment. |

## Remaining evidence / artifact boundary

Physical-device ordinary playback, known MFK/unknown status, rapid Next and background/close during validation need acceptance on this change. Provider data processing, ATT, App Privacy, intended-audience classification, remote identifier lifecycle and legacy-copy retention remain open. A denied video stays selected in the local queue; it is not silently deleted or endlessly skipped. Offline/failed status checks now prevent embedding even for previously played videos. Each new embedded video incurs a `videos.list` read; re-opening checks again and must be included in the final quota budget.

The `79eff2e` IPA predates this product/policy change. It remains valid historical signing evidence and cannot represent this source. Do not upload it as the content-status candidate. Prepare a fresh candidate artifact after remaining release configuration is settled; no new archive/upload is implied by tests.
