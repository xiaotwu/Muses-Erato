# Accessibility follow-up evidence

Date: 2026-09-29 (America/Los_Angeles). The coordinator requested a narrowly scoped confirmed-contrast repair after the initial freeze. This follow-up changes only `PublicSettingsViews.swift` and a focused SDK-17-compatible test in `PublicPrivacyUITests.swift`; no manifests or minimum OS versions change. Final source freeze follows the targeted contrast test below. Verification harnesses and generated projects live exclusively in ignored `.artifacts/quality-accessibility-followup` and `.artifacts/accessibility-followup-project`. The iOS 27-only VoiceOver API is not part of the public test composition and will not prevent CI from compiling with an SDK 26 toolchain.

## Actual display settings: completed

Reserved device: `Muses Privacy Settings`, iPhone 17 Pro, iOS 26.5, UDID `DE1D5F52-5046-4D64-9FDA-0309DD8855BD`. The shared iPhone Air `46441BA0-866C-4A6B-91D2-7547AC7CC613` and physical phones were not used.

The successful harness emits `[HARNESS_VERSION] 20260929-verified-display`. It uses the real system Settings app, toggles the trailing switch controls in Accessibility > Display & Text Size, and asserts readback. Original Reduce Transparency and Increase Contrast values were both `0`; enabled values were both `1`; final values were both restored to `0`. This is an OS settings change, not an app launch override.

Persistent preference inspection while enabled showed `EnhancedBackgroundContrastEnabled=1` and `DarkenSystemColors=1`. After restoration both read `0` (also `PointerIncreasedContrastEnabled=0`). Full raw snapshots: `.artifacts/quality-accessibility-followup/accessibility-initial.txt`, `accessibility-enabled.txt`, `accessibility-restored.txt`.

While both options were enabled, verified actual interactions:

- Initial policy sheet loads with Continue disabled. The complete bundled policy opens and navigation returns to the introduction.
- Not now returns to the local gate; app entry remains absent. Continue setup reopens the sheet.
- Explicit agreement enables Continue; consenting opens Home.
- Settings opens from Home and its Privacy destination opens the full policy.
- System Settings values are restored after the complete flow.

The XCTest flow passed (`TEST SUCCEEDED`): `/tmp/muses-accessibility-followup-7.log`; result `/tmp/muses-accessibility-followup-7.xcresult`. Audit results are not used to claim these interactions passed.

Screenshots exported to `.artifacts/quality-accessibility-followup/verified-display/`:

- `system-display-before.png`, `system-display-enabled.png`, `system-display-restored.png` (actual switch states).
- `policy-sheet-reduced-transparency-contrast.png`, `policy-detail-reduced-transparency-contrast.png`.
- `home-reduced-transparency-contrast.png`, `settings-reduced-transparency-contrast.png`, `settings-privacy-reduced-transparency-contrast.png`.

## Audit scope and limits

A separate exploratory `performAccessibilityAudit` collected contrast, hit-region, descriptions and text-clipping issues; the issue handler returned true **to collect every finding**, not to assert zero findings. The initial run's display toggles failed readback, so its diagnostics are a **baseline with both options off**, not evidence of enabled-mode auditing. Log `/tmp/muses-accessibility-followup-4.log` and result `/tmp/muses-accessibility-followup-4.xcresult` preserve that attempt.

Baseline flags include potentially clipped SwiftUI text, short selectable policy-version hit regions, disabled Continue contrast, onboarding secondary-text contrast, system section headers/account status contrast, and Home's YouTube Music contrast. These are automatic findings requiring visual/runtime triage, not confirmed defects: the same audit also flags primary black policy text on a white surface. Actual largest-font rendering and reachability were verified separately in the original Privacy handoff.

