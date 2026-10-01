# Physical-device verification — 2026-09-30

## Final physical acceptance

**Completed: 11 distinct UI methods passed on the paired iPhone 15 Pro against the final production implementation, zero final-method skips.** This is the union of the final passing executions listed below, not a claim that earlier diagnostic bundles were wholly successful. Those failed attempts remain recorded in the chronological sections.

| Final check | Passing evidence |
| --- | --- |
| Real configured Search | `muses-device-reauthorize-search-20260930.xcresult`, 1 method, 11.386s |
| First Open with keyboard and outside Home/Search dismissal | `muses-device-layout-final-20260930.xcresult`, 2 passing methods, 15.392/21.653s |
| Real Queue selection, full three-cycle/mode/landscape/foreground-pause/strict geometry, independent real visible playback/pause | `muses-device-final-acceptance-20260930.xcresult`, 3 passing real methods, 38.975/62.021/32.589s |
| Ordinary and maximum-text Queue full/mini routing and bounds | Same final-acceptance bundle, 2 passing fixture methods, 39.285/41.207s |
| Ordinary and maximum-text continuous Source/Type multi-selection | `muses-device-menu-playlist-final-20260930.xcresult`, 2 passing fixture methods, 31.114/38.134s |
| Complete favorite/playlist rename/reorder/delete/Queue editing and relaunch persistence | `muses-device-playlist-uninterrupted-final-20260930.xcresult`, 1 passing fixture method, **125.232s**, no failures/skips |

Bundles are local under `/tmp`; compact summaries and attachments are ignored under `.artifacts/remaining-quality`. Real tests omit catalog/media fixtures and observe external iframe events. Fixture methods establish interaction/layout/storage behavior rather than live-service output. All 278 production fingerprints match the validated signed presentation build. MusesQA was restored with a normal terminate-existing launch, clearing test launch environments; the original Muses installation and user data are retained. Google account correctness has the earlier user-operated confirmation, not a fresh interactive sign-in in this final session. Complete VoiceOver navigation remains outside this completed device pass.


Device: paired iPhone 15 Pro, iOS 27.0 (24A437), USB. Build: separately identified MusesQA (`com.xiaotwu.muses.erato.quality`), existing restricted private Google configuration. The original Muses installation is retained.

The user explicitly resumed the paused task and authorized device testing. Production changes match the final requested **Home +**, **navigation-bar Search filters**, and **Queue in player controls** layout.

| Check | Status | Evidence / limits |
| --- | --- | --- |
| USB pairing, tunnel, Developer Mode, usable DDI | Confirmed | Ignored `device-resume-details` / `device-resume-ddi` logs |
| Device unlocked | Confirmed | `devicectl device info lockState`: no passcode required, unlocked since boot |
| Latest QA build, signing and install | Passed | `.artifacts/remaining-quality/device-resume-build.log`; device install succeeded |
| App-hosted Public playback capability tests | 2 passed, 0 failures/skips | `/tmp/muses-device-resumed-capability-units.xcresult`; capability restrictions only, not actual playback or UI interaction |
| QA launch | Passed | `devicectl` launch success; physical screen capture returned 1179×2556 pixels |
| Home + / no global Queue / mini Queue layout | Confirmed by actual device screenshot | `.artifacts/remaining-quality/device-resumed-home.png`; prior content retained. Screenshot evidence validates layout only |
| Real Google login, search, visible playback before final layout update | User confirmed in earlier device session | Historical acceptance; not a new test of the final layout |
| Search filter interaction and actual results on 7b405b9 | User-operated pass | User confirmed Source/Type switching and real YouTube Developers results; physical XCTest remains unavailable. New icon/multi-select design is a later change requiring fresh verification |
| Visible playback, three Play/Pause cycles and foreground return on 7b405b9 | User reported functionally normal, low delay | Requested manual sequence confirmed; not an instrumented latency measurement. User identified moving controls/excess text requiring another layout iteration |
| Final full/mini Queue routing | Pending on physical device | Latest targeted simulator verification passed separately |
| Settings account identity and policy navigation | Pending final physical interaction | Existing account/content retained; no credentials read |

