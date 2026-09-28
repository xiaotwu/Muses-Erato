# Muses-Erato

Muses-Erato is the iOS 18+ port of [Muses for macOS](https://github.com/xiaotwu/Muses). The current integration targets public App Store distribution with official YouTube playback and catalog APIs. It is under development and is not ready for public release.

## Current public implementation

- Visible official YouTube IFrame playback, including video links, pause and queue Next.
- Official YouTube Data API search and Google sign-in with OAuth/PKCE.
- Local saved videos, favorites, listening history and editable playlists.
- Account-owned playlist and YouTube Music share-link import, with ordered repeated entries and atomic local save.
- Horizontally scrollable Library categories, adaptive hero cards and per-item/scoped list deletion.
- Notes and time bookmarks, with paused positioning in the visible player.
- Queue reordering/removal and a Library-level **Clear Up Next** action that preserves the current video.
- Adaptive iPhone/iPad navigation and keyboard dismissal outside text inputs.

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

Use Xcode with an iOS 18+ SDK and XcodeGen. A connected device additionally needs development signing. Generate the project and build using an available simulator:

```sh
xcodegen generate
xcodebuild -project Muses.xcodeproj -scheme Muses \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO build
```

For live search and sign-in, configure the project API key and iOS OAuth client through the [private local configuration workflow](docs/local-google-configuration.md). Keep credentials outside Git. Both API-key and OAuth-backed catalog requests consume Google project quota; OAuth is not a quota bypass. Known video links can use the embedded player without Data API credentials.

## Verification and release

Run app tests with the same scheme/destination and `test` instead of `build`. Package tests run with `swift test --package-path Packages/<package>`. Store migration, signed artifact inspection, privacy inventory, TestFlight and App Review remain release gates; see [release readiness](docs/p6-app-store-readiness.md). Migration has process-termination/activation proof and a runnable reviewed successor, but original-file retirement and unknown historical data still require a concrete preservation review. App Store export/signature verification is available through `scripts/audit-distribution-ipa.py`; it does not upload or establish store approval.

## License

MIT. Ported and adapted from [Muses](https://github.com/xiaotwu/Muses).
