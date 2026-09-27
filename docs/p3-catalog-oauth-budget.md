# P3 Catalog, OAuth and quota evidence

Status: package implementation and fake HTTP tests complete; production wiring and real Google/device acceptance pending P4/P6. Baseline `6dc19ba`, branch `codex/erato-p3-catalog-oauth`.

## Public boundary and P4 interface

- Products: `MusesNetworking`, `MusesCatalog`, `MusesIOSOAuth`. Add their local package references and iOS target dependencies in the P4-owned `project.yml`/Xcode project. No public path to Innertube, yt-dlp, Piped, Invidious, stream URLs or media downloading exists in these products.
- `YouTubeDataCatalog(apiKey:credential:transport:ledger:budget:)` calls only `www.googleapis.com/youtube/v3/{search,videos,playlists,playlistItems,subscriptions,channels}`. It exposes explicit page tokens, `complete`, `source`, `fetchedAt`, a local-first `CatalogDiscovery` and endpoint request counts. `search` is for user submission or a deliberate debounce, not each keystroke. Each further page requires a separate call. `artist` can map to `channel`; the official Data API has no YouTube Music release entity. P4 must expose that gap rather than synthesize a release.
- P2 owns final `VideoID`/`ChannelID`/`CatalogItem`/page contracts. This branch started before the P2 package was present, so `MusesCatalog.CatalogItem` is a temporary provider-facing value. P4 maps validated provider IDs into P2 types at the boundary; no Data API DTO leaves the adapter. Do not directly persist this temporary type as user truth.
- `OAuthConfiguration` requires an iOS client ID and custom native redirect URI. `OAuthAttempt` makes a fresh S256 PKCE verifier/challenge and state. `IOSAuthorizationSession` uses `ASWebAuthenticationSession`; `OAuthClient` exchanges/refreshes/revokes; `KeychainOAuthTokenStore` uses ThisDeviceOnly Keychain storage. Only `youtube.readonly` is requested. Public/guest calls use an API key; private calls use the OAuth credential. No write scope or desktop loopback callback is enabled.
- P4 must register the exact redirect scheme in the P4-owned Info.plist, provide its actual Google iOS OAuth client and bundle ID, pass a UIWindow presentation anchor, and use `OAuthClient` as `CatalogCredential`. Supply `PrivateAccountData` that clears the P3 private response cache, P2 authorized persistence and private UI state on revoke, local deletion, account replacement or invalid refresh. Call `clearPrivateCache` on `YouTubeDataCatalog`; public metadata may remain. Provide a visible local-data deletion action and explain that this does not delete YouTube data.
- A private result cache lives only in this actor's memory, has a default 5-minute TTL and a hard 1-hour TTL ceiling. No media bytes are cached. Local saved items are a separate user-data port; P4 owns their persistence/deletion policy. Do not persist authorized API data beyond the policy limit without refresh or active-consent checks.

## Budget and failure behavior

The [official quota calculator](https://developers.google.com/youtube/v3/determine_quota_cost) currently lists 100 `search.list` calls/day in a separate bucket and 10,000 units/day combined for other methods by default; each additional page is another request. The actual Cloud project allocation has **not** been inspected. The following table is a planning estimate, not measured production traffic.

| Action | Endpoint | Calls per action | Default bucket cost | At 20 DAU |
| --- | --- | ---: | ---: | ---: |
| Submitted search, first page | `search.list` | 1 | 1 search call | 20 search calls for 1/person |
| User requests five search pages | `search.list` | 5 | 5 search calls | 100 search calls; entire default bucket |
| Known video metadata, up to 50 IDs | `videos.list` | 1 | 1 other unit | 20 units for 1/person |
| Account start, first page | `channels.list`, `playlists.list`, `subscriptions.list` | 3 | 3 other units | 60 units |
| Open playlist, two pages | `playlistItems.list` | 2 | 2 other units | 40 units |

`GETCoalescer` shares active identical GETs, cancels the underlying task after its last waiter leaves and retries only 429/5xx up to two times with short bounded backoff. Each physical attempt is counted by `RequestLedger` and consumes one `RequestBudget` reservation. `RequestBudget` is an optional **device-side** guardrail with separate search/other caps resetting on the Pacific calendar day; it cannot enforce a shared Cloud-project budget. P4 should configure a conservative per-device cap after inspecting the actual allocation and projected DAU. Never use multiple Cloud projects or user developer keys to bypass the project quota.

403 quota errors, other 403, 429 with Retry-After, 5xx, 401, network and invalid-response errors are distinct. Search quota failure preserves local results and exposes `onlineError` for the UI. There is no private API fallback. The in-memory cache avoids repeated calls for identical requests for five minutes; ETag or HTTP 304 is not assumed to be quota-free. No live usage or cache-hit rate has been measured.

## Verification and remaining gate

- macOS SwiftPM tests: `MusesNetworking` 2, `MusesCatalog` 4, `MusesIOSOAuth` 3; fake responses cover pages, quota, private-cache purge, PKCE state, exchange, revoke and deletion. A failed remote revoke still deletes local tokens/data and returns an error; the UI must tell the user Google-side access may remain and link to Google's security settings.
- iOS 18 simulator-target package build: successful for all three products through the OAuth dependency graph. This establishes compilation, not app launch or native callback behavior.
- No Google API key, iOS OAuth client, test account, Cloud quota allocation or physical iPhone/iPad was available. Real consent, redirect, refresh, account switching, revocation, pagination changes, quota dashboards and cache deletion across installed app storage remain P4/P6 acceptance work. App Store readiness is unverified.

Source policy: [YouTube API data storage and deletion](https://developers.google.com/youtube/terms/developer-policies), [Google installed-app OAuth](https://developers.google.com/identity/protocols/oauth2/native-app).
