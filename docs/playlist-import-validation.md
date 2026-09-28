# Device-local YouTube / YouTube Music playlist import

Library → Playlists → Import icon opens account-owned playlists first, with a playlist share-link fallback. Sign-in is available in that sheet. Account list pagination is explicit. Selecting a playlist reads its metadata and first page (at most 50 entries); the primary next action reads all remaining pages, bounded to 100 total pages (5,000 entries), with a single-page fallback and cancellation. Import remains unavailable until the final page succeeds. A user-authored local name is required and never prefilled with an API title.

The repository stages new placeholder tracks and the complete local playlist in one SwiftData save with rollback on error. Existing saved tracks are reused. `occurrences` preserves playlist order and repeated videos for queue playback; the existing playlist editor uses a unique-video projection. No remote mutations occur. Existing Library playlist delete and clear actions remove local playlists. No partial playlist is written on API failure, malformed item, duplicate entry resource, repeated page cursor, cancellation, or invalid local name. Private/deleted IDs returned by the API retain their membership but playback is not guaranteed.

API metadata remains in memory. After the successful transaction, imported titles update session tracks immediately while preserving existing user-authored fields. New persisted tracks contain IDs, placeholder text and user-selected membership only. Unsupported/missing metadata and omitted playlist item resource IDs fail the import instead of reporting an empty or truncated success. This is a paginated live read; the API does not provide a transactional snapshot against concurrent remote edits.

## Official scope

- [playlists.list](https://developers.google.com/youtube/v3/docs/playlists/list): `mine=true` means playlists owned by the authenticated account. It does not promise all YouTube Music saved, recommended or third-party playlists.
- [playlistItems.list](https://developers.google.com/youtube/v3/docs/playlistItems/list): maximum 50 per page, explicit nextPageToken, forbidden/not-found/unsupported playlist errors. Only official API-readable playlist IDs are supported; no Innertube, scraping, or stream extraction fallback.

## Integration

Add `Sources/Muses/Features/Public/PublicPlaylistImportView.swift` to the Muses source allowlist and `Tests/MusesTests/PublicPlaylistImportTests.swift` to the MusesTests allowlist in project.yml and regenerate the project. This branch does not commit shared project files. Package source/tests are auto-discovered. New UI test: `Tests/MusesPublicUITests/PublicPlaylistImportUITests.swift` (existing folder allowlist).

## Validation

- Catalog package: 19 tests passed, including owned-account OAuth/mine/cursor, Music share link and host rejection, repeated videos, incomplete cursor rejection and malformed API playlist item rejection. `/tmp/erato-import-catalog.log`.
- Persistence package: 28 tests passed, including atomic import, retained repeated order, existing-track reuse, invalid-name no-write and placeholder metadata. `/tmp/erato-import-persistence.log`.
- iOS simulator build passed with the temporary source allowlist. `/tmp/erato-import-build.log`.
- Real OAuth consent, account visibility, private/unsupported YTM playlists and physical-device playback remain release gates. Fixtures and simulator results are not live-account or real-device validation.
- iPad mini (A17 Pro), iOS 26.5 simulator `438BB4B7-165B-4AF8-BD70-2F523044A805`: hosted metadata/payload test and UI account-select → link → all remaining pages → user name → import → restart passed. `/tmp/erato-import-final.log`; result `/tmp/erato-import/Logs/Test/Test-Muses-2026.09.27_17-35-48--0700.xcresult`.
- Initial UI run exposed a 19 × 21.5pt import icon accessibility frame; fixed with an internal 44 × 44pt image label and verified dimensions/label. Test assumptions were corrected for fixture signed-in state and grouped playlist navigation accessibility labels. Earlier failure logs: `/tmp/erato-import-ui.log`, `/tmp/erato-import-ui-final.log`; subsequent full run passed.
- Requested broader iPad hero/privacy/notebook audit was deferred when playlist import became the priority. No physical-device validation or live OAuth account import was performed by this branch.
- Final Release simulator build and static public-artifact audit passed (`/tmp/erato-import-release.log`, `/tmp/erato-import-audit.log`).
