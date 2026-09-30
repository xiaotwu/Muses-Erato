> Work resumed explicitly by the user on 2026-09-30 with physical-device testing authorized. `quality-paused-state.md` retains the historical checkpoint; resumed results are recorded below. Earlier freezes do not validate later layout adjustments.

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
- A separately identified **MusesQA** app was signed, installed and launched on the user's iPhone 15 Pro / iOS 27. The user confirmed real Google login returned to the app with the correct account. Initial search/content-check errors were traced to `API_KEY_IOS_APP_BLOCKED` for the QA identifier; the original identifier returned HTTP 200 with the same existing restricted key. The user added the QA allowlist entry, a follow-up probe returned HTTP 200, and the user then confirmed **real search and playback work**. No key value was printed, no restriction was removed and no app identifier was spoofed. The user reported occasional play/pause delay and requested another Home/Search hierarchy revision; that follow-up is described below and is not covered by the earlier freeze.
- Physical XCTest failed before executing assertions on three attempts: the runner exited with code 74 while the DTX peer refused the XCTestDriverInterface channel. This persisted after the user allowed the automation prompt and kept the phone unlocked. USB pairing/tunnel, Developer Mode and usable compatible developer disk image services were verified. This is recorded as an automation infrastructure failure, not a passing device regression or a failed application assertion.
- Final Public Release archive, App Store distribution export and `audit-distribution-ipa.py --variant public` passed after the configuration-error and visual fixes. App/package source hashes remained unchanged across this build. The exported IPA had a valid distribution profile, `get-task-allow=false`, no registered devices, strict code signatures and the expected Public capability restrictions. Export was local; **nothing was uploaded**. Evidence: `/tmp/muses-remaining-signed/MusesPublic-validated.xcarchive`, `/tmp/muses-remaining-signed/public-validated-export/Muses.ipa`; IPA SHA-256 `351aa1c50734a73ee516209762a71acf98d5d2353e8fa9a9afc23644398adbfc`.
- Actual iOS **18.2 / 22C150** verification passed **4/4**, zero skips/failures: first consent/persistence, navigation/iframe surface/Library, restricted-content recovery controls, and saved-video local Search/Library relaunch. The official Apple portal provided the signed runtime after newer component CLI downloads were unavailable. Import and a separate iPhone 16 Pro simulator boot succeeded. Result: `/tmp/muses-quality-remaining-20260929/runtime18-targeted-v2.xcresult`. These fixture-based checks establish old-OS behavior, not live playback or external YouTube app execution.
- Actual Reduce Transparency and Increase Contrast toggles, app flows and restoration passed. Settings/Privacy strict contrast audit passed after semantic foreground-color corrections. Real VoiceOver produced introduction/Home focus and utterances, while policy detail and Settings focus commands failed in the system automation service; full VoiceOver navigation remains unverified. See `quality-accessibility-followup.md`.
- A second signed Public archive/export used the existing private Google configuration with the original app identifier. Local distribution audit passed: `/tmp/muses-remaining-signed/MusesPublic-configured.xcarchive` and `/tmp/muses-remaining-signed/public-configured-export/Muses.ipa`; IPA SHA-256 `32f26a93391b7f21d74b07712404457fe87eb9720308aba2e5b01d7f80ad9b9c`. Configuration values and the IPA remain local and ignored. This precedes the latest Home/Search and command-feedback follow-up.
- Actual iPad window resizing, accessibility display settings and VoiceOver attempts are recorded in their dedicated follow-up reports; only completed checks are claimed as passed.

## Home/Search and control follow-up (latest source)

