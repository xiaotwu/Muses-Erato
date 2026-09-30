# Quality improvement and integration validation

Date: 2026-09-29 (America/Los_Angeles). Local implementation and integration; no commit, upload, hosted-policy publication or release approval.

## Delivered behavior

- First launch presents a concise native sheet with explicit, versioned consent. Normal text keeps agreement, Continue and Not now visible; largest text uses scrolling. Complete policy remains available in the sheet and Settings. Missing/empty policy blocks entry, even with old agreement or test fixtures. A counting-content unit test verifies the app/session boundary stays lazy before consent.
- Home follows the selected content-first direction: recently played, local playlists, saved-video fallback, then optional account playlists. Account Home requests only the first page; More is explicit. Failed continuation retains existing rows. Empty Home offers Search videos, Open link and Import playlist.
- Library has All Saved / Playlists / Favorites / History. Redundant Songs and unavailable Podcasts are removed from visible navigation. Favorites/history are independent of playlist membership. Clearing playlists keeps saved videos; deleting saved videos removes their references atomically. Local filtering and persisted Cards/List preference are available; the default is List and largest text uses rows without overwriting that preference.
- Search separates editing from submitted identity and stores submitted source/query/type in the session. Local Videos/Playlists make no catalog requests; local Channels is not offered. Type changes require submission; failures preserve rows and retry the same page. Search videos entries select Videos and focus input without submitting.
- Settings retains grouped destinations, adds app version/build/edition and policy agreement information, and uses account/metadata/deletion-specific operation state. Cleanup confirmations, retry and restart guidance remain.
- Playback status failures expose Retry and Open YouTube. Retry rechecks restrictions. Checkpoints write at most every 15 seconds and at lifecycle boundaries; failed saves expose Retry saving. Queue edits save a proposed snapshot before publishing it and have a separate error domain, preserving original content-check errors.
- Retry-After accepts seconds and HTTP dates. Automatic retries respect the server delay; long delays return a visible error instead of retrying early. Device budgets persist atomically across restarts and library/account deletion; policy discloses these non-account operational counters.
- Public and Native unit/UI compositions are separate. CI runs package suites, channel builds, Public capability audit, Public regressions and dedicated Native regressions. Simulator diagnostics collection is disabled after a confirmed local Xcode 27 collection hang; test logs and xcresults remain available.

## Architecture boundary

This iteration extracts library projection, playback checkpoint handling and device-budget construction into `PublicSessionControllers.swift`, while networking retry/budget responsibilities live in MusesNetworking. Account, metadata, deletion, playback, library and queue have scoped error state; search uses its pager state. The historical `failureMessage` remains a compatibility bridge for some notebook/import/legacy surfaces. This is an incremental extraction, not a claim that the entire session has been decomposed.

## Verification evidence

Toolchain: Xcode 27.0, iOS 26.5 simulators, XcodeGen 2.46.0. Each workstream uses a separate simulator and DerivedData. Fixtures use isolated local libraries and no real OAuth credentials.

| Check | Result | Evidence |
| --- | --- | --- |
| Integrated Public Debug build/start | Passed | Coordinator build/run log, 2026-09-30 02:15 UTC |
| Integrated Public units | 51 passed | Tests/CI handoff, integrated-final Public result |
| Integrated Native common/engine units | 53 passed | Tests/CI handoff, integrated-final Native result |
| Public Release and Native distribution build | Passed on frozen source; hashes unchanged | Tests/CI handoff, integrated-final build logs |
| Public static capability audit | Passed on unsigned simulator build | Tests/CI handoff; signed entitlements remain unverified |
| Package suites | 115 passed across reported runs | Domain 9, Queue 3, Persistence 40, Networking 12, Catalog 28, Core 3, OAuth 20; affected networking/catalog rerun by owner |
| Privacy/Settings | 5 unit + 7 UI passed | Privacy handoff: normal text plus largest text/dark; consent, refusal/reopen, policy navigation/missing policy/error isolation |
| Corrected Library/search/import | 9 UI passed | `.artifacts/ui-quality/corrected-ui.xcresult`: Library 5, pagination 1, import 3 |
| Public UI coverage after repairs | 30 distinct scenarios passed across rounds; no unresolved case | Full round: 29 passed + 1 outdated keyboard assertion failed. Frozen-source affected round: keyboard, large Library and large import/search all 3 passed, command exit 0. Evidence: `public-ui-final.xcresult` and `public-ui-affected-final.xcresult` under `/tmp/muses-quality-integrated-coordinator/` |
| Current Native UI | 2 passed, 0 failures/skips | `integrated-final/native-ui-frozen.xcresult`; frozen hashes unchanged; element-relative tap avoids observed invalid AX activation point |
| Policy/site parity | Passed | `python3 scripts/build-privacy-site.py --check`; 3 passive pages and local links, no hosted publication |
| Diff whitespace | Passed | `git diff --check` |

Earlier runs are retained as diagnostic history: source allowlist/type/initializer integration failures were repaired; a Public unit command completed assertions but hung in simulator diagnostic collection and was rerun successfully with collection disabled. A coordinator UI run built before category identifier repairs was stopped and superseded. These are not represented as successful current runs. The later complete Public UI command also failed its one obsolete initial-Search-heading assertion; the repaired keyboard case and the two UI cases affected by final visual changes passed a subsequent frozen-source command. The two commands are reported separately rather than claiming a single all-green full-suite command.

