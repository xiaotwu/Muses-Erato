# Public / Native tests and CI handoff

## Latest current-source status

- Public full app unit suite: **51 passed, zero failed/skipped** (`integrated-final/public-unit-latest.xcresult`).
- Native common + engine units: **53 passed, zero failed/skipped** (`integrated-final/native-unit-final.xcresult`).
- Frozen UI source (19:32:40 PDT) Public Release + artifact audit and Native distribution builds: **passed**, all exit 0 (`integrated-final/*-frozen.log`). Source fingerprint check confirmed **no production/unit source changes** during those frozen builds (`source-frozen-changes.json` is empty).
- Current Native UI full suite on frozen source: **2 passed, zero failed/skipped**, command exit 0 (`integrated-final/native-ui-frozen.xcresult`). Its first current run exposed an invalid mini-player AX activation point after Settings; the Native test now waits for Settings disappearance, verifies button frame bounds and taps the element frame center. Every confirmation/control/history/layout assertion remains; no longer timeout, skip or production workaround was added.
- CI includes SDK >=26.1 verification, complete Public UI composition without Native-only scenarios, separate Native UI selection and diagnosed `-collect-test-diagnostics never` mitigation. Policy publication stays manually dispatched.

Current evidence root: `/tmp/muses-quality-ci-20260929/integrated-final`. Baseline-copy evidence below is historical and separately labeled. Public full UI acceptance is owned by coordinator, not included in this stream's passing claim.

## Configuration delivered

- `MusesTests` retains the full common Public business regressions (flow, notebook, playlist import, upgrade/cleanup and migration fixture). It no longer compiles native initializer tests.
- New `MusesNativeTests` contains `ExperimentalNativePlaybackTests` with matching `MUSES_NATIVE_PLAYBACK` conditions for Debug/Native and an explicit enabled-engine assertion. Existing generated-audio race/retry/artwork tests remain.
- Public adds `PublicPlaybackCapabilityTests` to the common test target: native engine unavailable, operations cannot emit playback events, background audio absent.
- `project-public.yml` replaces inherited schemes with `MusesPublic` and the compatible `Muses` alias; both use Debug regression and Release archive. Native/live schemes are not exposed in the Public project. Inherited native test targets remain unselected.
- Base `MusesNative` runs common + deterministic native unit tests; archives Native. `MusesNativeLive` remains explicit diagnostic only. Legacy base `Muses` also includes the native test target.
- `.github/workflows/quality.yml` checks PRs, main pushes and manual runs: all seven local package suites, Public Release / Native distribution builds, Public capability audit, Public full app+UI regressions and Native common+engine regressions. Failures upload xcresult, with no write repository permission or publication action. Existing manual policy publishing workflow is unchanged.
- Added `Sources/Muses/App/PublicSessionControllers.swift` to base app source allowlist after coordinator instruction; Public inherits it. No production sources or PublicYouTubeFlowTests were edited by this stream. No PublicSmokeTests edits were made.

## Paths and ownership

Independent simulator: `BA3E1CB0-0574-4DB0-86AD-2B521FA51A60` (Muses Quality CI, iPhone Air / iOS 26.5). Main simulator was not used. All DerivedData, logs and xcresults are under `/tmp/muses-quality-ci-20260929`. Tests on this simulator must run serially.

Xcode 27.0 (27A266a), XcodeGen 2.46.0. Native manifest's relative Info.plist requires generating the Native project in repository root, as workflow does. Public manifest requires a project two directories below repository root, as documented and workflow does. Generating Native under .artifacts without correcting its Info.plist paths fails; first local attempt proved this. Isolated Native spec adjusted only physical plist paths for that run.

## Validation

- Initial shared-workspace Public Debug full unit suite: **40 tests passed**, `/tmp/muses-quality-ci-20260929/public-unit.xcresult`, log `public-unit.log`. Includes two new Public capability tests. This ran before session controller edits were integrated.
- Seven package suites passed: Domain 9, Queue 3, Persistence 40, Networking 4, Catalog 28, Core 3, OAuth 20 = **107 tests**, `*-package.log`. Networking subsequently changed; its owner will report new recovery tests.
- Workflow YAML parses; `git diff --check` passes. GitHub Actions has not been run; runner toolchain availability remains external verification.
- Shared-workspace attempts after session edits initially failed on missing PublicSessionOperation / PublicPlaybackCheckpointController / PublicLibraryProjection, because the new source wasn't yet in the allowlist. After temporarily including the source, session controller had Track.source / TrackID-vs-UUID compile errors (`native-integrated-unit.log` lines 335–347). These are integration observations, not test split failures; session owner is modifying the source.
- Independent baseline copy from HEAD plus this stream's test/config edits is under `/tmp/muses-quality-ci-20260929/baseline`; Native regressions / Public Release audit / targeted Public search pagination UI are being verified there to isolate configuration evidence from concurrent production edits. Final results are below.

