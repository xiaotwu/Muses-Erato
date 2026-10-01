> Engineering reference retained from the previous README. The current README is the product introduction.

# Muses-Erato

Muses-Erato is the iOS 18+ port of [Muses for macOS](https://github.com/xiaotwu/Muses-Polyhymnia). The current integration targets public App Store distribution with official YouTube playback and catalog APIs. It is under development and is not ready for public release.

## Current public implementation

- Visible official YouTube IFrame playback with Music/Video layouts, a persistent player surface and fixed playback controls. Music shows cover artwork alongside the visible video; switching layouts preserves playback.
- Official YouTube Data API search and Google sign-in with OAuth/PKCE.
- Local saved videos, favorites, listening history and editable playlists.
- Account-owned playlist and YouTube Music share-link import, with ordered repeated entries and atomic local save.
- Four Library categories: all saved videos, local playlists, independent favorites and confirmed playback history, with adaptive cards/lists and scoped deletion.
- Notes and time bookmarks, with paused positioning in the visible player.
- Compact Queue rows support selecting an existing entry for playback, reordering/removal and **Clear Up Next**, with save-failure feedback.
- Content-first Home with a + menu, icon search submission, multi-select Source/Type filters before Settings, Queue in player controls, and adaptive iPhone/iPad navigation.
- A concise first-launch consent sheet and a complete, sectioned policy in Settings > Privacy.

Google sign-in, search, visible playback, queue controls and account playlist import/counts/playback have been exercised on a physical iPhone. Automatic loading and original-name refinements are being completed. Notes/bookmarks, migration activation and recovery have simulator/package evidence; live bookmark positioning and final migration/retention acceptance remain open. See [implementation status](docs/implementation-status.md) for exact evidence and remaining gates.

## Playback boundary

The public build uses a visible YouTube player and stops playback when the player closes or the app enters the background. It does not deliver background music, audio extraction, media downloads, EQ, lossless/Hi-Res/Dolby playback or hidden remote playback. Background music remains a requested capability requiring an authorized source or separate permission. See [YouTube Developer Policies](https://developers.google.com/youtube/terms/developer-policies#i-additional-prohibitions) and the [architecture and migration plan](docs/ios-port-research-plan.md).

Some inherited native-audio and resolver files remain in the repository for migration/research. Their presence does not make them part of the public app: `project.yml` explicitly lists the public sources.

## Architecture

| Area | Location |
| --- | --- |
| Public app and local store startup | `Sources/Muses/App/PublicYouTubeApp.swift`, `PublicStoreLocation.swift` |
| Public UI | `Sources/Muses/Features/Public/` |
| Official embedded playback | `Sources/Muses/Platform/iOS/YouTubeIFrame/` |
| Value models, queue and persistence | `Packages/MusesDomain`, `MusesQueue`, `MusesPersistence` |
| Network, catalog and quota handling | `Packages/MusesNetworking`, `MusesCatalog` |
| Google OAuth and token storage | `Platform/iOS/OAuth/` |
| Inherited store migration proof | `Sources/Muses/Persistence/LegacyMigration/`, `Tests/LegacyMigrationTests/` |

## Build

Use Xcode with an iOS 26.1+ SDK and XcodeGen; the application supports iOS 18+ with availability fallbacks. A connected device additionally needs development signing. Generate the Public composition and build using an available simulator:

```sh
mkdir -p .artifacts/public-project
xcodegen generate --spec project-public.yml --project .artifacts/public-project --project-root .
xcodebuild -project .artifacts/public-project/MusesPublic.xcodeproj -scheme MusesPublic \
  -destination 'platform=iOS Simulator,name=<available iPhone simulator>' \
  CODE_SIGNING_ALLOWED=NO build
```

For live search and sign-in, configure the project API key and iOS OAuth client through the [private local configuration workflow](docs/local-google-configuration.md). Keep credentials outside Git. Both API-key and OAuth-backed catalog requests consume Google project quota; OAuth is not a quota bypass. Embedded playback, including known video links, requires a successful Data API content-status check. If configuration, quota or network access prevents verification, use the explicit YouTube website action. Local saved-item search remains available.

The experimental composition is generated from `project.yml` in the repository root. Its `MusesNative` scheme runs deterministic native-engine tests and archives with the `Native` configuration; `MusesNativeLive` is a separate live diagnostic. Public and Native test results describe different capabilities.

## Verification and release

Run app tests with the same scheme/destination and `test` instead of `build`. Package tests run with `swift test --package-path Packages/<package>`. Store migration, signed artifact inspection, privacy inventory, TestFlight and App Review remain release gates; see [release readiness](docs/p6-app-store-readiness.md). Migration has process-termination/activation proof and a runnable reviewed successor, but original-file retirement and unknown historical data still require a concrete preservation review. App Store export/signature verification is available through `scripts/audit-distribution-ipa.py`; it does not upload or establish store approval.

## License

MIT. Ported and adapted from [Muses](https://github.com/xiaotwu/Muses-Polyhymnia).

## Muses family and website

[Project-Muses](https://github.com/xiaotwu/Project-Muses) is the shared website and release hub. [Polyhymnia](https://github.com/xiaotwu/Muses-Polyhymnia) is the macOS product reference; iOS adapts its library and queue concepts while retaining Public/Native playback boundaries. The local checkout lives at `Project-Muses/Muses-Erato`.

Public website: [iOS support](https://xiaotwu.github.io/Project-Muses/ios/) · [Privacy](https://xiaotwu.github.io/Project-Muses/ios/privacy.html) · [Terms](https://xiaotwu.github.io/Project-Muses/ios/terms.html). `scripts/build-privacy-site.py` checks the policy locally; the parent repository publishes its reviewed output. This repository does not deploy Pages. Native signing, export and build gates remain platform-owned.
