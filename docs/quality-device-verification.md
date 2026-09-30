# Physical-device verification — 2026-09-30

Device: paired iPhone 15 Pro, iOS 27.0 (24A437), USB. Build: separately identified MusesQA (`com.xiaotwu.muses.erato.quality`), existing restricted private Google configuration. The original Muses installation is retained.

The user explicitly resumed the paused task and authorized device testing. Production changes match the final requested **Home +**, **navigation-bar Search filters**, and **Queue in player controls** layout.

| Check | Status | Evidence / limits |
| --- | --- | --- |
| USB pairing, tunnel, Developer Mode, usable DDI | Confirmed | Ignored `device-resume-details` / `device-resume-ddi` logs |
| Device unlocked | Confirmed | `devicectl device info lockState`: no passcode required, unlocked since boot |
| Latest QA build, signing and install | Passed | `.artifacts/remaining-quality/device-resume-build.log`; device install succeeded |
| QA launch | Passed | `devicectl` launch success; physical screen capture returned 1179×2556 pixels |
| Home + / no global Queue / mini Queue layout | Confirmed by actual device screenshot | `.artifacts/remaining-quality/device-resumed-home.png`; prior content retained. Screenshot evidence validates layout only |
| Real Google login, search, visible playback before final layout update | User confirmed in earlier device session | Historical acceptance; not a new test of the final layout |
| Final Search filter interaction and actual results | Pending | Physical XCTest did not execute its selected Search method |
| Final play/pause feedback, sustained visible playback and foreground return | Pending | Earlier real-iframe simulator cycles passed; final physical interaction remains to verify |
| Final full/mini Queue routing | Pending on physical device | Latest targeted simulator verification passed separately |
| Settings account identity and policy navigation | Pending final physical interaction | Existing account/content retained; no credentials read |

## Automation infrastructure

Two resumed attempts with standard and debugger-disabled QA launchers stopped before assertions, runner exit code 74. Standard attempt reported refused `XCTestDriverInterface` channel; the debugger-disabled variant exited due to IDE disconnection. Results: `/tmp/muses-device-resumed-search.xcresult` and `/tmp/muses-device-resumed-no-debugger.xcresult`. They are failed automation attempts, not passed device regressions or application assertion failures.

A generated build-for-testing configuration was inspected: the UI runner identifier and `UITargetAppPath` point to MusesQA correctly. The isolated QA product name and generated scheme metadata were then aligned; production identifiers are unchanged. The user has been asked to confirm the actual Developer settings **Enable UI Automation** switch, rather than assume a previous prompt established its current state. No repeated identical retry is planned without a relevant changed condition.

Physical tests must observe real results/player state. Installing or launching, showing an iframe surface, cached metadata, or a simulator pass does not establish a physical playback pass. If the system driver remains unavailable, distinguish observed/user-operated device checks from automated XCTest checks explicitly.
