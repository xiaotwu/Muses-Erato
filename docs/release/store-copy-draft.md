# Muses-Erato App Store material — draft

Updated against integrated code eb36a02 on 2026-09-27. Notes/bookmarks, catalog browsing and account-playlist imports are integrated. The latest UI functions have owner-confirmed physical-device acceptance; this is still a draft pending P6 privacy, authorization and release evidence. No upload has occurred.

## Proposed listing

**Name:** Muses Erato

**Subtitle:** Video library & listening notes

**Description:**

Keep the YouTube videos you return to in one organized space. Muses Erato combines a local video library with official YouTube search and a visible YouTube player.

- Save favorites and organize local playlists.
- Import supported playlists from your Google account or a YouTube Music playlist link.
- Browse the combined songs from your playlists as cards or a compact list.
- Arrange upcoming videos and clear the queue while keeping the current video.
- Search videos, playlists and channels. Load further catalog results as needed; playlist imports automatically read remaining pages within the displayed import limit.
- Add private notes and time bookmarks to saved videos.
- Sign in with Google to view supported read-only YouTube account information.

Local favorites, playlists and notes stay separate from your YouTube account. Playback uses YouTube's official visible player and pauses when the player closes or the app enters the background. Video availability and advertisements are controlled by YouTube. The app does not provide downloads, background audio or audio processing.

Muses Erato is an independent app and is not endorsed by Google or YouTube.

**Keywords proposal:** video,playlist,bookmark,notes,library,queue

## Review notes

The app uses the official YouTube IFrame Player API for visible playback and YouTube Data API v3 for catalog/account reads. It does not resolve or download media URLs. Google sign-in requests only the read-only YouTube scope. User-created local playlists/favorites/notes do not write to YouTube.

Guest review: open Home, enter the official IFrame sample video ID `M7lc1UVf-VE`, open the visible player, then use the player's controls. Guest online search requires the configured project API key; verify the final archive's configuration before submission. Closing the player or moving the app into the background stops playback.

Account review: Settings → Sign in with Google. Complete Google consent using an approved review account. Browse supported account playlists/subscriptions. Library → Playlists → Import: the account chooser automatically loads owned playlist pages. Select a playlist; import reads its remaining item pages and defaults to its source title. Save the local copy, swipe its song strip and open the visible player. Songs shows the union of local playlist membership with Cards / List controls. Owned playlists returned by the official endpoint are supported; a complete YouTube Music library sync is not promised. Sign out and revoke access; local credentials/private caches are removed, and failures of network revocation are explained. The owner must provide a reviewer-access strategy that works with the production OAuth consent state; no developer secrets belong in these notes.

Queue review: save two videos, add them to the queue, use Next, then Library → Queue menu → Clear Up Next. Only upcoming items are removed; current playback continues. Cancel a clear confirmation first, then repeat and confirm. Per-playlist clear affects its local membership; clearing Songs removes saved items in the playlist union, so use temporary review content. Local deletion does not delete the user's YouTube account.

## Required owner/platform fields

The owner selected GitHub for public support. Issues are enabled; Discussions are currently disabled. Use `https://github.com/xiaotwu/Muses-Erato/issues` as the support URL. The prepared repository privacy page still requires publication and a verified public URL. Google/Apple developer contact fields are separate from this public support choice.

- App Store Connect app record, SKU, pricing, countries, category and current age-rating questionnaire.
- Public support contact, support URL and privacy-policy URL, copyright identity.
- Production Google consent/verification status and reviewer access; API restrictions and quota evidence.
- Actual final-build screenshots per required device family, locale and size. No synthetic screenshots representing unfinished features.
- Signing/export compliance, version/build number, beta feedback contact and TestFlight audience.
- TestFlight review status and App Review submission/status. A signed archive alone is insufficient.