## Visual inspection

Coordinator inspected normal first-launch, empty Home/Library and populated dark Library; owners exported additional largest-text, Settings, complete policy and search-retry screenshots. Normal first launch displays all primary controls; four categories fit without the previous rail clipping. Final icon bounds, keyboard dismissal and affected largest-text cases passed coordinator regression on the frozen source. Owner source hashes were independently checked and all six matched.

- `.artifacts/quality-privacy-settings-2026-09-29/first-launch.png`
- `.artifacts/quality-privacy-settings-2026-09-29/settings.png`
- `.artifacts/quality-privacy-settings-2026-09-29/full-policy.png`
- `.artifacts/quality-privacy-settings-2026-09-29/consent-accessibility-dark.png`
- `.artifacts/quality-improvement/screenshots/home-empty.jpg`
- `.artifacts/quality-improvement/screenshots/library-empty.jpg`
- `.artifacts/ui-quality/screenshots/library-cards-dark.png`
- `.artifacts/ui-quality/screenshots/library-large-dark.png`
- `.artifacts/ui-quality/screenshots/search-retry-dark.png`
- `.artifacts/ui-quality/screenshots/home-populated-dark.png`
- `.artifacts/ui-quality/screenshots/search-local-large-dark.png`

## Follow-up verification (2026-09-30)

The user authorized completion of the remaining checks. Follow-up results supersede the initial limitations above, while retaining the initial evidence as history.

- A single complete Public UI command passed all 30 original scenarios. New iPad/live test sources were generated afterward; the current composition is being tested separately by the CI workstream. See `quality-remaining-ci-runtime.md` for fingerprints and final counts.
- Real service tests passed **2/2**, with no catalog fixtures: YouTube search returned video results, and the visible iframe reported Playing and responded to Pause with Paused. These used the existing private local Google configuration and the original app identifier on an iOS 26.5 simulator. Result: `/tmp/muses-remaining-live-sim/live-services.xcresult`. The opt-in tests explicitly skip in ordinary unconfigured CI.
- A separately identified **MusesQA** app was signed, installed and launched on the user's iPhone 15 Pro / iOS 27. The user confirmed real Google login returned to the app with the correct account. The user reported search/content-check errors. A bounded API probe confirmed `API_KEY_IOS_APP_BLOCKED` for the QA identifier and HTTP 200 for the original identifier, with the same existing restricted key. No key value was printed, no restriction was removed and no app identifier was spoofed. An added QA allowlist entry is needed to complete those physical network checks.
- Physical XCTest failed before executing assertions on three attempts: the runner exited with code 74 while the DTX peer refused the XCTestDriverInterface channel. This persisted after the user allowed the automation prompt and kept the phone unlocked. USB pairing/tunnel, Developer Mode and usable compatible developer disk image services were verified. This is recorded as an automation infrastructure failure, not a passing device regression or a failed application assertion.
- Final Public Release archive, App Store distribution export and `audit-distribution-ipa.py --variant public` passed after the configuration-error and visual fixes. App/package source hashes remained unchanged across this build. The exported IPA had a valid distribution profile, `get-task-allow=false`, no registered devices, strict code signatures and the expected Public capability restrictions. Export was local; **nothing was uploaded**. Evidence: `/tmp/muses-remaining-signed/MusesPublic-validated.xcarchive`, `/tmp/muses-remaining-signed/public-validated-export/Muses.ipa`; IPA SHA-256 `351aa1c50734a73ee516209762a71acf98d5d2353e8fa9a9afc23644398adbfc`.
- Actual iOS **18.2 / 22C150** verification passed **4/4**, zero skips/failures: first consent/persistence, navigation/iframe surface/Library, restricted-content recovery controls, and saved-video local Search/Library relaunch. The official Apple portal provided the signed runtime after newer component CLI downloads were unavailable. Import and a separate iPhone 16 Pro simulator boot succeeded. Result: `/tmp/muses-quality-remaining-20260929/runtime18-targeted-v2.xcresult`. These fixture-based checks establish old-OS behavior, not live playback or external YouTube app execution.
- Actual Reduce Transparency and Increase Contrast toggles, app flows and restoration passed. Settings/Privacy strict contrast audit passed after semantic foreground-color corrections. Real VoiceOver produced introduction/Home focus and utterances, while policy detail and Settings focus commands failed in the system automation service; full VoiceOver navigation remains unverified. See `quality-accessibility-followup.md`.
- Actual iPad window resizing, accessibility display settings and VoiceOver attempts are recorded in their dedicated follow-up reports; only completed checks are claimed as passed.

## Remaining limits

Physical XCTest, QA-restricted network access, complete VoiceOver navigation and unresolved raw system-audit findings retain their individual statuses in the follow-up reports. The strict iPad audit has an explicit diagnostic scheme and keeps its original failing assertions/findings; default CI covers the separately verified functional scenarios. Remote CI for draft PR #11 is running and is not yet claimed as passed. Local signing/export does not establish App Store review acceptance.

## Coordination

The main chat owns discussion and integration. Six user-requested local chats cover design, tests/CI, networking, session recovery, Privacy/Settings and Home/Library/Search; see `quality-improvement-coordination.md` for identifiers and ownership. Design: `quality-ui-design.md`; final review: `quality-ui-implementation-check.md`. Detailed workstream logs and interfaces remain in their corresponding handoff documents.