## Automation infrastructure

Two resumed attempts with standard and debugger-disabled QA launchers stopped before assertions, runner exit code 74. Standard attempt reported refused `XCTestDriverInterface` channel; the debugger-disabled variant exited due to IDE disconnection. Results: `/tmp/muses-device-resumed-search.xcresult` and `/tmp/muses-device-resumed-no-debugger.xcresult`. They are failed automation attempts, not passed device regressions or application assertion failures.

A generated build-for-testing configuration was inspected: the UI runner identifier and `UITargetAppPath` point to MusesQA correctly. The isolated QA product name and generated scheme metadata were then aligned; production identifiers are unchanged. The user confirmed the actual Developer settings **Enable UI Automation** switch is enabled. A subsequent test-without-building retry still failed before assertions with refused XCTestDriverInterface transport and runner exit code 74 (`/tmp/muses-device-ui-enabled-search.xcresult`). The switch alone did not resolve bootstrap; its cause remains unconfirmed. No repeated identical retry is planned without a relevant changed condition.

Physical tests must observe real results/player state. Installing or launching, showing an iframe surface, cached metadata, or a simulator pass does not establish a physical playback pass. If the system driver remains unavailable, distinguish observed/user-operated device checks from automated XCTest checks explicitly.

The two selected app-hosted tests executed successfully on this physical device. This narrows the current failure to UI automation bootstrap; it does not establish the cause of the refused driver connection. Final interactive checks remain pending.

After the switch-confirmed retry, MusesQA was relaunched for user-operated verification of real Search, three Play/Pause cycles and the foreground-return boundary. These manual results are pending and will be reported separately from XCTest. Queue reordering additionally requires the latest production fix, which is being validated in an isolated simulator before a new QA install.

## Latest user feedback and repaired QA

The user confirmed Search works with real results and playback functionally works with low delay. They requested an icon submit button, Filters before Settings, multi-select Source and Type, and fewer explanatory paragraphs with stable playback-control positions. Search and player workstreams are implementing this new scope; prior device passes do not validate the upcoming iteration.

Queue-repaired source 9e64b0e was installed and launched successfully after those manual checks. User-operated Queue reorder/delete/reopen/Open visible player validation has been requested and remains pending. Installation logs: `.artifacts/remaining-quality/device-queue-fixed-install.log`; direct device screenshot `.artifacts/remaining-quality/device-queue-fixed-current.png` confirms the running Home layout only.

## Queue manual result and architecture follow-up

On repaired QA 9e64b0e the user confirmed Queue reordering, Done, deletion and reopen behave correctly. They reported that selecting a Queue song/video does not start the selected item, and requested denser rows. Selecting and requesting playback for an existing queue occurrence is therefore being implemented and requires new acceptance.

The user additionally requested a new shared music/video presentation architecture with a top mode switch and a content-based default, referencing Demus and Lyra. After being informed of the official YouTube visible-player constraints, they explicitly selected **Public cover layout with a visible video region; Video mode emphasizes video**. This is display presentation, not background playback or hidden audio extraction. Reliable provider category metadata supplies music/video defaults; unknown metadata uses Video. New architecture/multi-select changes are pending verification and a fresh QA installation.

## Current presentation build and automation authorization

The accepted Music/Video design, icon search, persistent multi-select menu and compact Queue selection have been implemented. The final frozen-source MusesQA build and installation succeeded (`device-presentation-final-build.log`, `device-presentation-final-install.log` under ignored `.artifacts/remaining-quality`). Production fingerprints remained unchanged during QA and signed distribution builds. Earlier manual device passes validate the earlier build; fresh physical acceptance of this iteration remains pending.

