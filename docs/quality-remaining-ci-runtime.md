# Remaining CI / runtime validation

Date: 2026-09-29–30 (America/Los_Angeles). Local CI/runtime work completed; subsequent remote execution remains coordinator-owned. Coordinator owns commit/push/PR/dispatch and physical-device signing; this stream performs local validation and read-only GitHub inspection.

## Final local outcome

- Whole phone Public suite, one invocation of current generated composition: **30 passed / 0 failed / 2 explicit live skips**, total32, exit0. Result `/tmp/muses-quality-remaining-20260929/public-ui-current.xcresult`; summary `public-ui-current-summary.json`; 867.860 seconds test execution. iPad class excluded by scheme, not counted as idiom skips. New live/iPad files compiled in this build. Later new Settings contrast test was added after compilation and has owner evidence; not included in this32.
- Official iOS18.2/22C150 imported, available, actually booted; four selected Public UI checks **4 passed / 0 failed / 0 skipped**, exit0. Earlier CLI “unavailable” outcomes are superseded for achievable runtime18 coverage by the successful portal18.2 route.
- Final CI/spec routing validated using actionlint1.7.12, YAML, shell/Python and generated XML. MusesPublicAccessibilityAudit remains a strict optional diagnostic with raw findings, not a pass.
- Default Public Release rebuilt/audited successfully after plist metadata update. Real hosted execution is not claimed from local checks. Coordinator has separately committed/pushed; this stream made no commits or remote writes except explicitly authorized coordination messages.

The phone suite's start/end fingerprints differ due to concurrent owner fixes and own manifest routing. Full list: `public-ui-current-changes.json`. Package/API decoding changed after its build; this UI result does not prove the final branch freeze. Per coordinator instruction, no third whole local suite was started; final remote CI covers the newer freeze. Runtime18 start/end production/Packages/Platform hashes match, with only owner iPad test class split differing after compilation. Historical progress below is retained to distinguish initial unavailable/download attempts and prior composition from final results.

## Full Public UI, one command

Prior frozen production/unit hashes match the workspace at start. Generated current Public project, then started one command selecting **the entire MusesPublicUITests target**, without per-method or per-class selection. Public target still excludes Native-only UI source. Dedicated simulator: Muses Quality CI / iPhone Air iOS 26.5 (`BA3E1CB0-0574-4DB0-86AD-2B521FA51A60`); no coordinator/Privacy/Home simulator used.

```
xcodebuild -project .artifacts/quality-ci-public/MusesPublic.xcodeproj -scheme MusesPublic -configuration Debug \
  -destination 'platform=iOS Simulator,id=BA3E1CB0-0574-4DB0-86AD-2B521FA51A60' \
  -derivedDataPath /tmp/muses-quality-ci-20260929/public \
  -resultBundlePath /tmp/muses-quality-remaining-20260929/public-ui-full.xcresult \
  -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO \
  -only-testing:MusesPublicUITests test
```

Log: `/tmp/muses-quality-remaining-20260929/public-ui-full.log`. Initial Source + Public UI test hashes are `public-ui-source-start.json`; final hashes and xcresult summary will be recorded on completion. No other owner's UI tests edited here.

Coordinator notified a metadata-only Info.plist repair during this run: CFBundleIdentifier now expands PRODUCT_BUNDLE_IDENTIFIER and CFBundleDisplayName expands PRODUCT_NAME, preserving defaults and enabling separate QA signing. This stream will include plist/resources in subsequent fingerprints and rebuild/audit default Public Release. Physical QA/device installation remains coordinator-owned.

## iOS 18 runtime: actual checks

Initial disk availability: about **597 GiB**. Xcode 27.0 / 27A266a is the only installed Xcode. Installed runtime images: iOS 26.5, iOS 27.0, watchOS 27.0. No iOS 18 runtime or disk image is installed; runtime registry, runtime volumes and Apple's cached signed MobileAsset catalog were read. Existing runtimes were preserved.

Apple's [supported component download instructions](https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components) provide `-downloadPlatform`, version selection and `-importPlatform`. Attempts were nonblocking xcodebuild processes, each with its own log under `/tmp/muses-quality-remaining-20260929/`:

