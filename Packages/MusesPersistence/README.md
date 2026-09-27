# P2 persistence handoff

`MusesDomain`, `MusesQueue`, and `MusesPersistence` compile independently with SwiftPM. They are not yet linked into the iOS app. P4 owns `project.yml`, the Xcode project, and composition.

## Interfaces

- `MusesDomain`: validated provider and user IDs, `Track` / `CatalogItem` / `Video` / `PlaybackSource`, catalog and playback ports, rights and capability policy. A YouTube source carries a `VideoID`, never a stream URL.
- `MusesQueue`: `PlaybackQueue(snapshot:)` is a value reducer. `QueueEntry.id` is the occurrence identity, so a `TrackID` may appear more than once. Each structural transition increments `generation`; the coordinator must reject stale adapter events by generation and source. The serialized `QueueSnapshot` preserves current, upcoming, history, repeat, shuffle seed/order and position. `restored()` forces pause.
- `MusesPersistence`: `SwiftDataSnapshotRepository` stores versioned, typed JSON snapshots in `MusesSchemaV1.Record` rows. `saveTrack`, `track`, `saveQueue`, and `queue` are convenience APIs; `put/get/list/delete` cover other kinds. It accepts snapshots and IDs rather than transporting `@Model` objects. `importLegacy` validates before an idempotent transaction and sets a migration marker. It does not mutate the source store.

## P4 integration

1. Add the three local package products to the app target. Keep the inherited SwiftData model container open as a **read-only migration source** and create the V1 target at a **different** store URL. Never point `SwiftDataSnapshotRepository.container(url:)` at `muses-youtube-native.sqlite`.
2. On the old `ModelContext` actor, fetch old `Track`, `QueueState`, `TrackNote`, `TrackBookmark`, `Playlist`, `PlaylistItem`, `ListeningEvent`, `YouTubeImport`, and `YouTubeImportItem` rows; read relevant `UserDefaults` settings. Copy fields into `LegacyUserTruthBundle` values. Decode old `QueueState.itemsJSON` into `LegacyQueueEntry` values. Pass that bundle to `importLegacy`. Read the migration marker before presenting the new store as authoritative.
3. Keep old store files and their WAL/SHM together until fixture-backed upgrade tests, version rollback, and user data parity checks pass. If opening/decoding the old store fails, surface an actionable recovery state; do not create an empty replacement as though migration succeeded.
4. `PlaybackCapabilityPolicy.effective` requires source rights, channel evidence, adapter and runtime capabilities. Public YouTube composition must use a visible IFrame adapter; native audio flags are removed for YouTube. The coordinator owns queue transitions and filters stale events.

## Migration gaps to close before production switch

- The inherited schema is an unversioned autoschema with many relationships. This package **does not perform an in-place SwiftData migration** or open the inherited store. P4 must provide an app-side reader and real old-store fixture, then verify first install, upgrade, corrupt-store recovery, and rollback. Current tests exercise value fixtures and an in-memory V1 store only.
- `LegacyTrackSnapshot` copies the stable UUID, title, artist, video ID, duration and favorite flag. Album, artwork, lyrics, availability, catalog links, quality metadata, timestamps and play counts need additional DTO fields and mapping before retiring the old store.
- `LegacyQueueSnapshot` maps the main ordered `itemsJSON` and current index. It does not yet carry separate `upNextJSON`, `historyJSON`, advanced groups, locked/priority attributes, source context or an old shuffle seed (the inherited schema had no seed). Do not cut over the queue until those are preserved or explicitly reconciled.
- The bulk bundle covers notes, bookmarks, playlists, history, imports and settings via value records. P4 still needs to capture all source fields, including playlist/import relationships, revision/shadow sync metadata, and privacy-sensitive settings. Additional old models (`ListeningSession`, `InboxItem`, focus/automation data) need a scope decision and mapping. The generic V1 records preserve captured values but do not yet provide specialized query APIs for every feature.
- The repository throws on malformed or unknown payloads and leaves source data untouched. It has no automatic corrupt-store repair or user-facing recovery screen. Do not silently clear data.

Run `swift test --package-path Packages/MusesDomain`, `Packages/MusesQueue`, and `Packages/MusesPersistence`. This tests the package contracts on macOS; it does not establish iOS simulator or device behavior.
