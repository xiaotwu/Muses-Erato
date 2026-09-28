# iOS Music Home adaptation

## User-requested scope

Home must include local Muses recommendations and cloud YouTube Music recommendations, using successful macOS API paths where possible. Public discovery must not be labeled personalized simply because OAuth is configured. The user accepts reconsidering distribution when required functionality cannot fit the public App Store path.

## Reused macOS mechanisms

- `Sources/Muses/Services/Discovery/MusesHomeProvider.swift`: local playlist/history/favorite shelves; the public composition derives membership from persisted Domain snapshots instead of constructing the legacy LibraryService.
- `Sources/Muses/Services/Discovery/YouTubeMusicHomeProvider.swift` and `Innertube/InnertubeHomeParser.swift`: `FEmusic_home` browse endpoint and normalization of server carousel titles and real video/playlist/browse endpoints. The adaptation is browse-only; legacy player/stream/download/EQ services are not constructed.
- `YouTubeMusicAccountSession.swift` and `InnertubeClient.applyAuth`: optional first-party OAuth bearer header. The existing iOS OAuth client refreshes the token; it is sent directly to music.youtube.com, not logged, exported, persisted in the Home cache or sent to a developer server.

## Implementation and truthful states

`PublicMusicHomeService` bootstraps the Music client version from the first-party website, requests browse Home, normalizes supported carousel renderers and keeps server shelf titles/order. Responses are bounded to 8 MB. An ephemeral URLSession does not read or persist browser cookies. Home caches normalized results in memory for five minutes and supports pull refresh and retry. Local shelves render independently of network requests.

The account path is attempted with the existing OAuth permission. Only a response containing the authenticated `logged_in=1` signal is labeled Your recommendations. An accepted HTTP request or a locally signed-in state alone is insufficient. A rejected/unconfirmed account response leads to a visible account-availability notice and an explicitly labeled public feed. The real Music website remains available for its independent browser-session Home. No Safari/macOS cookie export or credential import is implemented.

Account-epoch and sign-in state invalidate visible Home state; stale account requests cannot publish across a sign-out, local-data cleanup or another account scope. Private requests participate in the session’s network cleanup accounting. Request cancellation and failures preserve the last successfully loaded same-scope shelves.

## Evidence and limitations

- Anonymous live probe on 2026-09-28: first-party Music browse returned HTTP 200 and 2 carousel shelf renderers; responseContext reported logged_in=0. This demonstrates a guest response only.
- Unit tests cover endpoint normalization and rejection of unconfirmed personalization. UI fixture tests cover presentation, not real account feed availability.
- macOS’s signed-in Web Home helper is macOS-only and depends on an independently authorized browser session. It cannot simply be launched on iOS. OAuth Music Home availability for the user’s actual account remains a physical-device gate. A web-session solution is required if this OAuth route is rejected; do not mark personalized Home complete based on guest shelves or fixtures.
- This is an undocumented Music endpoint, separate from the official Data API composition and quota accounting. Its inclusion is an experimental candidate change and requires an updated P6/distribution assessment before any App Store or TestFlight claim. No store upload, publication or distribution approval is implied by successful compilation.
- Playback remains the existing visible official player. This Home adaptation does not implement background audio, hidden playback or native stream extraction.
- Bundled privacy policy is updated to 2026-09-28.1 for Home requests and separate sign-out/revoke controls. Published policy/verification materials must be synchronized by the release owner before submission.
