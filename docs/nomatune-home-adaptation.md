# Home content and compact Library toolbar

## Reference review

Reviewed [NomaTune](https://github.com/Shahdullah/NomaTune) at commit d62a74900ab1ea6adc53fa8e47d01399f77edab7: screenshots/home.jpeg, HomeScreen.kt, HomeViewModel.kt, innertube/pages/HomePage.kt, MusicService.kt, StreamChunkResolver.kt and PlaybackStreamRecoveryTracker.kt. Its home combines category/mood entry points, quick picks, speed dial, keep-listening collections and paginated server shelves. Its playback infrastructure uses Android Media3/ExoPlayer, client-specific HTTP request profiles, expiry-aware URL caches and bounded stream recovery.

Muses uses independently written SwiftUI views and its existing services. No Kotlin source, artwork, Android UI implementation or GPL-licensed code is included. The reference is GPL-3.0; this change adapts information hierarchy and general interaction ideas. Existing Liquid Glass/native iOS navigation and playlist hero decks stay authoritative.

## Library

The count, Cards/List control and clear action share one HStack. The two display buttons use symbols only, retain the capsule background/selected fill, 44-point targets, VoiceOver names and stable identifiers. Display state belongs to PublicRootView and is bound into PublicLibraryHeroShelf; there is no second selector inside the content. The state survives category changes. All collection membership/deletion confirmation logic is retained.

## Home hierarchy

1. Horizontal mood shortcuts: Relax, Focus, Energy, Feel good, Live. These perform explicit YouTube searches; they are not claimed to be account-derived server filter chips.
2. Featured cloud shelf with portrait artwork, original server titles and direct song playback. Personalization is labeled only when the response confirms a signed-in session; public recommendation/account fallback notices remain.
3. Keep listening: real current/recent tracks as filled portrait artwork cards, with direct resume/play.
4. Quick picks: a compact two-column grid from favorites and playlist members, deduplicated and capped at six; accessibility text sizes use one column.
5. Recently played: horizontal artwork rail, with See all opening Library History.
6. Local playlists and account YouTube playlists: horizontal cover shelves, preserving names. Local playlists start playback; account playlists open the existing read-only in-app collection route.
7. Remaining server shelves and an explicit More recommendations action when a page continuation exists.

The screen uses lazy vertical/horizontal containers, semantic fonts, system colors, rounded image surfaces and glass functional controls. Empty local content does not create placeholder song/artist identities. A new PublicHomeContent.swift owns the local-home components; the root owns navigation/search actions.

## Content plumbing

Music home retains the server's shelf ordering. Page-level continuation tokens are read only from section-list containers, excluding inner carousel continuations. Additional pages merge matching shelf IDs and deduplicate card IDs. Repeated continuation tokens stop pagination. Loading, retry, cancellation and account-scope/generation checks protect refresh and account changes. Empty terminal pages are accepted. Refresh invalidates old pagination work. Requests use the existing first-party-only OAuth boundary; no browser cookies or OAuth credentials go to an extractor.

Cloud playlist cards open in-app playlist details when their endpoint supplies an actual playlist ID; radio/mix IDs beginning RD and unsupported browse-only destinations retain the website path. Discovery reads never import or overwrite playlists automatically. Metadata names can refresh through the existing guarded read path.

## Playback findings

The Android backend cannot link into AVPlayer. Muses already implements a process-memory URL candidate cache, failed-format rejection, one automatic retry, an explicit Retry action, generation guards and website fallback. This Home round keeps that audio engine intact; an Android README advertising background playback is not evidence of an iOS/App Store-compatible implementation. Client-profile/expiry handling is a potential future native-resolver improvement requiring separate stream tests, not an advertised new backend in this change.

## Acceptance

Automated parser checks cover real endpoints/login evidence and page-vs-carousel continuation selection. A separate opt-in live test exercises the anonymous first-party home and continuation without account credentials. UI checks cover Home/account normal and accessibility text sizes, direct Home/history playback, the count-row selector alignment and icon-only labels. Initial selector testing exposed a parent accessibilityIdentifier overriding child button IDs; the parent ID was removed while preserving each button's identifier. Final evidence is recorded below after the gates complete.

Final evidence:

- `/tmp/erato-home-layout-final-tests.xcresult`: two parser tests and three UI tests passed. The UI tests include normal/large text Home/account, direct Home/history playback, count-row selector alignment, and icon-only Cards/List labels. Screenshots of the featured Home and compact Library toolbar were visually inspected. Their content is explicitly isolated fixture data.
- `/tmp/erato-home-continuation-live.xcresult`: actual anonymous first-party browse and pagination passed on the simulator, returning two initial shelves and three additional shelves. The earlier live run returned an empty continuation because visitor context was missing. The service now keeps the server-returned visitor context in memory only, resets it when account scope changes, and rejects old-generation responses. No cookies or new persisted credentials are introduced.
- Debug signed device and public Release build gates passed. Final phone installation and launch are recorded after the final build below. Public Release remains without the experimental native extraction/background composition.
- Exact personalized recommendations still depend on the first-party endpoint accepting the account session; the interface preserves the public fallback notice and does not claim public content is personalized. Device UX preference and actual account-specific results require user review.

Deployment evidence: `/tmp/erato-home-install-build.log` passed for the final signed Debug app. It was installed on the connected iPhone without uninstalling or clearing user data. `/tmp/erato-home-caption-final.xcresult` passed the final compact-source-header Home/account UI check after visitor-scope isolation and radio/mix website routing. `/tmp/erato-home-release-build.log` passed the public Release gate. User review of the final Home layout and account-specific recommendations remains pending.


## Superseded Home presentation (2026-09-28)

The user subsequently chose to remove recommendation content because account personalization is not reliable with the current OAuth session. The live 2+3-shelf pagination result above demonstrated anonymous/public browse only. Home now uses Recently Played and On YouTube account playlists, with a YouTube Music website entry. The recommendation model is no longer instantiated by Home and no browse request is triggered by Home load/refresh. Artists and Albums placeholder categories are removed from the public category rail. Original playlist hero decks and playback adapters are unchanged.