No Git commit, upload, PR, policy publication or external account change performed.

## Completed baseline verification

The baseline copy contains HEAD production code plus this stream's configuration/test edits (before controller/search allowlist additions). It does not claim verification of concurrently changing production sources.

| Run | Result | Evidence under /tmp/muses-quality-ci-20260929 |
| --- | --- | --- |
| Native Debug common + engine tests | **42 passed** (38 common + 4 native) | baseline-native-unit.log, baseline-native-unit.xcresult |
| Public Release simulator build | **passed** | baseline-public-release.log |
| Public static capability audit | **passed**; unsigned entitlement check remains unverified | baseline-public-audit.log |
| Public search pagination/retry UI regression | **1 passed** | baseline-public-ui.log, baseline-public-ui.xcresult |
| Native distribution simulator build | **passed** | baseline-native-distribution.log |

Workflow shell blocks (`bash -n`), embedded Python syntax and actual generated scheme test-target XML were checked. Public scheme list is exactly MusesPublic/Muses. Public UI composition now excludes `PublicNativePlayerUITests.swift`, whose scenarios require Native background controls. Native legacy scheme retains that file; automated Native CI runs generated-audio unit regressions, not live extraction or native UI diagnostics. CI uses setup-xcode latest-stable plus an explicit iOS simulator SDK >=26.1 check. It has not been executed remotely.

Added `Sources/Muses/Features/Public/PublicSearchScreen.swift` to the app allowlist after it appeared, per coordinator instruction. `PublicSessionControllers.swift` is also present in the allowlist. Public inherits both.

Final shared-workspace Public unit attempt (`public-current-unit-v2.log`, `public-current-unit-v2.xcresult`) is **blocked at compilation**, before any test executes: `PublicSearchScreen.swift:10` uses ambiguous `CatalogItem` (legacy Muses model vs MusesDomain); macro expansion errors follow. Session's earlier Track ambiguity is now corrected in its owned source. The preceding attempt (`public-current-unit.log`) lacked the newly referenced Search file while that file was being created. These transient shared integration failures must not be represented as passing updated production acceptance.

Next coordinator step: UI owner qualifies `MusesDomain.CatalogItem`, regenerate project and rerun common Public unit + updated UI suites; then Native integrated unit/distribution and Public Release audit. No user question is needed from this stream. Full updated UI acceptance remains coordinator/UI stream responsibility.

The dedicated CI simulator was shut down after local validation; it remains available for coordinated reuse.

## P0 follow-up: Native UI and policy tests

- `PublicPrivacyPolicyTests.swift` is now in the base MusesTests allowlist and therefore both channels. Its three tests cover missing/blank policy, versioned consent and bundled version/sections. First shared attempt failed before test execution due the same Search CatalogItem ambiguity (`privacy-unit.log`).
- Public source exclusion of `PublicNativePlayerUITests.swift` was already delivered and verified in generated pbxproj. Entire remaining Public UI suite stays selected; no Public test skipping was added.
- Added Native-only `MusesNativeUI` scheme, selecting exactly `PublicNativePlayerUITests` inside the existing MusesPublicUITests target. This target compiles PublicSmokeTests and its `addSavedVideosToLocalPlaylist` helper without selecting those Public classes to run. Generated scheme XML uses a SelectedTests whitelist and the single class identifier. No shared helper or other UI test source was edited.
- Native CI now runs `MusesNativeUI` as a separate step after common/engine units and uploads its failure xcresult. This keeps Native UI failures attributed to Native. Public manifest replaces schemes and does not expose this Native scheme.
- Native UI scenarios still assume the old Library category layout/helper path and previous Settings behavior. UI owner/coordinator should adapt those two scenarios to approved behavior rather than skip their native controls or confirmed-history assertions. Native UI suite is being exercised separately on baseline; current-source Native UI build will report integration compilation failure while CatalogItem remains ambiguous.

Additional current Native evidence: `native-ui-build.log` fails at `PublicYouTubeApp.swift:186`, before test execution: `.map { _ in legacyURL... }` captures self before checkpointNow / beforeQueueSave / requestBudgetURL / defaults / deletion closures are initialized. Session owner should reference the initializer argument (`legacyStoreURL` or its resolved local value) rather than the stored property in that closure, or assign all stored members before capturing self. No session production fix was made by this stream.

