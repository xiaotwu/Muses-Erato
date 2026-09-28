# Library hero cards and local deletion — 2026-09-27

Branch: `codex/public-library-hero`. Started at requested integration `0b7346d`; fast-forwarded to `a78e14b` to include the owner's privacy/support components and the Notebook staging interface before finishing. The final feature commit is independent of those existing integration commits. The macOS source workspace was read-only.

## Reference and presentation

Read the actual local macOS implementations in `/Users/xiaotwu/Code/Muses`:

- `Sources/Muses/Features/Shared/AlbumObject.swift`, `AlbumObjectView` → `.heroCard`: full-bleed artwork, lower gradient scrim, 20-point corners, source tag and action pill.
- `Sources/Muses/Features/Shared/HeroObject.swift`: artwork, title, subtitle and metadata hierarchy; honors Reduce Motion.
- `Sources/Muses/Features/Playlist/PlaylistsView.swift`: playlist hero-card grid usage.

`PublicLibraryHeroViews.swift` adapts that structure for saved videos and local playlists. Library categories now occupy one horizontal scroll rail rather than a multi-row grid. Selected categories remain reachable by scrolling and accessible to VoiceOver; selection centering skips animation under Reduce Motion. Hero grids adapt to available width; accessibility text uses one column and expandable labels/action hit areas. At accessibility text sizes, iPad uses the single-column tab navigation so a large sidebar does not consume the reading width.

Artwork and Details are **presentation choices**, not music/audio playback modes. Artwork is a static thumbnail. Opening Play presents the existing visible official player. No IFrame is created under the cards, and no new control overlays the actual IFrame. The Songs category explicitly says these are saved YouTube videos whose song classification is unavailable. No song/album/artist relationships, codec, container, quality or resolution values are invented. Details show stored title/artist/duration when available and explain that YouTube controls playback encoding.

Common actions use icons with spoken labels and stable semantic identifiers. Confirmations, identity/title text, errors, privacy, permission and read-only scope explanations remain text. The existing top-level Queue / Clear Up Next entry, keyboard behavior, Settings player presentation, legal links, consent gate and Notebook views are retained.

## Deletion and clear semantics

- Saved video: confirmed removal of the saved track, its favorite marker, all displayed local history occurrences, current/upcoming/queue-history references, local playlist membership, notes and bookmarks. Deleting the current video dismisses and tears down its player and cancels obsolete bookmark cueing; no next video auto-plays.
- Favorite: confirmed removal of the local favorite only. The saved video, playlists, history and YouTube account remain.
- History item: confirmed removal of this video's local listening-history occurrences (the current History UI groups by video). Saved video and queue history remain separate.
- Local playlist: confirmed deletion of its collection only. Its saved videos remain. The playlist detail also provides a confirmed clear-membership action.
- Library Videos/Songs, Favorites, Playlists and History each have a confirmed, scoped icon clear action, disabled while empty. Unsupported/derived categories have no fabricated deletion action.
- Search clear resets input and displayed results, without deleting saved videos. Catalog lists can clear their loaded display. Account clear resets locally loaded YouTube lists/cache; it never unsubscribes, deletes cloud playlists, or performs a YouTube write.

`LocalLibraryDeletion.swift` validates and prepares the public graph, calls `stageVideoNotebookDeletion(trackID:)`, and saves all affected rows in **one** context save. Errors roll the context back. Only after success does the session publish the new graph and call `notebook.forget`. Save failure leaves the player, references and visible data intact and displays an error. Favorites batch removal also commits one save. Legacy source SQLite, `.legacyTrack` / `.legacyModel` archives and migration receipts are never deleted.

Integration boundary: old archive/projection types other than the live public track/local-playlist/queue/history/favorite graph and live Notebook projections remain owner-managed. Before exposing additional migrated objects, the owner must extend deletion for their relationships; this task does not wipe the archive to hide those dependencies.

## Validation

- Persistence package: **26 tests passed**. Added graph cleanup, immutable archive preservation, notes/bookmarks cascading deletion, rollback after staged mutations/save failure, and scoped history/favorite removal.
- Hosted app: **18 tests passed**. Added current-video deletion and relaunch, rejected deletion without false success/player dismissal, batch clear scopes/restart, and clearing catalog state without deleting local collections.
- Dedicated iPhone 17e / iOS 26.5 (`F7C4C82C-6BF7-4D3A-B010-91914456EE3B`): **4 UI flows passed** — horizontal category reachability/empty disabled state; hero→visible player→confirmed single deletion→relaunch; cancel/confirm bulk clear; accessibility XXXL text and hero controls.
- Dedicated iPad mini / iOS 26.5 (`438BB4B7-165B-4AF8-BD70-2F523044A805`): **2 UI flows passed** — horizontal categories and accessibility XXXL hero/navigation. Final screenshots were inspected. No shared owner simulator was used for this feature.
- Release simulator build and `scripts/audit-public-artifact.py` passed.

Earlier UI runs revealed inherited accessibility identifiers on card children, modern popover confirmations without an explicit Cancel row, and a partially clipped rail item being tapped by automation. Child identifiers were fixed; automation now dismisses popovers appropriately and taps only fully visible rail items. One failed-run Xcode teardown hung after tests had reported completion; only this task's runner was stopped, and the corrected runs completed successfully.

Logs: `/tmp/erato-hero-persistence.log`, `/tmp/erato-hero-last.log`, `/tmp/erato-hero-final-ui.log`, `/tmp/erato-hero-ipad-final.log`, `/tmp/erato-hero-release.log`, `/tmp/erato-hero-audit.log`.

UI result bundles:

- `/tmp/erato-hero-build/Logs/Test/Test-Muses-2026.09.27_17-04-05--0700.xcresult`
- `/tmp/erato-hero-ipad/Logs/Test/Test-Muses-2026.09.27_17-05-31--0700.xcresult`

Exported screenshots: `/tmp/erato-hero-phone-screens/` and `/tmp/erato-hero-ipad-final-screens/`. Reduce Motion is respected directly through the environment flag; a physical-device accessibility-settings/VoiceOver pass remains outstanding. No new live playback, authentication or Cloud restriction acceptance is claimed.

`project.yml` explicitly allowlists `PublicLibraryHeroViews.swift`. The generated Xcode project was used for local verification but is intentionally excluded from this feature commit: the integration owner requested a combined regeneration after merging parallel features.

## Pending metadata-policy integration from owner

The owner is moving provider metadata to memory-only display because a suspended app cannot guarantee timely disk deletion. Preserve the new Library `library.refresh` icon and its first-eligible-entry refresh task; they call the existing batched `refreshSavedMetadata()` method, never Search. The task is guarded by view-owned state and does not run on every redraw. Favorites and deletion now preserve survivors' in-memory titles instead of replacing them with repository placeholders.

When merging the owner's forthcoming `Track.localPersistenceSnapshot`, sanitize the two direct Track-encoding callsites in `LocalLibraryDeletion.swift`: `clearLocalFavorites()`'s payload map and `removeLocalFavorite()`'s encoded update. Saved-video deletion itself writes only playlist/queue snapshots and deletes Track rows. A hosted regression test simulates disk placeholders and verifies single favorite removal, favorites clearing and deletion of another video preserve the fresh display title. No unknown legacy archive is destroyed to resolve metadata provenance uncertainty.