The debugger-disabled retry `/tmp/muses-device-final-enabled-no-debugger.xcresult` ended with **Timed out while enabling automation mode**, before any assertions. A direct device capture identified the actual system **Enter iPhone Passcode for XCTest / Enable UI Automation** page. The user has been asked to enter their passcode only on the phone, retain USB/unlocked state and confirm completion. This is separate from the already confirmed Developer settings switch. No passcode is requested in chat, and no screen capture is performed during entry. The observed prompt explains this particular timeout; it does not establish the causes of earlier transport failures.

Once system authorization completes, rerun real search and playback/mode/Queue tests using the final QA source. Restore the normal QA process afterward with terminate-existing launch, so fixture environments cannot persist into user-operated acceptance.

## Authorization resumed and actual UI execution — 2026-09-30

The user explicitly requested restarting authorization and continuing, then confirmed completing the actual phone XCTest passcode prompt. The debugger-disabled runner now executes assertions. Real configured Search passed **1 executed / 1 passed / 0 failed**, 11.386s: `/tmp/muses-device-reauthorize-search-20260930.xcresult`. This is a physical iPhone pass using the real service, not the earlier simulator or manual result.

The subsequent three live player methods executed and failed on the link-opening precondition (`/tmp/muses-device-authorized-player-20260930.xcresult`), so none establishes physical playback/mode/Queue acceptance. First tap on Open while the keyboard is present dismisses the keyboard but leaves the link sheet visible. Actual device capture: ignored `.artifacts/remaining-quality/device-authorized-player-observation.png`; the button remains available with the typed URL and no player. `PublicRootView.openLink()` synchronously clears `activeTool` before starting the async catalog call, making an uninvoked action the strongest explanation rather than a slow catalog request. UIKit hit type/interference is not independently established.

A scoped production correction is authorized: protect the Open button's real UIWindow region from the outside-keyboard-dismissal recognizers, allowing its own action to dismiss focus and open the item; keep help/blank-area outside dismissal and alert/control exclusions. A fixture first-tap regression and the existing keyboard test will run locally before a new physical build. New production requires new signed/QA builds; older signed-production fingerprints do not cover this correction. Final physical acceptance remains pending.


## Protected-region build and live input diagnosis

The rebuilt QA executed four methods in `/tmp/muses-device-open-protected-live-20260930.xcresult`: the first-tap fixture passed **16.582s**; three live methods failed at link-opening preconditions. These failures do not establish real playback, modes or Queue selection. Failure events place live Open taps at **(321.69, 529.35)**, while the expanded-keyboard button occupies **(293, 161, 68, 58)**. This supports stale test layout coordinates rather than a network-loading failure. The live tests are being synchronized with actual keyboard visibility and current button geometry before a single tap; original playback assertions remain required. No final pass is claimed yet.


## Live layout synchronization result

Resolving the expanded-keyboard Open button's current geometry before one tap corrected the live opening path. `/tmp/muses-device-current-open-live-20260930.xcresult`: **3 executed / 2 passed / 1 failed / 0 skipped**. Queue selection confirmed the selected real `M7lc1UVf-VE` iframe **Playing** (not the permitted browser-block alternative), and the independent visible-player Playing/Pause method passed. The three-cycle/mode/lifecycle method failed only its first pending-state geometry sampling predicate; five later comparisons used the unassigned default CGRect.zero and are derivative failures, not observed zero-size controls. All later actual Playing/Paused confirmations, state-confirmed geometry, mode identity/time, visible media bounds, landscape and foreground pause checks completed without further failures. This method remains failed until repaired and rerun; no overall device completion is claimed.

Recorded Play/Pause observations include XCTest interaction and polling: Play 3.942/2.974/2.873s; Pause 2.944/2.858/2.896s. These are not pure playback latency measurements. Attachments under ignored `device-current-open-attachments` contain actual real Music, Video and landscape images and the Queue Playing observation.

The uncommitted Open protected-region experiment lacked independent necessity evidence after the old-coordinate cause was established and has been removed. Root/keyboard helper are restored to the committed production implementation. The experiment's successful signed export/audit is historical only; the original signed presentation artifact still matches final production, which now has test-only changes. A fresh physical fixture/real acceptance run is underway against that production.


