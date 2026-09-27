# Public catalog browsing — 2026-09-27

Base: `e909e5332ff2a29735bcf4236d9b6e9b44be3348` (`codex/erato-integration-base` at dispatch). Isolated branch: `codex/public-catalog-browsing`.

## Delivered behavior

- Explicit video / playlist / channel searches, explicit next-page buttons, cached responses and shared concurrent GETs. No search requests on typing, scrolling or view appearance. Search failures do not automatically retry and spend additional search quota.
- Playlist details and 50-item video pages, preserving distinct playlist entries even when the same video appears twice. Channel details use `channels.list(part=snippet,contentDetails)`; uploads use the returned uploads playlist, never an extra search. Public channel playlists use `playlists.list(channelId=...)`.
- Own channel profile, playlists and subscriptions remain read-only and page on demand. Private playlist details/items explicitly request OAuth even when an API key is also configured. Missing permission, unavailable content, quota and transport failures have visible messages/retry; a failed next page keeps loaded items and its cursor.
- Home recognizes HTTPS video, playlist, `/channel/UC…` and `/@handle` links. A watch URL containing both `v` and `list` opens the video. Unsupported legacy `/c/` vanity URLs are not scraped or guessed. Known video IDs still open the existing visible official player without successful metadata lookup.
- Account & collections separates device-owned playlists/favorites/history from the read-only YouTube profile and collections. Discover explicitly states that no personalized YouTube Music feed is available.
- Reset generations discard stale search/account pages and in-flight cache fills after sign-out. Existing player implementation, client origin, keyboard dismissal and local queue layout are preserved. Settings presents its own full-screen player from the active sheet so account playlist videos can open correctly; a regression test covers opening and closing this route.

## Metadata storage audit

Reviewed the official [Developer Policies III.E.4(c–f)](https://developers.google.com/youtube/terms/developer-policies) and [derived-data policy](https://developers.google.com/youtube/terms/derived-metrics-policy) on 2026-09-27. Titles/creator names are subject to the ordinary refresh/delete limit; the extended analytics exception is not used here. Revocation deletion is described in III.D.2 and III.E.4(g).

`Track` now has optional, backwards-decodable `metadataOrigin` (`user`, `youtubeDataAPI`, `placeholder`) and `metadataFetchedAt`, in addition to existing video/source provenance. API search/link titles retain the actual fetch timestamp when saved. User-provided titles are distinguished explicitly. Old payloads with no origin/time are treated as unverified metadata, not silently marked fresh.

After 29 days, or immediately for legacy unstamped YouTube metadata, title/artist/duration are replaced with an ID-based placeholder. Track IDs, video IDs, favorite flags, history references, queue and user-created playlist names/membership remain intact. Sweep runs before startup presentation, on foreground, and hourly while active; the app cannot execute while iOS has suspended/terminated it, so an inactive installation is swept on next launch before exposing metadata. No background refresh or search is introduced. The Settings refresh action reads at most 50 IDs per call, retains user-authored titles, and records fresh timestamps. Missing API objects lose cached fields. Sign-out also removes API-derived track fields.

Catalog response cache remains memory-only, defaults to five minutes, and is capped at one hour. Expired cache entries are pruned; HTTP transport uses an ephemeral session without a URL cache. View page snapshots expire before 30 days. API titles are not copied into local playlist names. No user credentials were read or printed for this work.

Integration note: retain the small `expireCatalogMetadata()` call immediately after loading stored tracks when merging the separately developed startup migration. `Track` defaults to unknown metadata origin, so legacy mappings do not accidentally label imported provider titles as user-authored. No migration implementation or Library clear-queue region was edited here.

## iOS API key restriction identity

Google Cloud's official [Manage API keys — iOS apps](https://docs.cloud.google.com/docs/authentication/api-keys#ios) requires `X-Ios-Bundle-Identifier` for requests using an iOS-restricted key. Catalog now accepts validated, injectable `CatalogClientIdentity`; the public app passes its actual `Bundle.main.bundleIdentifier`. Only API-key requests receive this header. OAuth reads remain bearer-token requests. Tests assert the header and absence of fabricated `Referer`/`Origin` values, plus rejection of newline-containing identifiers.

This header is not app attestation or secret protection. Google recommends API restrictions alongside application restrictions and quota monitoring. Cloud configuration must allow the shipping bundle ID and restrict the key to YouTube Data API v3. Root integration reported an owner-local `videos.list` HTTP 200, but that alone does not prove restriction enforcement. **Release gate:** verify the configured restricted project key accepts the correct bundle ID and rejects absent/wrong bundle identity and disallowed APIs; no owner key or Cloud settings were accessed or modified in this task.

## Verification

Final result: **55 tests passed, zero failures** across the suites below. Release simulator build, public artifact audit and Release fixture-exclusion check passed. The Settings presentation failure found during development was fixed and all four UI flows passed on the dedicated simulator.

Fixture/unit coverage:

- MusesCatalog: 15 tests — page cursors, deduplication, repeated videos in playlists, stale request invalidation, channel uploads, OAuth with/without API key, typed search, cached pages, budget rejection and URL validation.
- MusesNetworking: 4 tests — quota/error classification, separate budgets, one reservation for coalesced concurrent GETs, cancellation isolation and no automatic search retry.
- MusesDomain: 5 tests — including backward decoding, metadata expiration and user-title preservation.
- MusesPersistence: 18 tests — existing migration/persistence regression suite.
- Hosted app unit tests: 9 tests — including API title expiry across relaunch without loss of user truth, and 51 saved IDs refreshed in exactly two calls.
- UI fixture flows: playlist/channel navigation and paging; account profile/playlists/subscriptions; search next-page failure/retry; account playlist opening the visible player from Settings.

Commands use `swift test --package-path Packages/<package>` and `xcodebuild -project Muses.xcodeproj -scheme Muses ... CODE_SIGNING_ALLOWED=NO test`. Fixture mode requires both an isolated `MUSES_UI_TEST_LIBRARY` and `MUSES_UI_TEST_CATALOG=fixtures`, is compiled only in DEBUG, bypasses credentials, and never contacts the Data API. `project.yml` explicitly allowlists the new production view and the DEBUG-only fixture transport. Release binary string checks confirm fixture data/code are absent.

Final device: dedicated iPhone 17e / iOS 26.5 simulator `F7C4C82C-6BF7-4D3A-B010-91914456EE3B`. An earlier re-run on shared simulator `780AC25A-56B5-40AF-9159-E96554EEA6D2` was interrupted because a concurrent task installed the older app. That interrupted run is not counted as passing evidence.

Logs: `/tmp/erato-catalog-tests.log`, `/tmp/erato-network-tests.log`, `/tmp/erato-domain-tests.log`, `/tmp/erato-persistence-tests.log`, `/tmp/erato-catalog-isolated-ui.log`, `/tmp/erato-catalog-release.log`, `/tmp/erato-catalog-audit.log`. Xcode result bundles are under `/tmp/erato-catalog-build/Logs/Test/`.

## Remaining limits

No new live-account or physical-device acceptance is claimed. Google sign-in, OAuth-only live search and real playback remain the previously reported integration evidence. Quota enforcement is a device-process guardrail, not a persistent/global project quota service; Google remains authoritative. No background refresh is promised. Only official APIs and the existing visible IFrame path are used; unavailable/private/non-embeddable videos have no alternate stream path. Release simulator build/static audit does not verify signing, App Store review or production runtime traffic.