| Requested runtime | Outcome |
| --- | --- |
| iOS 18.5 arm64 | exit 70: not available for download (`runtime-download.log`) |
| iOS 18.5 universal | not available for download (`runtime-universal.log`) |
| iOS 18.6 default architecture | not available for download (`runtime-18-6.log`) |
| iOS 18.0 default architecture | initially unable to connect to simulator; retry returned exit 70: not available for download (`runtime-18-0-retry.log`) |

Apple's public `devimages-cdn.apple.com/downloads/xcode/simulators/index2.dvtdownloadableindex` was saved as `apple-runtime-index.plist`: it lists stable 18.0, 18.1, 18.2, 18.3.1, 18.4, 18.5 and 18.6 entries using MobileAsset downloads, without a direct disk-image source URL. This is catalog metadata, not proof the current Xcode/host can retrieve and install those assets. Public MobileAsset catalog fetches returned HTTP 403; local cached catalog contains only 26.5/27.0. No signature bypass, internal asset-file mutation, global Xcode switch or runtime deletion was performed. iOS 18 actual runtime regression remains unverified until a signed official image can be installed and booted.

## Read-only GitHub findings

Repository `xiaotwu/Muses-Erato`: public, default branch main, viewerPermission ADMIN. Actions enabled; allowed_actions=all; SHA pinning not required. Default workflow permissions are read; workflows cannot approve pull requests. Repository self-hosted runner count is zero; that endpoint does not enumerate GitHub-hosted images. Remote workflows currently show only manual Publish reviewed policy site and dynamic Copilot; quality.yml is local and has not been uploaded. The selected-actions endpoint returns HTTP 409 because all actions are allowed, not a permissions denial. All gh calls were GET/read-only; no auth token value printed, commits, pushes, PRs, dispatches or repository setting changes.

## Prepared CI toolchain

