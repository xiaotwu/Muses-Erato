# P2 persistence handoff

`MusesDomain`, `MusesQueue`, and `MusesPersistence` compile independently with SwiftPM. They are not yet linked into the iOS app. P4 owns `project.yml`, the Xcode project, and composition.

## Interfaces

- `MusesDomain`: validated provider and user IDs, `Track` / `CatalogItem` / `Video` / `PlaybackSource`, catalog and playback ports, rights and capability policy. A YouTube source carries a `VideoID`, never a stream URL.
- `MusesQueue`: `PlaybackQueue(snapshot:)` is a value reducer. `QueueEntry.id` is the occurrence identity, so a `TrackID` may appear more than once. Each structural transition increments `generation`; the coordinator must reject stale adapter events by generation and source. The serialized `QueueSnapshot` preserves current, upcoming, history, repeat, shuffle seed/order and position. `restored()` forces pause.
- `MusesPersistence`: `SwiftDataSnapshotRepository` stores versioned, typed JSON snapshots in `MusesSchemaV1.Record` rows. `saveTrack`, `track`, `saveQueue`, and `queue` are convenience APIs; `put/get/list/delete` cover other kinds. It accepts snapshots and IDs rather than transporting `@Model` objects. `importLegacy` validates before an idempotent transaction and sets a migration marker. It does not mutate the source store.

## P4 integration

1. Call `LegacyStoreSnapshotter.snapshot(sourceURL: oldURL, destinationURL: temporaryCopyURL)`. Its read-only SQLite backup includes committed WAL pages and validates the copy. Open **only the returned copy** with the inherited app's exact `MusesSchema.current` model graph. Never point `SwiftDataSnapshotRepository.container(url:)` at `muses-youtube-native.sqlite`.
2. Fetch all 19 old model types from the copied store, including empty tables. Map every Track scalar to `LegacyTrackArchive` and every QueueState scalar to `LegacyQueueArchive`. Build the existing `LegacyUserTruthBundle` projections. For each of the other 15 user-state model types, create `LegacyModelArchive(id:fields:fieldNames:)` with all keys in `LegacyModelKind.requiredFields`, explicit JSON nulls, and relationship IDs. Use `LegacyCompleteBundle.knownSettingKeys` to check UserDefaults; pass present values as `LegacySetting` and all checked keys as `inspectedSettingKeys`. Pass all fetched model names as `inspectedModels`.
3. Open a **new, empty** V1 store at a different URL and call `repo.importLegacyComplete(bundle)`. Verify `repo.get(LegacyMigrationReceipt.self, kind: .migration, id: "legacy-complete-v1")` and archive counts before making it authoritative. A repeat call with the same bundle is idempotent; changed input, existing target data and damaged records are errors. Keep the old store files and WAL/SHM together for rollback.
4. If snapshotting, old-model fetch, field mapping, validation or target opening fails, retain the old store and show the recovery state. The public app currently blocks on any old store; removing that gate belongs to the integration owner after a real old-schema fixture and rollback test pass.
4. `PlaybackCapabilityPolicy.effective` requires source rights, channel evidence, adapter and runtime capabilities. Public YouTube composition must use a visible IFrame adapter; native audio flags are removed for YouTube. The coordinator owns queue transitions and filters stale events.

## Migration gaps to close before production switch

- The inherited schema is an unversioned autoschema with many relationships. This package does not open it. The app-side reader and a physical old-schema SwiftData fixture have **not** been implemented; the migration release gate remains blocked. Package tests use a representative JSON fixture and SQLite WAL/corruption fixtures, not an inherited-store upgrade.
- Full Track and QueueState fields are archived. Public playback cannot use every archived field. Raw queue source context, advanced groups, locked/priority flags and history state are retained but not represented in `QueueSnapshot`; the inherited schema had no shuffle seed.
- The other 15 user-state models are stored as full JSON archives after the app reader supplies them. Only the existing small DTO projections have public query APIs. The public UI has no consumer for sessions, inbox, EQ, automation, focus or sync archives yet.
- `CatalogRelease` and `CatalogArtist` are excluded as rebuildable old Innertube caches. The official Data API cache belongs to the new catalog layer and must be fetched anew. Old settings are archived, not automatically applied. Cookie/consent settings require a separate product decision.
- The repository throws on malformed or unknown payloads and leaves source data untouched. It has no automatic corrupt-store repair or user-facing recovery screen. Do not silently clear data.

Run `swift test --package-path Packages/MusesDomain`, `Packages/MusesQueue`, and `Packages/MusesPersistence`. This tests the package contracts on macOS; it does not establish iOS simulator or device behavior.
