# P0 build, test and device record

Recorded 2026-09-27 on macOS with Xcode **27.0 (27A266a)** and iOS Simulator SDK 27.0. All tests ran against the working-tree snapshot described in `p0-baseline.md`; no clean checkout or release archive was built. Commands use the branch worktree unless an explicit directory is shown.

| Check | Command / environment | Result | Limit |
| --- | --- | --- | --- |
| Target inventory | `xcodebuild -list -project Muses.xcodeproj` | `Muses`, `MusesWidgets`, `MusesWatch`, `MusesTests`; schemes `Muses`, `MusesCore`, `MusesWatch` | Project resolves local `MusesCore`; no signature or archive check. |
| Core unit tests | `swift test --package-path Packages/MusesCore` | **3/3 passed** | Pure package tests, do not exercise app playback or UI. |
| iOS Debug build | `xcodebuild -project Muses.xcodeproj -scheme Muses -configuration Debug -destination 'platform=iOS Simulator,id=32E2039F-75EB-4982-BD4B-42220F18A42E' -derivedDataPath /tmp/muses-erato-p0-derived CODE_SIGNING_ALLOWED=NO build` | **BUILD SUCCEEDED** for iPhone 17 / iOS 26.5 simulator | Compile/link only. Signing disabled, so App Group and CarPlay entitlement validity are not proved. Warnings: deprecated route button and SwiftData revision properties; asynchronous alternative suggested in stream engine; AppIntents metadata skipped. |
| macOS reference tests | `swift test --no-parallel` in `/Users/xiaotwu/Code/Muses` | **671 tests / 92 suites passed** | Source macOS dirty tree; test suite includes yt-dlp stream behavior, which is not the iOS public playback contract. |
| iOS app tests | `xcodebuild -project Muses.xcodeproj -scheme Muses -configuration Debug -destination 'platform=iOS Simulator,id=32E2039F-75EB-4982-BD4B-42220F18A42E' -derivedDataPath /tmp/muses-erato-p0-derived CODE_SIGNING_ALLOWED=NO test` | **TEST FAILED:** XCTest 86 executed, 2 failed; Swift Testing 7 passed | Existing tests include private-interface parser and native-stream expectations; cannot promote public IFrame row. Result bundle: `/tmp/muses-erato-p0-derived/Logs/Test/Test-Muses-2026.09.27_14-41-27--0700.xcresult`. |

The two XCTest failures are baseline expectation mismatches in the inherited dirty tree: `HomeDualModeTests.testRecommendationModeDefaultsToMuses` expected `muses` but got `youtubeMusic`; `InnertubeSearchParserTests.testCatalogBrowseIdsAreStable` expected `FEcharts` but got `FEmusic_charts`. P0 did not edit code or tests to make this snapshot green. The latter tests an internal browse ID that is outside the public Data API path; P2/P3 should decide whether it still expresses a valid contract. The former requires product-default review when P4 integrates Home.

## Device and distribution limits

Installed simulators: iPhone 17/17e/Air/17 Pro Max and several iPads on iOS 26.5; iPhone 18 Pro on iOS 27.0. They were shut down at inventory. `xcrun devicectl list devices` showed only simulated devices, with no connected physical iPhone/iPad; no installed iOS 18 runtime was identified. Therefore minimum-version UI, real IFrame playback, OAuth redirect, route/interruption, battery/memory, Watch/CarPlay and signing are **not verified**. A simulator Debug build does not demonstrate App Store eligibility, TestFlight install, or an Ad Hoc IPA. No Google Cloud quota allocation, registered iOS OAuth client, YouTube permission letter, CarPlay managed-entitlement approval, or App Review response was available for inspection; those gates remain open.

## Next verification matrix

| Gate | Minimum environments and case | Owner |
| --- | --- | --- |
| IFrame | Physical supported iPhone and iPad, public embeddable and blocked videos; play/next/leave/background/return/network loss, actual sound and visible surface | P1 |
| Domain / store | SwiftPM contract tests; old iOS store fixture into new schema, corrupt store recovery, queue generation/restart without auto-play | P2 |
| Catalog / OAuth | Fake HTTP plus real test account on iPhone; native callback/PKCE, consent/revoke, page gaps, 429/403/quota exhausted, delete private cache | P3 |
| UI | iPhone small/large, iPad portrait/landscape/split width, iOS minimum and current, VoiceOver, Dynamic Type, Reduce Motion/Transparency | P4/P6 |
| Distribution | Signed device build, entitlement approval, privacy labels, reviewer account and policy evidence, TestFlight, archive inspection | P6 |

Do not mark a gate complete from class names, source tests of an old path, or the ability to install an IPA.