- Home centralizes Open link, Import playlist and Create local playlist in a **+** toolbar menu, following the user’s final device feedback. Populated Home prioritizes content without repeated action strips; an empty Home retains Search, Open link and Import actions. Logged-out account shelves are omitted. Search uses a primary input/submit row and one navigation-bar Filters menu with flat Source/Type sections, selected states and accessible current values; the input/submit row stacks at accessibility sizes. Queue opens directly from player and mini-player controls rather than global navigation. Submitted result identity, paging and retry remain intact. See `quality-home-search-redesign.md` and `quality-home-search-hierarchy-review.md` for screenshots and test results.
- A separate observable playback-command controller provides immediate pending feedback, rejects duplicate toggles, reports dispatch/confirmation errors and allows retry. Only real iframe events confirm Playing/Paused; background return does not automatically resume. The Public foreground-only playback boundary remains. Selected unit/flow checks passed **33/33** (`/tmp/muses-session-command-unit-2.xcresult`), standalone iframe contracts passed, and the opt-in real iframe check passed **1/1**, zero skips (`/tmp/muses-session-command-live-2.xcresult`): three Play/Pause rounds plus the actual Home/foreground lifecycle route. The observed 1.55–1.78 second confirmation intervals include XCTest polling and do not measure pure media latency. The final buffering-icon consistency edit subsequently built successfully.
- Updated MusesQA built, installed and launched on the reconnected iPhone; a direct device screenshot confirms the final + toolbar and mini-player Queue with prior content retained. Final interactive device verification is in progress. The previously verified Google configuration remains in use.
- The latest configured Public Release archive, local App Store export and distribution audit passed with unchanged production-source hashes: `/tmp/muses-remaining-signed/MusesPublic-redesign.xcarchive` and `/tmp/muses-remaining-signed/public-redesign-export/Muses.ipa`; IPA SHA-256 `9b81a6177410481f8024a2e79c186d0259b5b242c54f78dae8db8be7192bc3f2`. No upload occurred.
- The previous hosted Native UI failure was isolated to reading an empty AX frame immediately after Settings closed. Its adapter now waits for a nonempty in-window frame within the existing five-second deadline, preserving every geometry and business assertion. An isolated copy of d25825c plus this single test patch passed **2/2**, zero skips (`/tmp/muses-native-remote-36682903307/patched-baseline.xcresult`). Hosted SDK 26.6 verification of the final source remains pending.

## Remaining limits

Physical XCTest, complete VoiceOver navigation and unresolved raw system-audit findings retain their individual statuses in the follow-up reports. QA-restricted network access has been resolved and actual device search/playback confirmed by the user. The strict iPad audit has an explicit diagnostic scheme and keeps its original failing assertions/findings; default CI covers the separately verified functional scenarios. The previous hosted run for d25825c completed with identified Native AX-frame and iPad environment-variable failures; the repairs and latest source require hosted SDK 26.6 confirmation through draft PR #11. Local signing/export does not establish App Store review acceptance.

## Coordination

The main chat owns discussion and integration. Six user-requested local chats cover design, tests/CI, networking, session recovery, Privacy/Settings and Home/Library/Search; see `quality-improvement-coordination.md` for identifiers and ownership. Design: `quality-ui-design.md`; final review: `quality-ui-implementation-check.md`. Detailed workstream logs and interfaces remain in their corresponding handoff documents.

## Resumed final-source validation

- Public units **56/56**, Native units **58/58**, both distribution simulator configurations, Public capability audit, iframe contracts and workflow syntax passed. See `quality-remaining-ci-runtime.md`; these local checks use Xcode 27, with hosted SDK 26.6 still to confirm.
- Queue targeted verification passed **4/4** on the latest source: ordinary/maximum player and mini-player controls, queued-only entry, actual Queue-sheet dismissal then player presentation, and scoped clearing. Result `/tmp/muses-session-queue-placement-3.xcresult`. The previous zero-method selection used the wrong class; the corrected selection targets `PublicLocalLibraryUITests`. The floating-point comparison allows only 0.000001pt numeric tolerance and preserves the 44pt target requirement. Native mini-player geometry and Queue return follow-up passed **1/1** (`/tmp/muses-session-queue-native-geometry-2.xcresult`); the confirmed AX frame is captured before tapping to avoid a transient subsequent empty frame. See `quality-session-handoff.md`.
- iPad narrow-window follow-up passed **1/1**, retaining the earlier three passed scenarios. Actual application/window coordinate origins differ; the new assertion checks full containment within the real screen-coordinate window and preserves all menu/action checks. See `quality-home-search-redesign.md` for geometry attachments. This is not represented as one rerun of all four tests.
- Latest signed original-identifier Public archive/export and distribution audit passed, with production-source hashes unchanged: `/tmp/muses-remaining-signed/MusesPublic-resumed-final.xcarchive`, `/tmp/muses-remaining-signed/public-resumed-final-export/Muses.ipa`; SHA-256 `c0aac2415637616e68afc32f99a83d6bee9d4bbf41961899580455a264f400a3`. Existing private Google configuration is present; no upload occurred.
- Reconnected-device XCTest attempts with the standard and debugger-disabled launchers still exited during bootstrap (code 74), with no test assertions executed. USB pairing/tunnel, Developer Mode, compatible DDI and unlocked state were verified; generated test configuration points to the correct MusesQA app. An actual Developer settings UI Automation switch check is pending with the user. Evidence: `/tmp/muses-device-resumed-search.xcresult`, `/tmp/muses-device-resumed-no-debugger.xcresult`, ignored device logs and `.artifacts/remaining-quality/device-resumed-home.png`.

Physical-device method, per-check status and automation evidence: `quality-device-verification.md`.
