# ADR 0002: P2 value contracts and additive user store

Status: accepted for P2 package interface, 2026-09-27.

The inherited app stores SwiftData `@Model` references in its service graph and has an unversioned autoschema. P2 needs a shared boundary that can compile without app UI or media engines while preserving an upgrade path.

We use validated typed IDs and immutable source/capability values in `MusesDomain`. `MusesQueue` is a synchronous value reducer with occurrence IDs and a persisted generation. `MusesPersistence` stores versioned snapshot payloads in a new SwiftData schema at a separate URL; a transaction imports plain values captured from the old store. The old database is retained during cutover. This avoids asking SwiftData to infer a migration between unrelated model graphs and allows rollback.

The alternative was to copy all inherited `@Model` types into the shared package and migrate in place. That would transfer obsolete media assumptions and relationship cycles into the new contract, while making old-store failure harder to recover. A generic JSON row store trades efficient field queries for safe initial extraction; specialized indexed models can be introduced in later schema versions after P4 maps all fields and measures query needs.

The public YouTube source carries only a validated video ID. The capability policy requires a visible video adapter and excludes native audio, offline and system remote features for this source. Future local or licensed sources require explicit rights and distribution evidence.

P2's package tests prove value serialization, queue invariants, V1 disk reopen, import validation, and corrupt payload error behavior. They do **not** prove a real inherited database upgrade or iOS app integration. P4 must create a read-only old-store reader, a full-field fixture, and a user-visible recovery path before making V1 authoritative. Field gaps are listed in `Packages/MusesPersistence/README.md`.
