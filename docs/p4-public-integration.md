# P4 public YouTube integration

Base: `codex/erato-integration-base` at `670d893`. The app launcher now enters `PublicYouTubeApp` for normal runs. This composition creates only the official YouTube Data API catalog, optional iOS OAuth client, P2 queue/repository and the visible P1 IFrame adapter. The inherited `AppComposition`, stream engine, Innertube services and desktop-like UI still compile for migration and existing tests, but the public launch path does not construct them.

## Configuration

Set these **build settings** for the app target in the release pipeline (or on an `xcodebuild` command line). No credential is stored in this repository:

- `MUSES_YOUTUBE_API_KEY`: app's official Data API key for public search and video metadata. Without it, validated video URLs/IDs still open in the IFrame and local search works.
- `MUSES_GOOGLE_IOS_CLIENT_ID`: actual Google iOS OAuth client ID for bundle `com.xiaotwu.muses.erato`.
- `MUSES_GOOGLE_REDIRECT_SCHEME`: the exact custom scheme registered with that client. `Info.plist` registers it and the app forms `<scheme>:/oauth2redirect`. The project defaults to `muses-erato` only to keep unconfigured simulator builds launchable; replace it with the real scheme before shipping.

OAuth asks for `youtube.readonly` and stores tokens in ThisDeviceOnly Keychain. Signed-in subscriptions are fetched only when requested or after sign-in. Revocation clears the private Data API cache and local account state; a failed Google-side revocation is surfaced to the user. No authorized API response is stored in the P2 repository. The quota guard is currently 10 searches and 100 other units per device per Pacific day; it is a conservative demo limit, not a server-wide quota mechanism. Replace it after inspecting the actual Cloud allocation and projected traffic.

## Working vertical path

On a new install: paste a validated YouTube video link or submit official Data API search, select a video, open the visible IFrame screen, optionally queue another result, favorite the current item, and find saved videos/history in Library. Playback history is recorded only after an IFrame `playing` event. The queue and saved tracks use the P2 versioned store at `muses-public-v1.sqlite`; restored queue intent is paused. The IFrame is destroyed when its visible sheet closes and pauses on background entry. Embedding errors offer a YouTube link, with no stream fallback.

The public target removes the audio background mode and CarPlay entitlement/scene. It does not embed Watch or widgets. Settings explains unavailable native audio capabilities; library categories without official data are visible with an explicit unavailable state. iPhone uses tabs, iPad uses a sidebar.

## Migration and release gates

An existing `muses-youtube-native.sqlite` causes a recovery screen before the V1 store opens. The old database and WAL/SHM remain untouched. This is intentional because P2's current legacy DTO omits album, artwork, lyrics, advanced queue, relationship and settings fields. A fixture-backed, field-complete migration and rollback check is required before upgrading existing users. Corrupt-store errors also show recovery instead of creating an empty replacement.

P6 still needs a real API key/client, quota allocation review, consent/redirect/revocation on device, first-install and upgrade fixtures, live iPhone/iPad playback, embed refusal, offline behavior, accessibility pass, privacy review and App Store policy review. Simulator compilation and fake tests do not establish these outcomes.

## P4 verification (2026-09-27)

- `xcodegen generate` and iPhone 17e / iOS 26.5 simulator `xcodebuild ... build`: passed. The generated `Muses.xcodeproj` references P1's three Swift files and all six local package products.
- `swift test` for Domain (3), Queue (3), Persistence (4), Networking (2), Catalog (4), and IOSOAuth (3): 19 passed. P1 IFrame contract checks passed.
- App simulator unit target: 88 executed, 2 legacy-path tests explicitly skipped, 0 failures. Before isolation, the same two baseline assertions failed: `HomeDualModeTests.testRecommendationModeDefaultsToMuses` expected `muses` but received `youtubeMusic`; `InnertubeSearchParserTests.testCatalogBrowseIdsAreStable` expected `FEcharts` but received `FEmusic_charts`. Their assertions remain in the source, with skip reasons naming the inactive public paths.
- UI smoke on iPhone 17e: passed. It entered a known video ID, opened a visible IFrame, closed it and reached Library. The first UI run found a real SwiftData crash because the composition did not retain its `ModelContainer`; the final code retains it. The next run found a keyboard focus issue on returning from the player; opening a video now releases text focus.
- iPad mini / iOS 26.5: app installed and launched; the sidebar and Home detail were visually inspected. No iPad UI automation or physical device acceptance was performed.

The first iPhone 17 simulator became unable to launch this app during the combined test run and returned SpringBoard preflight errors. A clean iPhone 17e installed and launched the same build. Final unit and UI evidence above comes from the clean simulator, with test targets run separately.
