# Physical-device verification — 2026-09-30

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