## Original-production physical fixture follow-up

`/tmp/muses-device-layout-final-20260930.xcresult` executed **7 methods / 2 passed / 5 failed / 0 skipped**. Original production first-Open-with-keyboard passed **15.392s**, and outside-tap Home/Search keyboard dismissal passed **21.653s**, confirming the extra protected-region production registry was unnecessary for these checks.

Two multi-select methods successfully tapped consecutive choices and produced result rows, but failed the menu action identifier assertion and a later attempt to read the hidden background toolbar while the menu remained open. iOS 27 menu AX handling is being verified using actual attachments; assertions must continue to prove consecutive selections without reopening, required last-item disabling, and Channel removal inside the still-open menu. Toolbar value checks belong after menu closure.

The playlist and two Queue placement methods failed on the same input opening path, using their still-unsynchronized direct Open taps; downstream missing Favorite/player controls are derivative failures. Shared current-coordinate single-tap synchronization is being applied to these helpers. Their functional layout/edit assertions remain unvalidated physically until the corrected scripts execute. Production source remains unchanged.


## Final-production eight-method acceptance — first execution

`/tmp/muses-device-final-acceptance-20260930.xcresult`: **8 executed / 6 passed / 2 failed / 0 skipped**. Final committed production, with no Open-region registry:

- Real Queue selection confirmed **Playing**, 38.975s.
- Full real three-cycle/mode/landscape/foreground-pause and strict same-snapshot geometry passed, **62.021s**. Three Play observations: 2.857/2.906/2.907s; Pause: 2.902/2.871/2.883s, including test interaction/polling.
- Independent real visible-player Playing/Pause passed, 32.589s.
- Ordinary multiselect passed, 30.980s.
- Queue full/mini routing and layout passed ordinary **39.285s** and maximum text **41.207s**.

Maximum-text multiselect failed only because the persistent menu scrolled the fixed top-source verification button offscreen. Recording confirms Type choices remain visible and all later selections/result/last-item disabling checks succeeded. The test now checks the just-selected visible choice in the same still-open menu, retaining no-reopen semantics. The full playlist method passed initial link opening and actual reorder, but its Save tap left the rename alert open; subsequent title/relaunch failures cannot establish a persistence bug. Current Save geometry/input is being verified before a complete method rerun. Remaining failed methods will not be counted as passes until rerun.


## Menu/rename follow-up and environmental interruption

`/tmp/muses-device-menu-playlist-final-20260930.xcresult`: ordinary multiselect **31.114s** and maximum-text multiselect **38.134s** both passed. The complete playlist method executed, and its corrected exact Night input/Save/alert-dismissal/rename checks passed. The earlier add-videos Done tap was intercepted by a system notification banner, opening an external foreground application. The add-videos sheet consequently stayed open; the Edit tap had no valid hit point, so the playlist drag never occurred. Later Queue drag actually reversed its order, but its expected labels depended on the unperformed playlist reversal. This is a failed, environmentally interrupted method, not an application-edit or locale defect. The prior eight-method recording did confirm real playlist reorder before its separate rename failure.

No production or locale changes are made. A test precondition now requires the add-videos sheet to disappear within five seconds before editing, failing and returning on interruption rather than generating downstream order errors. The existing Edit/drag/rename behavior remains unchanged. The user was informed to keep the phone idle and avoid notification banners during the final isolated complete-method rerun. External application imagery is not displayed or used to diagnose unrelated private content.

All **278 production files** match `presentation-final-production-end.json`, confirming the original signed presentation archive/IPA still covers the final app code. Ignored `final-production-match.json` records zero changed production files.


The final isolated complete playlist method passed **125.232s**, `/tmp/muses-device-playlist-uninterrupted-final-20260930.xcresult`, after the notification interruption had cleared. Every original playlist/Queue actual-order, exact-label, Cancel/delete/favorite and relaunch assertion was exercised. No production edits or alternative expected order were used.