Native UI selection verification completed: **2 tests passed**, zero failures, in 246.783 seconds on the independent HEAD-production baseline, using only MusesNativeUI selection. `testHomeAndHistoryRowsPlayWithoutDetailsAndHeroCoversRemainPassive` passed (131.725s); `testNativeControlsMinimizeAndCloudSyncConfirmation` passed (115.058s). Evidence: `/tmp/muses-quality-ci-20260929/baseline-native-ui-v2.log` and `baseline-native-ui-v2.xcresult`. This verifies the scheme class whitelist and helper composition and establishes existing Native UI behavior; it does not verify new Home/Library/Settings production changes. Updated Native UI must be rerun after concurrent integration compilation blockers and old layout expectations are resolved.

Final follow-up checks: generated Public pbxproj contains PublicPrivacyPolicyTests and excludes PublicNativePlayerUITests; Public scheme list remains Muses/MusesPublic; NativeUI SelectedTests XML contains only PublicNativePlayerUITests. Updated workflow YAML/shell/Python syntax and diff whitespace checks pass. No production/UI test source was changed in this follow-up.

The final unrestricted `git diff --check` also observed a concurrent UI-stream trailing-whitespace line at `PublicPlaylistImportUITests.swift:100`. This stream's owned manifest/Native unit-test diff check passes; the shared UI file was not edited here.

## Current integrated validation rerun (2026-09-29)

Coordinator confirmed Public Debug compiles after Search/session integration repairs and requested a full current-code rerun. Current Public full MusesTests, Public Release+audit and Native distribution builds are running with logs under `/tmp/muses-quality-ci-20260929/integrated-final/`. Native full common+engine units will run after Public tests finish on the same dedicated simulator, serially. No Public UI tests are being run here; coordinator owns full current Public UI acceptance.

Projects are generated from current manifests/source allowlists. Native isolated spec only converts relative source/package/plist paths to absolute repository paths so the independent generated project can live under `.artifacts`; settings, dependencies, test composition and compilation conditions remain those in project.yml. These are current integrated source runs, separate from the earlier HEAD-production baseline copy. Source hashes were captured in `source-start.json` to identify concurrent source edits.

Current rerun first attempt executed **49 Public tests, zero failures**, but Xcode 27 then hung in `XCTHRunDestinationAllocator.collectSimulatorDiagnostics`. Stack sample `public-test-runner-sample.txt` confirms diagnosis. The incomplete result has no Info.plist; its xcodebuild was stopped (exit 143), so this attempt alone is not claimed as a completed test command. Rerun uses `-collect-test-diagnostics never` to retain XCTest logs/results while avoiding host sysdiagnose collection. CI test commands now use that same observed mitigation. Privacy view changed during the first round; both distribution builds and Public units were restarted after it, with `*-final.log` evidence.

Current integrated Native unit command completed successfully with diagnostics disabled: **53 passed, zero failed, zero skipped**, confirmed by xcresulttool summary (`native-summary.json`, `native-unit-final.xcresult`). Both Public and Native ran the new `testFailedQueueSaveKeepsCommittedStateAndScopedErrorsUntilSuccessfulEdit` and passed. Public's prior complete round had **50 passed**, zero failed/skipped (`public-summary.json`, `public-unit-final.xcresult`). Between those runs Privacy added `testInvalidLinkLeavesSettingsFeedbackClear`; it is present in Native's 53 and a latest Public full-suite rerun is now covering it.

`-collect-test-diagnostics never` is incorporated into both CI test commands after the local observed diagnostic-collection hang and successful normal result completion with the flag. This is local Xcode 27 evidence, not a claim that GitHub runners necessarily reproduce the hang. XCTest results/logs and explicit UI attachments remain in xcresult.

Latest-round evidence uses `public-unit-latest.xcresult`, `public-release-latest.log`, `public-audit-latest.log`, `native-distribution-latest.log`; source fingerprint is `source-latest-start.json`. This latest round also covers Home/Root/Search production edits observed after the prior round. Results will be finalized below.

## Completed current integrated unit/distribution results

All commands below ran against current shared-workspace production code, not the HEAD-production baseline copy. Commands completed normally (exit 0); xcresult summaries confirm no failures or skips.

| Run | Result | Evidence under /tmp/muses-quality-ci-20260929/integrated-final |
| --- | --- | --- |
| Latest Public full app unit suite | **51 passed, 0 failed, 0 skipped** | public-unit-latest.log, public-unit-latest.xcresult, public-summary-latest.json |
| Current Native common + engine units | **53 passed, 0 failed, 0 skipped** | native-unit-final.log, native-unit-final.xcresult, native-summary.json |
| Latest Public Release simulator build | **passed** | public-release-latest.log |
| Latest Public static capability audit | **passed** (unsigned entitlement boundary retained) | public-audit-latest.log |
| Latest Native distribution simulator build | **passed** | native-distribution-latest.log |

The latest Public 51 includes the subsequent invalid-link feedback policy test; Native 53 includes this and its four native engine/artwork tests. Both contain the failed editQueue recovery test. Public 50 was an earlier completed current-source run before Privacy added its final test.