An enabled-mode audit attempt timed out during the first policy audit and subsequently encountered a system Preferences crash while restoring through the UI (`/tmp/muses-accessibility-followup-5.log`). That attempt is not reported as passed. OS preferences were explicitly recovered, and the final complete interaction-only run then proved both enabling and restoring via actual Settings readback. Enabled-mode zero-issue auditing has **not** been established. No app failure is inferred solely from these test-service/system-app failures. Home diagnostics are handed to the coordinating stream; this workstream did not modify Home source.

## Actual VoiceOver: partial verification, remaining paths failed

Xcode 27's installed XCUIAutomation headers provide `XCUIDevice.voiceOverService`, with `enable`, `disable`, `isEnabled`, `currentSpeech`, `moveForward`, `moveIn` and real utterance output. This requires iOS 27. An additional isolated `Muses Privacy VoiceOver` simulator was created (iPhone 17 Pro / iOS 27.0 / `A0CFFDBC-1296-450D-A876-53C0DBE2E60B`) without occupying the main simulator or a phone.

Actual initial service attempt read `isEnabled=false -> true -> false` and launched the real VoiceOverTouch process. Policy focus commands failed with `AXVoiceOverAutomationErrorDomain Code=3` / `Failed to send moveForward command`. A second attempt queried actual speech and injected two single-finger right swipes. Policy returned `No speech available`; `moveIn` reported the navigation style was not Groups; Settings forward navigation also failed. Home did return **`Open YouTube link Button`** from the actual service. The service was restored to disabled.

These results establish successful enabling/restoration and one actual Home speech/focus event. They do **not** establish a complete policy or Settings VoiceOver flow. The second harness's XCTest success means the collection/restoration procedure completed, not that VoiceOver navigation passed. Logs: `/tmp/muses-voiceover-followup-2.log` and `/tmp/muses-voiceover-followup-3.log`; results of the same names with `.xcresult`. Screenshots are exported under `.artifacts/quality-accessibility-followup/voiceover-attempt1` and `voiceover-attempt2`.

One final already-in-scope attempt enables VoiceOver before launching the app and explores titles by an actual single-finger tap before reading/moving focus. It prints `[HARNESS_VERSION] 20260929-preenabled-voiceover`; logs `/tmp/muses-voiceover-followup-4.log`, result `/tmp/muses-voiceover-followup-4.xcresult`. It has completed (`TEST SUCCEEDED` for collection/restoration). Real utterance output covered 6 distinct introduction items plus the title announced as a Heading, and 13 distinct Home items including Open link, Import playlist and the three tab positions. Policy detail and Settings returned `Failed to send moveForward command` with zero captured focus utterances; those paths remain **not passed**. The service was again restored to `isEnabled=false`. Repeated identical utterances appeared in some rapid navigation steps, so the result is described as partial focus/speech evidence, not a complete uninterrupted end-to-end VoiceOver pass. No AX snapshot or automated accessibility audit is described as a VoiceOver gesture/reading pass.

Apple primary reference for the new simulator service: https://developer.apple.com/videos/play/wwdc2026/8005/ (Accessibility Technologies Group Lab). Installed headers in Xcode's XCUIAutomation framework were inspected directly; production/CI code does not reference this API.


## Confirmed Settings contrast repair

Stable iPad audit evidence `.artifacts/ipad-quality/audit-test.log` reports low contrast for About and YouTube account. The exploratory Privacy audit also identifies Provider & support. These share a reproducible small system-secondary-text treatment; repaired by explicitly using primary text color for those headings/status while retaining their footnote/section hierarchy. No Home/Library source edits here.

A permanent `PublicPrivacyUITests.testSettingsContrastAudit` runs an unfiltered contrast audit on Settings and Privacy & support, with no handler that suppresses findings. This uses the existing iOS 17 audit API and does not toggle system settings or reference VoiceOver's iOS 27 API. Targeted audit and existing Settings navigation tests are running on the reserved iOS 26.5 simulator; log `/tmp/muses-settings-contrast-fix-1.log`, result `/tmp/muses-settings-contrast-fix-1.xcresult`.
