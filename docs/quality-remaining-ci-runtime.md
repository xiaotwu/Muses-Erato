# Remaining CI / runtime validation

Date: 2026-09-29 (America/Los_Angeles). Work is in progress. Coordinator owns commit/push/PR/dispatch and physical-device signing; this stream performs local validation and read-only GitHub inspection.

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

Per coordinator instruction, strict raw iPad accessibility audit is separated into optional `MusesPublicIPadAudit`, selecting `PublicIPadAccessibilityAuditUITests`. Functional CI keeps MusesPublicIPad / PublicIPadLayoutUITests. Both iPad classes are excluded from phone schemes, including generic Native Muses. Owner was explicitly asked to move the audit method into that class while retaining the strict unfiltered assertion and original failed result. Class move/last generation verification pending; this is not an audit pass. Privacy Settings strict contrast test stays in normal CI pending its own real verification.