The [official macOS 26 arm64 runner image](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md), retrieved on this date, reports image 20260907.0351.1, installed Xcode 26.6 (17F113), iOS simulator SDK/runtime 26.5 and existing iPhone devices. Latest file commit read via GitHub API: `0af81b6d930d02b52941d584bee9214c4bc228c6` (2026-09-11). The [runner label mapping](https://github.com/actions/runner-images) advertises macos-26 as arm64. This is the installed-image contract, not execution of our job.

Updated quality.yml to explicitly select **macos-26 + Xcode '26.6'**, matching that image instead of floating macos-latest/latest-stable. Kept SDK >=26.1 verification. Simulator selection now chooses the highest available iOS 18+ runtime **no higher than the selected simulator SDK**, so an unrelated/newer installed runtime cannot be chosen accidentally. [setup-xcode's documented SemVer input](https://github.com/maxim-lobanov/setup-xcode) supports the quoted version. Public/Native regression and publication boundaries remain as previously delivered. Remote Actions execution still belongs to coordinator and is not claimed as passing.

Final CI syntax checks, default plist expansion/Release audit, full UI result and final runtime attempt will be added below.

## Local results and updated composition (2026-09-30)

First whole-target Public UI invocation completed: **30 passed, 0 failed, 0 skipped**, exit 0, 1127.880 seconds test execution. Summary: `/tmp/muses-quality-remaining-20260929/public-ui-full-summary.json`. This generated project predates the new iPad/live files. Start/current hashes also detected owner edits to PublicHomeContent.swift and PublicRootView.swift during/after that invocation, so this is evidence for its built snapshot, not the newest source freeze.

Regenerated into `.artifacts/quality-ci-composition-next` and started a second whole phone-suite invocation with the same command options and exclusive simulator. Result `/tmp/muses-quality-remaining-20260929/public-ui-current.xcresult`, log `public-ui-current.log`, fingerprint `public-ui-current-start.json`. New iPad/live Swift files compiled successfully. Ordinary phone schemes explicitly exclude PublicIPadLayoutUITests; MusesPublicIPad selects only that class. Thus hardware-specific tests are routed to the iPad lane; do not claim them as executed phone tests or infer four idiom skips. Live tests retain their two explicit XCTest skip guards without secrets. Final runtime counts pending.

CI now creates an isolated supported iPad using the same bounded runtime as the phone, prefers Pro 13-inch, shuts down only its own phone, runs MusesPublicIPad, uploads its result on failure, and cleans up both owned devices even on failure. Existing phone suite is not run against the regular sidebar. No other owner's test file changed. Ruby YAML parsing, all 11 run blocks' bash syntax, embedded Python compilation, generated scheme XML skip/select assertions, and **actionlint 1.7.12** passed. No remote execution claimed. Local host remains Xcode 27; SDK 26.6 compilation must be confirmed by the prepared hosted job. No SDK27-only VoiceOver symbol occurs in the allowlisted test directory.

Updated default Public Release build and artifact audit passed (`public-release-plist.log`, `public-audit-plist.log`). Packaged CFBundleIdentifier is `com.xiaotwu.muses.erato`; CFBundleDisplayName is `Muses`. Unsigned audit's entitlement verification limitation remains explicit.

Apple portal fallback: in-app browser lacked login; Chrome's existing signed-in session recovered after one communication retry and reached the official More Downloads catalog. No credentials or cookies accessed, no account changes. iOS18.5 exact query returned no results; catalog visibly lists official iOS18.2 Simulator Runtime. Download/import attempt continues.

Official browser download: the signed-in Apple catalog's stable **iOS18.2 Simulator Runtime**, dated 2024-12-11, exposes the vendor disk-image link and size **8.38 GB**. Its detail notice says future runtimes are no longer served by the website and points to xcodebuild download/import. Clicked the official disk-image link; browser action timed out but a growing incomplete download appeared. No completed image/import success is claimed yet. Browser safety policy rejected `chrome://downloads/` (only HTTP/HTTPS allowed). No alternate browser-control or private download-history access used to bypass it; installation will use the completed official file, if available.

During the second UI invocation, source-owner fixes changed PublicHomeContent.swift, PublicLibraryHeroViews.swift, PublicRootView.swift, PublicSettingsViews.swift, PublicIPadLayoutUITests.swift and PublicPrivacyUITests.swift. Own project.yml change only routes iPad-specific tests out of the generic phone Muses scheme as well. Consequently the running result will be reported with its exact built snapshot and final differences; coordinator explicitly requested keeping this invocation and using final remote CI for the later freeze, without starting a third whole local suite. Networking owner also updated package API-error decoding after the build; those changes are not covered by this UI build. A package/Platform fingerprint captured later is explicitly named `package-platform-late-fingerprint.json`, not presented as a start freeze.

## Official iOS18.2 import and boot succeeded

Completed vendor file `/Users/xiaotwu/Downloads/iOS_18.2_Simulator_Runtime.dmg`. `xcodebuild -importPlatform` exited **0** (`runtime-18-2-import.log`). CoreSimulator now registers `com.apple.CoreSimulator.SimRuntime.iOS-18-2`, build **22C150**, `isAvailable=true`. Created separate Muses Quality iOS18 / iPhone16Pro **795B1D41-210F-4A34-99B1-7D9CA42F851A**; initial bootstatus completed, repeat bootstatus confirms already booted (`runtime-18-2-boot.log`). Existing runtimes preserved; system Xcode unchanged. Earlier unavailable statements apply to CLI download of18.0/18.5/18.6, not to the successfully installed portal18.2.

A temporary ignored runtime18 scheme selects four checks: existing first-consent persistence, existing initial navigation/visible iframe route, existing Made-for-Kids recovery/retry/external-action availability, and a local harness testing saved-video local search plus Library persistence. No tracked UI test or app code changed for this harness. Generation's first relative include was invalid; fixed to the absolute Public spec before building. Actual invocation/evidence uses `runtime18-targeted-v2.log` and `runtime18-targeted-v2.xcresult`; results pending. Fingerprint includes app, resources, UI, packages and Platform (`runtime18-source-start.json`).

Per coordinator instruction, strict raw iPad accessibility audit is separated into optional `MusesPublicAccessibilityAudit`, selecting `PublicIPadAccessibilityAuditUITests`. Functional CI keeps MusesPublicIPad / PublicIPadLayoutUITests. Both iPad classes are excluded from phone schemes, including generic Native Muses. Owner was explicitly asked to move the audit method into that class while retaining the strict unfiltered assertion and original failed result. Class move/last generation verification pending; this is not an audit pass. Privacy Settings strict contrast test stays in normal CI pending its own real verification.

Final composition verified after owner split: class exists; generated phone MusesPublic/Muses skip both iPad classes; MusesPublicIPad selects only functional layout class; requested MusesPublicAccessibilityAudit selects only strict audit class. actionlint and diff whitespace checks pass. CI/spec files are ready for coordinator commit. Settings contrast test remains default after owner reports its real pass.

## iOS18.2 targeted regression: **4 passed, 0 failed, 0 skipped**

Actual `xcodebuild test` completed exit0 with Xcode27 on imported iOS18.2/22C150, dedicated iPhone16Pro. Result `/tmp/muses-quality-remaining-20260929/runtime18-targeted-v2.xcresult`, machine-readable summary `runtime18-targeted-summary.json`, available/boot/download-byte proof `runtime18-available-boot-proof.json`.

- First required policy agreement gates entry, refusal remains reachable, consent survives relaunch.
- New-install navigation opens visible iframe, exposes state, closes player and enters Library.
- Fixture Made-for-Kids failure exposes restriction, disabled Play, enabled external YouTube and retry controls, and recoverable close route. This checks the fallback surface, not external app execution or live playback.
- Saved video local search finds its actual local row under On this device without pagination; Library still contains it after relaunch (temporary ignored harness).

All four used actual runtime18 UI automation. Production/Packages/Platform hashes at runtime18 start/end remain identical; test-owner audit class split changed only the UI source listed below, after compilation. This does not invalidate the four selected unchanged methods; it does not cover new audit composition.
- `Tests/MusesPublicUITests/PublicIPadLayoutUITests.swift`

## Final phone result and resource cleanup

Phone suite finished 2026-09-30 00:16:39 PDT: all32 scheduled methods completed, 30passes and only PublicLiveServiceUITests' two opt-in skips, no failures. Full log and xcresult remain at the paths above. Fingerprints `public-ui-current-start.json`, `public-ui-current-end.json`, `public-ui-current-changes.json` retain the exact8 changed tracked paths, including the4 production owner files,2 test files and2 manifests. No third full invocation.

Only this stream's iOS26.5 phone and newly created iOS18.2 simulator are shut down after evidence collection; device definitions, completed official disk image and all existing/new runtimes retained. Other owners' simulators and physical device untouched.

## Remote Native failure follow-up (2026-09-30)

Baseline head `d25825c4c32b6e3961154c05d94d34b4142f1355`, run36682903307, Native job109782216578. Distribution and units passed; NativeUI artifact11083496573 reports **1passed/1failed/0skipped** on iPhone17Pro/iOS26.5/23F77, hosted Xcode26.6. Sole failure is controls method line31, `XCTAssertFalse(openPlayer.frame.isEmpty)`. Settings disappearance and mini existence had already succeeded; subsequent frame reads/center tap, native toggle, position slider, hittable queue, Website playback, and final mini geometry assertions all passed. Post-failure Native Now Playing screenshot confirms rendered controls. This is a transient AX frame-readiness check after sheet dismissal, not evidence for the later unpushed Add menu or Play/Pause changes.

Logs retrieved read-only with `gh api --allow-escape-sequences`, redirected then ANSI-sanitized; treated only as data. Evidence root `/tmp/muses-native-remote-36682903307`: `job-sanitized.log`, artifact/NativeUI.xcresult, summary.json, all-attachments/manifest.json. Repeated artifact extraction returned existing-file error; original extracted NativeUI summary and attachments are readable.

Patch replaces mini existence-only wait with a predicate requiring existence plus nonempty on-screen frame **within the same5second budget**. Original geometric assertions and every business assertion remain. No sleeps, larger timeout, extra skip or production changes. UI owner's two new Add-menu entry changes preserved in current file. Isolated archived baseline copy receives only this readiness patch and retains baseline old entrypoint; validating its entire two-method NativeUI class locally on exclusive iPhoneAir/iOS26.5 with Xcode27 (`patched-baseline.xcresult`). This separates remote baseline diagnosis from current production edits and is not a hosted Xcode26.6 rerun. Result pending.

Native follow-up completed: isolated d25825c + readiness patch **2passed/0failed/0skipped**, xcodebuild exit0. Home/History70.027s; controls54.773s. Evidence `/tmp/muses-native-remote-36682903307/patched-baseline.xcresult`, patched-summary.json and patched-baseline.log. Comparing all tracked Swift/plist/manifests in the archived copy against d25825c confirms the only difference is PublicNativePlayerUITests.swift (baseline-source-differences.json). No production or CI change was needed. Current shared file includes the same patch plus owner's already-present Add-menu adaptations; those latest layout changes are not covered by the isolated baseline result. Hosted Xcode26.6 confirmation remains the next coordinator-owned run.

## Latest affected iOS18 regression and hosted Public follow-up

Coordinator froze current Home/Search/player production after d25825c and requested affected-only iOS18.2 checks, no live service and no full suite. Started a temporary ignored MusesRuntime18Affected scheme selecting six existing fixture tests: simplified populated Home/Add/Search hierarchy (ordinary and maximum text), empty Home, Search type change/submission/clear identity, basic new-install Add/OpenLink/player/Library route, and Made-for-Kids recovery surface. Evidence root `/tmp/muses-runtime18-affected-20260930`, `affected.xcresult`/`affected.log`, complete source start fingerprint `source-start.json`. Actual iOS18.2 iPhone16Pro795B1D41-210F-4A34-99B1-7D9CA42F851A; no other owner's simulator used. No tracked test/spec/production changes in this phase. Results pending.

Hosted baseline Public job109782216622 is still in progress; read-only GET returned no completed failure state. Job log endpoint404 while active is not evidence of an application failure. Native failure diagnosis remains separate as above. Will retrieve the completed job and any failure artifact when available.

Latest pre-final-layout iOS18 affected result: **5passed/1failed/0skipped**, exit65, `/tmp/muses-runtime18-affected-20260930/affected.xcresult` and summary.json. Only testSimplifiedEmptyHome line158 (`public.add.isHittable`) failed. Both populated Home/Add/Search ordinary/maximum text, Search draft/submitted kind identity, basic Add/player/Library route and recovery surface passed. Empty Home screenshot shows Home title and Add+ clearly visible; it does not reproduce owner's later iOS26 screenshot lacking that toolbar.

Ignored one-case empty-Add diagnostic retains a strict5s `isHittable` wait and **fails1/1**: exists=true and frame(284.7,52.3,58.3,52) valid, but isHittable=false persists across all5s. Then actual XCTest button.tap() opens Add menu; openLink/import/create entries all pass hittability assertions. Log shows system computed hit point{-1,-1}; this is not proved to be a transient readiness issue, so no timeout increase/wait-only patch applied to the owned test. Evidence empty-add-diagnostic.xcresult/log and retained AX tree/menu screenshot. No original failure has been suppressed.

Coordinator subsequently requested a further final layout (Home plus-only, Search filters toolbar menu, Queue in player/mini), owned by UI/session streams. Above result predates that change; waiting for explicit freeze before any further affected rerun. Fingerprint captured after completion is named source-post-completion.json, not asserted as an exact end-of-test snapshot.

## Hosted Public baseline completed; iPad CI environment scope fixed

Run36682903307/d25825c Public job109782216622 completed failure **before any iPad test**. Public artifact11084290430 (`quality-Public`, 13.5MB) contains Public.xcresult: **82passed/0failed/2skipped**, total84 =51unit passes+31UI passes+2live skips. Its app regression step ran07:26:33–07:53:51UTC (27m18s), UI execution1328.301s (22m08s), versus earlier local current phone867.860s; no evidence of a hung test or60m timeout. Distribution/audit also succeeded.

The iPad step created7E5EAF24-F8BF-42C9-A6B9-DFC1A046B46B, bootstatus reached terminalFinished, then shell failed `MUSES_CI_IPAD: unbound variable`. Root cause: Python appended UDID to GITHUB_ENV and the same run shell immediately tried to expand it; GitHub imports that file for later steps, not the writer's current step. No PublicIPad.xcresult exists, so no iPad application assertions executed.

Fixed quality.yml by splitting Create isolated iPad test simulator and subsequent Run Public iPad regression. Cleanup still gets envUDID, all test scopes/timeouts unchanged. actionlint, all12 run blocks' bash syntax, Python compilation and explicit writer/next-step consumer structural assertions passed. Hosted rerun remains coordinator-owned. Read-only evidence: `/tmp/muses-native-remote-36682903307/public-job-sanitized.log`, public-status.json, public-artifact/Public.xcresult, public-summary.json.

GitHub environment-file scope is corroborated by [official workflow commands documentation](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#setting-an-environment-variable): writer steps do not receive the new value; subsequent steps do.

Hosted Settings strict contrast audit passed13.669s in Public baseline, remains normal gate. Final-layout rerun has intentionally not started before the coordinator freeze signal; prior affected6/diagnostic failures remain visible. CI fix is ready for integration, no commit/push/dispatch by this stream.

## Final flat-menu Home/Search iOS18 targeted invocation

On coordinator's explicit UI-owner freeze signal, started five related existing methods only: populated simplified hierarchy ordinary/maximum text, emptyHome ordinary/maximum text, and Search type draft/submitted identity. Home is symbol-only plus; Search uses one flat filter menu with Source/Type sections. The owner replaced unreliable emptyHome AX-hittable-only check with validbounds plus actual menu-open/action assertions. Earlier raw5/6 and diagnostic failure remain preserved; this invocation tests the newly adapted behavior. No live/restriction/full-suite rerun.

Evidence `/tmp/muses-runtime18-flat-menu-20260930/flat-menu.xcresult`, flat-menu.log, source-start.json. Using previously imported iOS18.2 iPhone16Pro, existing independent runtime18 DerivedData. Session queue changes are not yet claimed frozen or validated here; waiting for separate signal before player/mini affected checks.

## Paused at explicit user request — 2026-09-30

Only the already-running final flat-menu command was allowed to finish. Result **5passed/0failed/0skipped**, xcodebuild exit0. Complete evidence `/tmp/muses-runtime18-flat-menu-20260930/flat-menu.xcresult`, summary.json and flat-menu.log. Five methods: populated Home/Add/flat Source-Type Search ordinary/maximum text; emptyHome plus actual-menu route ordinary/maximum text; Search type selection preserves submitted results until new submit, clear returns idle. No live service run or whole-suite rerun.

Start/end fingerprints saved as source-start.json/source-end.json/source-changes.json. Concurrent session/test changes listed below are retained; this result does not verify the later Queue sheet→visible player handoff, final player/mini Queue placement or queued-only recovery on iOS18. Those planned extra checks were **not started**. No new suite, remoteCI, commit/push or further code modification after the pause signal. Existing Native readiness adapter and iPad CI environment-scope fixes are prepared but hosted rerun remains unverified. Earlier affected5/6 and persistent emptyAdd AX diagnosis stay preserved, superseded only for the new owner-adapted emptyHome behavior by these real final5passes.

Resume only on an explicit human-user command. On resume: obtain latest UI/session freeze; run only the still-unverified Queue routes on iOS18 if still requested; coordinator owns integration commit/push and hosted confirmation.

Concurrent changed paths:
- `Sources/Muses/Features/Public/PublicNativePlayerView.swift`
- `Sources/Muses/Features/Public/PublicRootView.swift`
- `Tests/MusesPublicUITests/PublicQueuePlacementUITests.swift`


## Resumed integration checks — 2026-09-30

The user explicitly resumed work after the earlier pause and authorized physical-device QA. The coordinator owns that QA and the final commit/push; this workstream performed only isolated local unit, distribution compilation and read-only CI checks.

Current source snapshot verification, using Xcode 27.0 (27A266a), iOS 26.5 (23F77), dedicated iPhone Air simulator `E48EB26A-B7BF-45E6-82D7-BA46C3ACA8C8`:

- Public app unit tests: **56 passed, 0 failed, 0 skipped**.
- Native common + engine unit tests: **58 passed, 0 failed, 0 skipped**.
- Public Release and Native distribution configurations: generic simulator builds both succeeded (unsigned; arm64 and x86_64).
- Public static artifact audit passed. Signed entitlements remain unverified on these unsigned simulator artifacts.
- All current Public UI target sources compiled during the Public unit build; no UI cases were executed in this resumed check.
- iFrame contract checks passed, including stale same-video callback and blocked-playback event gating.
- `actionlint`, all 12 workflow shell block syntax checks and embedded Python compilation passed.
- Source fingerprints across `Sources/**/*.swift`, `Tests/**/*.swift` and both project specifications were unchanged from the start through the end of these checks.

Evidence: `/tmp/muses-quality-resumed-20260930`, including both `.xcresult` bundles, summary JSON, distribution logs, artifact audit log and source fingerprints. Generated projects are ignored under `.artifacts/quality-resume-public` and `.artifacts/quality-resume-native`; derived data is independent. The dedicated simulator was shut down after verification; other owners' simulators and the physical device were untouched.

Read-only hosted baseline `36682903307`, head `d25825c4c32b6e3961154c05d94d34b4142f1355`, remains completed with failure. The existing iPad `GITHUB_ENV` writer/consumer split and Native button readiness fix are retained. These local results do not establish SDK 26.6 compilation or a repaired hosted run; the coordinator's final integrated commit/push must trigger that confirmation. No commit, push, dispatch or repeated Home/Search/iOS 18 UI run was performed by this workstream.


## Hosted final head and Queue reorder repair — 2026-09-30

Run `36767943895` strictly matches integrated head `7b405b9b769c8f862f567ea5d4e7056a46d133d5` (not the earlier `d25825c` baseline). It completed with failure:

- Packages: seven package suites, **120 tests passed** under Xcode 26.6.0 (17F113).
- Native: distribution compilation, **58 units** (54 common + 4 engine) and **2 Native UI tests** passed. The repaired button frame readiness check succeeded on the hosted iOS 26.5 / 23F77 runtime.
- Public: distribution compilation and static artifact audit passed. `Public.xcresult` reports **93 passed, 1 failed, 3 explicitly skipped live tests**, total 97 (56 units; 37 UI passes; one UI failure).
- The only failure was `PublicLocalLibraryUITests.testLocalPlaylistFavoriteQueueEditingAndRelaunch`, `PublicSmokeTests.swift:178`: after dragging the queue reorder handles, tapping the Edit mode's **Done** button found no matches. The failure AX attachment shows the Library and mini player; the entire Queue sheet had disappeared. The iPad creation/regression steps were consequently skipped before execution; this run does **not** verify the iPad environment-variable fix.

The coordinator authorized a minimal fix and targeted validation. The original failure reproduced locally on a dedicated iPhone 17 Pro / iOS 26.5 simulator, with the same missing Queue sheet and Done assertion. Mini player Queue presentation state now lives in `PublicRootView`, rather than the system tab accessory, so queue updates do not replace the presentation owner. The player-local queue presentation and dismiss-before-opening-player behavior remain; both use the same Queue sheet toolbar. The existing regression only adds an assertion that Queue stays open after reordering; all reorder, persistence, removal and relaunch assertions remain intact.

Local Xcode 27 validation of the repair: **4 UI tests passed, 0 failed, 0 skipped** (the original failing local-library flow and all three QueuePlacement tests); **Public 56 units** and **Native 58 units** passed with no failures or skips; Public Release and Native distribution compilation both passed; the unsigned Public artifact static audit passed (signed entitlements are not established by this local build). No source/test/manifest changes occurred during verification. A repaired hosted SDK 26.6 run remains required after the coordinator's next commit/push.

Evidence is read-only under `/tmp/muses-hosted-36767943895`: final run/head status, complete sanitized job logs, packages/Native counts, downloaded artifact `11123567647` (`quality-Public`), hosted `.xcresult`, failure AX and activity attachments, original local reproduction, repaired UI/unit bundles and source fingerprints. No commit or push was performed by this workstream.