Concurrent UI source updates were recorded during the latest round: PublicCatalogViews.swift, PublicRootView.swift, PublicSearchScreen.swift (`source-latest-start.json` vs `source-latest-end.json`; exact list in source-latest-changes.json). These results verify the workspace build inputs read by those commands; they are not a claim that later UI edits were frozen. Session/network/business test source stayed stable in that round. Coordinator should use its final UI acceptance/source state for the eventual final artifact rebuild.

Requested current Native UI test (both scenarios) is running separately with `native-ui-current.log` / `native-ui-current.xcresult`; its build succeeds and uses current category/helper/Settings sources. No UI test source edits made here yet. Public UI remains coordinator-owned.

Current Native UI first full run: **1 passed / 1 failed**, no skips (`native-ui-current.xcresult`). Home/history direct-play scenario passed (69.338s). NativeControls/CloudSync scenario failed after Settings dismissal and mini-player tap: full player controls did not appear, so toggle/position/queue assertions failed and Playback actions could not be tapped. Screenshots and accessibility hierarchy were exported to `native-ui-attachments/` for inspection. Failure occurs at NativePlayerUITests lines 26–30 (before the test-only follow-up edit).

Native test-only follow-up now explicitly asserts `Close settings` finishes disappearing before mini-player tap, and that the mini-player open button is hittable. This preserves every confirmation/control/layout assertion and adds a concrete modal transition precondition; no sleeps, skips, production fixes or alternate navigation were added. Failed scenario is being rerun alone as `native-ui-dismissal.xcresult` to distinguish a transition sequencing issue from a product opening issue.

The dismissal-only rerun failed earlier at the explicit hittability query: XCTest reports "Activation point invalid and no suggested hit points based on element frame" for mini-player button. Exported AX hierarchy gives a valid visible frame `{33,774,242,46}`; prior screenshot confirms the button is onscreen and Settings has disappeared. A second Native test-only adaptation asserts the button has a nonempty frame fully inside the app and taps the element's frame center, avoiding the invalid AX activation point from the system tab accessory. All actual player-control, position, queue, external-action and mini/tab layout assertions remain required. Evidence: `native-ui-dismissal.log` / `native-ui-dismissal.xcresult` / `native-ui-dismissal-attachments`; frame-center rerun is `native-ui-accessory.xcresult`. This is an observed automation issue; it is not yet evidence that the product's open action works.

The Native mini-player frame-center targeted rerun **passed** (53.418s), with every original native control/confirmation/position/queue/external-action/layout assertion succeeding (`native-ui-accessory.log`, `native-ui-accessory.xcresult`). A physical tap on the valid element frame opens the player; the observed failure was the AX activation point used by XCTest after a sheet closes, not a need for a longer player timeout. No production presentation workaround was made. The test keeps explicit Settings nonexistence and visible frame bounds preconditions and uses element-relative coordinates, not fixed screen coordinates.

Coordinator froze UI production source at 19:32:40 PDT. Final Public Release+audit and Native distribution builds are now using that frozen current source (`*-frozen.log`, `source-frozen-start.json`). Full current Native UI class (both scenarios) is being rerun on frozen source as `native-ui-frozen.xcresult`, using the test-only AX adaptation, to verify the exact CI selection in one normal completed command. No baseline-copy runs were repeated in this current validation phase.

Frozen-source final distribution evidence: both `public-release-frozen.log` and `native-distribution-frozen.log` end BUILD SUCCEEDED; xcodebuild exits 0. `public-audit-frozen.log` passes all static checks; unsigned entitlements remain unverified. `source-frozen-start.json` captured source+unit/manifests hashes and `source-frozen-changes.json` is empty. These builds cover the coordinator's frozen production source, superseding the earlier moving-source distribution rounds.

Final current Native UI full-class result: **2 passed, 0 failed, 0 skipped**, normal command exit 0, `native-ui-frozen.log` / `native-ui-frozen.xcresult` / `native-ui-frozen-summary.json`. Home/History direct-play/hero interaction passed (68.365s); native controls/minimization/cloud-sync confirmation passed (53.606s). Total suite 121.971s. Frozen production/unit/manifests hashes remained unchanged after this run (`source-frozen-end.json` matches source-frozen-start.json). Current Native UI test uses the approved updated public helper/category layout and the observed element-relative AX adaptation. Earlier Native UI failures remain recorded as diagnosis, superseded by this passing full run.

All requested current integration validation in this stream is complete: Public full unit, Native common+engine unit, frozen Public Release/audit, frozen Native distribution and frozen Native two-scenario UI. No real-stream live diagnostics, signed archive, remote Actions execution or Public full UI acceptance is claimed. Dedicated Quality CI simulator is returned to Shutdown for reuse. No Git commit/upload/PR/publication performed.
