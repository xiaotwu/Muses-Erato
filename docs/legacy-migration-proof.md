# Physical legacy migration proof

The isolated `MusesLegacyProof` package and `migration-proof.yml` compile the original 19 SwiftData models and `MusesSchema.current` directly from `Sources/Muses`, in their historical `Muses` module. No replacement `@Model` declarations or SQLite table emulation are used. All original model-bearing files and the schema are byte-identical to integration base `dd6fabb`. Three nonpersistent dependencies were relocated without changing their bodies: pagination values, `RecapRange`, and the playback-context extension of `TrackSnapshot`. This prevents the migration target from pulling in the legacy network/playback service graph.

`Tests/LegacyMigrationTests/Fixtures` contains an actual committed physical fixture, its WAL and SHM, an independently generated row manifest, explicit settings, and SHA-256 provenance. It was written with the inherited schema on macOS using Swift 6.4. Tests copy the fixture before opening it. Both macOS and iOS also generate fresh physical fixtures at runtime. The committed fixture is synthetic user data written by the original models, **not evidence from a previously shipped app executable or a production user's database**.

The writer inserts every model type, two occurrences of the same track in both a manual playlist and an import, populated optional scalars, notes/bookmarks, favorites, events/sessions, inbox, focus, automation, EQ, revisions and sync intent. Queue data is encoded using the original `QueueItem`, `TrackSnapshot`, and `QueueGroup` value types, with nonempty current/up-next/history/groups, lock/priority/context/history metadata. Settings cover string, integer, floating point, Boolean, Date, Data, array and dictionary. The manifest records input values before the reader runs. To-many relationship IDs are sorted because SwiftData does not promise array ordering; `order` remains a separate preserved scalar.

A SQLite connection pins the empty pre-write transaction. The writer commits SwiftData changes while that pin is held, and tests confirm the pinned main snapshot has zero tracks and the WAL contains pages. Thus a copy of only the main file cannot satisfy the manifest. The reader uses the SQLite backup API, opens only the backup with `allowsSave: false`, disables autosave, fetches all 19 types, validates the Track inverse, and decodes the original queue value types. Every declared scalar and relationship is compared against the manifest, including queue JSON strings. Null fields, malformed queue groups, occupied targets, corrupt targets, existing snapshots and real read-only save failures are covered.

`LegacyMigrationPreparation.prepare` implements a controlled preparation phase in a fresh attempt directory. It creates a snapshot, imports into a separate empty V1 database, reopens V1, compares every imported record through the receipt/retry validator, and atomically writes `prepared.json` last. Failure leaves diagnostic files and the original library intact. The marker is evidence only; it does not change the public startup route. Repeated attempts must use fresh directories. This avoids installing a partially verified target or overwriting public edits. No legacy defaults are applied.

The receipt now encodes archive field-name sets in sorted order, making a fresh capture stable across process hash seeds. Snapshot destination creation now uses `O_EXCL`; the SQLite `SQLITE_OPEN_EXCLUSIVE` flag alone does not provide that guarantee. Orphan destination WAL/SHM files also block snapshot creation.

Run the proof on macOS:

```sh
swift test
swift test --package-path Packages/MusesPersistence
```

Run the same suite on an available iOS simulator (choose its UDID from `xcrun simctl list devices available`):

```sh
mkdir -p .artifacts/migration-proof
xcodegen generate --spec migration-proof.yml --project .artifacts/migration-proof
xcodebuild test \
  -project .artifacts/migration-proof/MusesLegacyMigrationProof.xcodeproj \
  -scheme MusesLegacyMigrationProof \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' \
  -derivedDataPath .artifacts/migration-derived CODE_SIGNING_ALLOWED=NO
```

To export a new real fixture for inspection, set `MUSES_LEGACY_PROOF_OUTPUT` to an empty/nonexistent directory when running the macOS suite. Export does not replace the committed fixture automatically. Temporary test directories are left to OS cleanup because Core Data can close SQLite handles asynchronously; deleting them immediately can unlink a still-open database. The save-failure test intentionally logs Cocoa error 513 for a read-only V1 target. Settings use the `.plist.bin` suffix so Xcode copies their bytes without recompiling the property list. The macOS 27 fixture also produces a Core Data framework-version diagnostic on iOS 26.5 (Persistence-1629 to Persistence-1526); read-only capture and field comparisons still complete. This does not establish arbitrary OS downgrade compatibility.

Release remains blocked. The following evidence/work is still required before changing `PublicYouTubeApp`:

- Run downgrade/rollback using the actual previous app executable, including a writable reopen and continued editing. Current tests reopen the original schema read-only after failure and success and compare original main/WAL bytes. They do not claim execution of the old app binary.
- Exercise process termination during import and marker publication, disk-full conditions and restart recovery. The suite proves real save rejection, durable empty-target retry, complete-receipt retry and corrupt/occupied-target rejection; it does not simulate every crash window.
- Resolve public history consumption: migrated `.history` payloads are `LegacyHistoryEvent` (`startedAt`), while `PublicYouTubeSession` currently decodes `PlayedVideo` (`date`). Removing the recovery gate today would fail library loading for this fixture.
- Integrate the audited migration source allowlist into a signed public build, define durable route activation and post-migration edit behavior, run the public artifact audit, and test the deployment floor and a device. Current iOS evidence is an unsigned simulator test framework on iOS 26.5, not a signed App Store build or iOS 18 device.

There is no demonstrated need for an unsafe helper binary: the isolated reader compiles without the prohibited legacy playback/network implementations. If distribution constraints later prevent including this allowlist, retain this exact preparation protocol in a controlled transition release; do not substitute simplified model definitions or delete the original store. A prepared directory alone must never bypass the recovery gate.

Validated on 2026-09-27: 5 physical proof tests on macOS, the same 5 tests on the iPhone 17e / iOS 26.5 simulator, and 16 MusesPersistence package tests all passed. Public startup source and its recovery gate were not changed.
