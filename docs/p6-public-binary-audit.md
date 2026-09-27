# Public binary isolation audit

Audit date: 2026-09-27. Base commit: `891e881` (`codex/erato-integration-base`). This engineering audit applies to the local unsigned iOS Release archive after the source allowlist change. Repeat it on the exact signed distribution archive.

## Build boundary

`project.yml` now lists every main app Swift source and asset catalog explicitly. The public app compiles `PublicYouTubeApp`, `PublicRootView`, the official IFrame adapter/contract/controller factory and a small helper that names the inherited store for a non-destructive migration check. The old SwiftData schema, playback engines, cache, discovery routes, CarPlay, Watch and widget implementations remain in source control for migration or separate research. They are absent from the generated main target. The `MusesCore` package, which contains inherited Innertube IDs, is no longer a project dependency. The unit test target contains only public flow tests; inherited tests remain in source control.

The app's `@main` is `PublicAppLauncher`, which starts `PublicYouTubeApp` in Release. Debug hosted tests use a minimal scene so XCTest can bootstrap. The former launcher and service composition are not compiled. The main target has no entitlements file. The generated project has no Watch or widget targets; the main `Info.plist` no longer declares Live Activities.

## Local evidence

- Xcode 27.0, iOS 27 SDK: Debug iPhone simulator build and Release iPhone simulator build succeeded with signing disabled.
- Public unit tests passed (2/2) on the iPhone 17e simulator. A first run failed before test bootstrap while the simulator was in use; the Debug test host was then isolated and the rerun passed.
- `xcodebuild archive -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` succeeded. Local final archive: `/tmp/erato-public-final.xcarchive`. This is **not** a signed App Store archive or export.
- `python3 scripts/audit-public-artifact.py /tmp/erato-public-final.xcarchive/Products/Applications/Muses.app` passed. The archived plist has no `UIBackgroundModes`, Live Activities or CarPlay scene; the app contains no `PlugIns` or `Watch` folder. No CarPlay or App Group entitlement is configured for the main target; actual signed entitlements remain unverified because this archive is unsigned.
- Executable strings contained `https://www.youtube.com/iframe_api`, `https://www.googleapis.com/youtube/v3/`, Google OAuth authorization/token/revoke endpoints and a YouTube watch link. They did not contain the tested markers for native stream resolution, Innertube, Piped, Invidious, yt-dlp, CarPlay, Watch connectivity or remote command handling. `otool -L` showed WebKit, SwiftData, SwiftUI, UIKit and OAuth/security frameworks, with no direct MediaPlayer or CarPlay framework link. String scans can miss dynamically formed requests, so a device network trace is still required.
- The archived plist had empty `MusesYouTubeAPIKey` and `MusesGoogleIOSClientID` values. Live online catalog and OAuth cannot be accepted from this artifact.

## Release gates still open

1. Build, export and inspect a **signed** archive with the final Apple team and provisioning profile. Run the audit script on its `.app`; record `codesign -d --entitlements :-`, embedded content and the exact commit/build number. Verify the final App Store Connect upload.
2. Run the public flow on physical iPhone and iPad. Capture a redacted request trace proving the IFrame request identity and showing only permitted catalog/OAuth/player endpoints, including background/lock and dismissal behavior. Test embed errors and no fallback.
3. Supply the restricted YouTube Data API key, registered iOS OAuth client, consent configuration, quota and test account. Confirm Google and Apple policy/reviewer requirements, privacy policy and App Privacy answers. Neither a successful local archive nor this static scan constitutes approval.
4. Complete the inherited library migration and recovery test before distribution to existing users. The legacy store is left untouched and currently blocks opening the new public library when found.
