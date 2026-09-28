# ADR 0005: Keep new API display metadata out of durable library snapshots

Date: 2026-09-27. Applies to the public iOS library, not an approval of legacy retention.

## Decision

Explicit `.youtubeDataAPI` Track metadata is displayed in memory. Before writing a `.track`
record, persistence uses `localPersistenceSnapshot` to replace API-derived title/artist/
duration/fetchedAt with a placeholder while preserving the user's selected video identity,
favorite flag and library relationships. `.user` edits remain durable. Generic `put`
enforces the boundary as well as `saveTrack`; transaction-specific direct encoders must use
the same snapshot. Catalog/OAuth transport is ephemeral, with no response disk cache.
The app configures shared Foundation artwork caching with zero disk capacity.

An inactive iOS process cannot promise to execute a 29-day timer. Therefore the public app
must not depend on that timer to remove newly persisted API display metadata. Library titles
can be refreshed in batches of up to 50 selected IDs; a placeholder remains if a request is
unavailable. Fresh API results remain unchanged for their live presentation. Existing expiry
guards still apply to memory and older records.

## Evidence and remaining gate

The SQLite test inspects actual record payloads and reopens the store: a fresh API-only
title/channel never enters the durable Track payload, selection/favorite remain, and a
user-authored label survives. The persistence suite passed 24 tests after this change.

This does not settle provenance or retention of original stores, immutable migration archives,
old device backups, authorization-derived selections or WebKit-owned data. Those need the
P6 inventory/permission decision and deletion evidence. Never describe this change as a
complete Google compliance determination. Source:
[YouTube Developer Policies, III.E.4](https://developers.google.com/youtube/terms/developer-policies).
