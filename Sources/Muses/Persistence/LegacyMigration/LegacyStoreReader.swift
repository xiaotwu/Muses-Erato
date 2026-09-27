import Foundation
import SwiftData
import MusesPersistence

/// Only entry point accepts a source to back up, never opens that source with SwiftData.
/// No registered defaults, network services, or legacy playback code are executed.
@MainActor
enum LegacyStoreReader {
    struct Capture {
        let bundle: LegacyCompleteBundle
        /// Includes cache rows and Track inverse edges for physical fixture verification.
        let manifest: [String: [LegacyModelArchive]]
    }

    static func read(sourceURL: URL, snapshotURL: URL,
                     defaults: UserDefaults, domainName: String) throws -> Capture {
        let copy = try LegacyStoreSnapshotter.snapshot(sourceURL: sourceURL, destinationURL: snapshotURL)
        let config = ModelConfiguration(schema: MusesSchema.current, url: copy,
                                        allowsSave: false, cloudKitDatabase: .none)
        let container = try ModelContainer(for: MusesSchema.current, configurations: [config])
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let settings = try LegacySettingsSnapshot.read(defaults: defaults, domainName: domainName)
        var manifest: [String: [LegacyModelArchive]] = [:]
        let rowsYouTubePlaylistRevision = try context.fetch(FetchDescriptor<YouTubePlaylistRevision>())
        manifest["YouTubePlaylistRevision"] = try rowsYouTubePlaylistRevision.map(archive).sorted { $0.id.uuidString < $1.id.uuidString }
        let rowsYouTubeSyncBatch = try context.fetch(FetchDescriptor<YouTubeSyncBatch>())
        manifest["YouTubeSyncBatch"] = try rowsYouTubeSyncBatch.map(archive).sorted { $0.id.uuidString < $1.id.uuidString }
        let rowsYouTubeSyncOperation = try context.fetch(FetchDescriptor<YouTubeSyncOperation>())
        manifest["YouTubeSyncOperation"] = try rowsYouTubeSyncOperation.map(archive).sorted { $0.id.uuidString < $1.id.uuidString }
        let rowsCatalogRelease = try context.fetch(FetchDescriptor<CatalogRelease>())
        manifest["CatalogRelease"] = try rowsCatalogRelease.map(archive).sorted { $0.id.uuidString < $1.id.uuidString }
        let rowsCatalogArtist = try context.fetch(FetchDescriptor<CatalogArtist>())
        manifest["CatalogArtist"] = try rowsCatalogArtist.map(archive).sorted { $0.id.uuidString < $1.id.uuidString }
        let rowsFocusSession = try context.fetch(FetchDescriptor<FocusSession>())
        manifest["FocusSession"] = try rowsFocusSession.map(archive).sorted { $0.id.uuidString < $1.id.uuidString }
        let rowsTrack = try context.fetch(FetchDescriptor<Track>())
        manifest["Track"] = try rowsTrack.map(archive).sorted { $0.id.uuidString < $1.id.uuidString }
        let rowsYouTubeImport = try context.fetch(FetchDescriptor<YouTubeImport>())
        manifest["YouTubeImport"] = try rowsYouTubeImport.map(archive).sorted { $0.id.uuidString < $1.id.uuidString }
        let rowsYouTubeImportItem = try context.fetch(FetchDescriptor<YouTubeImportItem>())
        manifest["YouTubeImportItem"] = try rowsYouTubeImportItem.map(archive).sorted { $0.id.uuidString < $1.id.uuidString }
        let rowsPlaylistItem = try context.fetch(FetchDescriptor<PlaylistItem>())
        manifest["PlaylistItem"] = try rowsPlaylistItem.map(archive).sorted { $0.id.uuidString < $1.id.uuidString }
        let rowsTrackNote = try context.fetch(FetchDescriptor<TrackNote>())
        manifest["TrackNote"] = try rowsTrackNote.map(archive).sorted { $0.id.uuidString < $1.id.uuidString }
        let rowsTrackBookmark = try context.fetch(FetchDescriptor<TrackBookmark>())
        manifest["TrackBookmark"] = try rowsTrackBookmark.map(archive).sorted { $0.id.uuidString < $1.id.uuidString }
        let rowsListeningEvent = try context.fetch(FetchDescriptor<ListeningEvent>())
        manifest["ListeningEvent"] = try rowsListeningEvent.map(archive).sorted { $0.id.uuidString < $1.id.uuidString }
        let rowsQueueState = try context.fetch(FetchDescriptor<QueueState>())
        manifest["QueueState"] = try rowsQueueState.map(archive).sorted { $0.id.uuidString < $1.id.uuidString }
        let rowsEQPreset = try context.fetch(FetchDescriptor<EQPreset>())
        manifest["EQPreset"] = try rowsEQPreset.map(archive).sorted { $0.id.uuidString < $1.id.uuidString }
        let rowsPlaylist = try context.fetch(FetchDescriptor<Playlist>())
        manifest["Playlist"] = try rowsPlaylist.map(archive).sorted { $0.id.uuidString < $1.id.uuidString }
        let rowsListeningSession = try context.fetch(FetchDescriptor<ListeningSession>())
        manifest["ListeningSession"] = try rowsListeningSession.map(archive).sorted { $0.id.uuidString < $1.id.uuidString }
        let rowsInboxItem = try context.fetch(FetchDescriptor<InboxItem>())
        manifest["InboxItem"] = try rowsInboxItem.map(archive).sorted { $0.id.uuidString < $1.id.uuidString }
        let rowsAutomationRule = try context.fetch(FetchDescriptor<AutomationRule>())
        manifest["AutomationRule"] = try rowsAutomationRule.map(archive).sorted { $0.id.uuidString < $1.id.uuidString }
        guard rowsQueueState.count <= 1 else {
            throw PersistenceError.unsupportedLegacyRecord("multiple queue states")
        }
        // Check both inverse directions before discarding the redundant Track edge.
        for track in rowsTrack {
            let expected = Set(rowsYouTubeImportItem.filter { $0.track?.id == track.id }.map(\.id))
            guard Set((track.youTubeImportItems ?? []).map(\.id)) == expected else {
                throw PersistenceError.unsupportedLegacyRecord("Track inverse relationship")
            }
        }
        var truth = LegacyUserTruthBundle()
        truth.tracks = rowsTrack.map { .init(id: $0.id, title: $0.title, artist: $0.artist,
            youTubeId: $0.youTubeId, durationMs: $0.durationMs, liked: $0.liked) }
        truth.notes = rowsTrackNote.map { .init(id: $0.id, trackId: $0.trackId, content: $0.content, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        truth.bookmarks = rowsTrackBookmark.map { .init(id: $0.id, trackId: $0.trackId, timestampMs: $0.timestampMs, title: $0.title, note: $0.note) }
        truth.playlists = rowsPlaylist.map { .init(id: $0.id, name: $0.name, createdAt: $0.createdAt, pinned: $0.pinned) }
        truth.playlistItems = try rowsPlaylistItem.map {
            guard let parent = $0.playlist else { throw PersistenceError.unsupportedLegacyRecord("orphan PlaylistItem") }
            return .init(id: $0.id, playlistID: parent.id, trackID: $0.track?.id, order: $0.order)
        }
        truth.history = rowsListeningEvent.map { .init(id: $0.id, trackID: $0.trackId, title: $0.trackTitle, artist: $0.artist, startedAt: $0.startedAt, listenedMs: $0.listenedMs, outcomeRaw: $0.outcomeRaw) }
        truth.imports = rowsYouTubeImport.map { .init(id: $0.id, playlistID: $0.playlistId, originalURL: $0.url, title: $0.title, importedAt: $0.importedAt) }
        truth.importItems = try rowsYouTubeImportItem.map {
            guard let parent = $0.import_ else { throw PersistenceError.unsupportedLegacyRecord("orphan YouTubeImportItem") }
            return .init(id: $0.id, importID: parent.id, videoID: $0.youTubeId, playlistItemID: $0.playlistItemID, order: $0.order)
        }
        truth.settings = settings.values
        let tracks = try manifest["Track", default: []].map { try JSONDecoder().decode(LegacyTrackArchive.self, from: $0.fields) }
        let queue = try manifest["QueueState"]?.first.map { try JSONDecoder().decode(LegacyQueueArchive.self, from: $0.fields) }
        try queue?.validate()
        if let queue {
            for json in [queue.itemsJSON, queue.upNextJSON, queue.historyJSON] {
                _ = try JSONDecoder().decode([QueueItem].self, from: Data(json.utf8))
            }
            if let groups = queue.groupsJSON {
                _ = try JSONDecoder().decode([QueueGroup].self, from: Data(groups.utf8))
            }
        }
        let other: [LegacyModelKind: [LegacyModelArchive]] = [
            .playlistRevision: manifest["YouTubePlaylistRevision", default: []],
            .syncBatch: manifest["YouTubeSyncBatch", default: []],
            .syncOperation: manifest["YouTubeSyncOperation", default: []],
            .focusSession: manifest["FocusSession", default: []],
            .youTubeImport: manifest["YouTubeImport", default: []],
            .youTubeImportItem: manifest["YouTubeImportItem", default: []],
            .playlistItem: manifest["PlaylistItem", default: []],
            .trackNote: manifest["TrackNote", default: []],
            .trackBookmark: manifest["TrackBookmark", default: []],
            .listeningEvent: manifest["ListeningEvent", default: []],
            .eqPreset: manifest["EQPreset", default: []],
            .playlist: manifest["Playlist", default: []],
            .listeningSession: manifest["ListeningSession", default: []],
            .inboxItem: manifest["InboxItem", default: []],
            .automationRule: manifest["AutomationRule", default: []],
        ]
        return Capture(bundle: LegacyCompleteBundle(userTruth: truth, tracks: tracks, queue: queue,
            otherModels: other, inspectedModels: Set(manifest.keys), inspectedSettingKeys: settings.inspectedKeys),
            manifest: manifest)
    }

    private static func value<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value), options: [.fragmentsAllowed])
    }
    private static func row(_ id: UUID, _ fields: [String: Any]) throws -> LegacyModelArchive {
        .init(id: id, fields: try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]),
              fieldNames: Set(fields.keys))
    }

    private static func archive(_ m: YouTubePlaylistRevision) throws -> LegacyModelArchive {
        try row(m.id, [
            "id": value(m.id),
            "importID": value(m.importID),
            "accountChannelID": value(m.accountChannelID),
            "kindRaw": value(m.kindRaw),
            "createdAt": value(m.createdAt),
            "snapshotData": value(m.snapshotData),
            "fingerprint": value(m.fingerprint),
            "pinned": value(m.pinned),
        ])
    }

    private static func archive(_ m: YouTubeSyncBatch) throws -> LegacyModelArchive {
        try row(m.id, [
            "id": value(m.id),
            "importID": value(m.importID),
            "accountChannelID": value(m.accountChannelID),
            "playlistID": value(m.playlistID),
            "stateRaw": value(m.stateRaw),
            "baseRevisionID": value(m.baseRevisionID),
            "localRevisionID": value(m.localRevisionID),
            "remoteRevisionID": value(m.remoteRevisionID),
            "expectedRemoteFingerprint": value(m.expectedRemoteFingerprint),
            "desiredSnapshotData": value(m.desiredSnapshotData),
            "preRemoteSnapshotData": value(m.preRemoteSnapshotData),
            "createdAt": value(m.createdAt),
            "startedAt": value(m.startedAt),
            "remoteObservedAt": value(m.remoteObservedAt),
            "completedAt": value(m.completedAt),
            "invalidatedReason": value(m.invalidatedReason),
        ])
    }

    private static func archive(_ m: YouTubeSyncOperation) throws -> LegacyModelArchive {
        try row(m.id, [
            "id": value(m.id),
            "idempotencyKey": value(m.idempotencyKey),
            "importID": value(m.importID),
            "accountChannelID": value(m.accountChannelID),
            "batchID": value(m.batchID),
            "sequence": value(m.sequence),
            "kindRaw": value(m.kindRaw),
            "stateRaw": value(m.stateRaw),
            "playlistItemID": value(m.playlistItemID),
            "videoID": value(m.videoID),
            "fromPosition": value(m.fromPosition),
            "toPosition": value(m.toPosition),
            "previousPlaylistItemID": value(m.previousPlaylistItemID),
            "nextPlaylistItemID": value(m.nextPlaylistItemID),
            "remoteResultID": value(m.remoteResultID),
            "attempts": value(m.attempts),
            "lastError": value(m.lastError),
            "createdAt": value(m.createdAt),
            "startedAt": value(m.startedAt),
            "remoteObservedAt": value(m.remoteObservedAt),
            "completedAt": value(m.completedAt),
        ])
    }

    private static func archive(_ m: CatalogRelease) throws -> LegacyModelArchive {
        try row(m.id, [
            "id": value(m.id),
            "stableID": value(m.stableID),
            "title": value(m.title),
            "artistName": value(m.artistName),
            "artistStableID": value(m.artistStableID),
            "artworkURL": value(m.artworkURL),
            "year": value(m.year),
            "kindRaw": value(m.kindRaw),
            "refreshedAt": value(m.refreshedAt),
            "unavailable": value(m.unavailable),
        ])
    }

    private static func archive(_ m: CatalogArtist) throws -> LegacyModelArchive {
        try row(m.id, [
            "id": value(m.id),
            "stableID": value(m.stableID),
            "name": value(m.name),
            "channelID": value(m.channelID),
            "browseID": value(m.browseID),
            "artworkURL": value(m.artworkURL),
            "biography": value(m.biography),
            "refreshedAt": value(m.refreshedAt),
            "unavailable": value(m.unavailable),
        ])
    }

    private static func archive(_ m: FocusSession) throws -> LegacyModelArchive {
        try row(m.id, [
            "id": value(m.id),
            "startedAt": value(m.startedAt),
            "plannedDurationMs": value(m.plannedDurationMs),
            "endedAt": value(m.endedAt),
            "playlistId": value(m.playlistId),
            "listeningSessionId": value(m.listeningSessionId),
            "statusRaw": value(m.statusRaw),
        ])
    }

    private static func archive(_ m: Track) throws -> LegacyModelArchive {
        try row(m.id, [
            "id": value(m.id),
            "title": value(m.title),
            "artist": value(m.artist),
            "albumTitle": value(m.albumTitle),
            "albumArtist": value(m.albumArtist),
            "durationMs": value(m.durationMs),
            "trackNo": value(m.trackNo),
            "discNo": value(m.discNo),
            "year": value(m.year),
            "genre": value(m.genre),
            "youTubeId": value(m.youTubeId),
            "mediaKindRaw": value(m.mediaKindRaw),
            "releaseCatalogID": value(m.releaseCatalogID),
            "releaseOrder": value(m.releaseOrder),
            "artistCatalogID": value(m.artistCatalogID),
            "artworkUrl": value(m.artworkUrl),
            "lyrics": value(m.lyrics),
            "lyricsOffsetMs": value(m.lyricsOffsetMs),
            "replayGain": value(m.replayGain),
            "sampleRate": value(m.sampleRate),
            "bitDepth": value(m.bitDepth),
            "codec": value(m.codec),
            "bitRate": value(m.bitRate),
            "channels": value(m.channels),
            "isLossless": value(m.isLossless),
            "metadataStatusRaw": value(m.metadataStatusRaw),
            "availabilityRaw": value(m.availabilityRaw),
            "addedAt": value(m.addedAt),
            "lastPlayedAt": value(m.lastPlayedAt),
            "playCount": value(m.playCount),
            "liked": value(m.liked),
            "youTubeImportItems": value(m.youTubeImportItems.map { $0.map(\.id).sorted { $0.uuidString < $1.uuidString } }),
        ])
    }

    private static func archive(_ m: YouTubeImport) throws -> LegacyModelArchive {
        try row(m.id, [
            "id": value(m.id),
            "playlistId": value(m.playlistId),
            "url": value(m.url),
            "title": value(m.title),
            "channel": value(m.channel),
            "artworkUrl": value(m.artworkUrl),
            "importedAt": value(m.importedAt),
            "lastSyncedAt": value(m.lastSyncedAt),
            "accountChannelID": value(m.accountChannelID),
            "remoteCheckedAt": value(m.remoteCheckedAt),
            "baseRevisionID": value(m.baseRevisionID),
            "remoteShadowRevisionID": value(m.remoteShadowRevisionID),
            "deletedAt": value(m.deletedAt),
            "remoteWritable": value(m.remoteWritable),
            "items": value(m.items.map { $0.map(\.id).sorted { $0.uuidString < $1.uuidString } }),
        ])
    }

    private static func archive(_ m: YouTubeImportItem) throws -> LegacyModelArchive {
        try row(m.id, [
            "id": value(m.id),
            "import_": value(m.import_?.id),
            "youTubeId": value(m.youTubeId),
            "playlistItemID": value(m.playlistItemID),
            "title": value(m.title),
            "artist": value(m.artist),
            "durationMs": value(m.durationMs),
            "order": value(m.order),
            "availabilityRaw": value(m.availabilityRaw),
            "track": value(m.track?.id),
        ])
    }

    private static func archive(_ m: PlaylistItem) throws -> LegacyModelArchive {
        try row(m.id, [
            "id": value(m.id),
            "order": value(m.order),
            "playlist": value(m.playlist?.id),
            "track": value(m.track?.id),
        ])
    }

    private static func archive(_ m: TrackNote) throws -> LegacyModelArchive {
        try row(m.id, [
            "id": value(m.id),
            "trackId": value(m.trackId),
            "content": value(m.content),
            "createdAt": value(m.createdAt),
            "updatedAt": value(m.updatedAt),
        ])
    }

    private static func archive(_ m: TrackBookmark) throws -> LegacyModelArchive {
        try row(m.id, [
            "id": value(m.id),
            "trackId": value(m.trackId),
            "timestampMs": value(m.timestampMs),
            "title": value(m.title),
            "note": value(m.note),
            "createdAt": value(m.createdAt),
        ])
    }

    private static func archive(_ m: ListeningEvent) throws -> LegacyModelArchive {
        try row(m.id, [
            "id": value(m.id),
            "trackId": value(m.trackId),
            "trackTitle": value(m.trackTitle),
            "artist": value(m.artist),
            "albumTitle": value(m.albumTitle),
            "startedAt": value(m.startedAt),
            "endedAt": value(m.endedAt),
            "listenedMs": value(m.listenedMs),
            "completionRatio": value(m.completionRatio),
            "outcomeRaw": value(m.outcomeRaw),
            "contextSummaryJSON": value(m.contextSummaryJSON),
            "sessionId": value(m.sessionId),
        ])
    }

    private static func archive(_ m: QueueState) throws -> LegacyModelArchive {
        try row(m.id, [
            "id": value(m.id),
            "itemsJSON": value(m.itemsJSON),
            "currentIndex": value(m.currentIndex),
            "upNextJSON": value(m.upNextJSON),
            "historyJSON": value(m.historyJSON),
            "repeatModeRaw": value(m.repeatModeRaw),
            "shuffle": value(m.shuffle),
            "savedAt": value(m.savedAt),
            "currentTrackId": value(m.currentTrackId),
            "lastPositionMs": value(m.lastPositionMs),
            "groupsJSON": value(m.groupsJSON),
        ])
    }

    private static func archive(_ m: EQPreset) throws -> LegacyModelArchive {
        try row(m.id, [
            "id": value(m.id),
            "name": value(m.name),
            "bandsJSON": value(m.bandsJSON),
            "createdAt": value(m.createdAt),
        ])
    }

    private static func archive(_ m: Playlist) throws -> LegacyModelArchive {
        try row(m.id, [
            "id": value(m.id),
            "name": value(m.name),
            "createdAt": value(m.createdAt),
            "pinned": value(m.pinned),
            "items": value(m.items.map { $0.map(\.id).sorted { $0.uuidString < $1.uuidString } }),
        ])
    }

    private static func archive(_ m: ListeningSession) throws -> LegacyModelArchive {
        try row(m.id, [
            "id": value(m.id),
            "startedAt": value(m.startedAt),
            "updatedAt": value(m.updatedAt),
            "endedAt": value(m.endedAt),
            "statusRaw": value(m.statusRaw),
            "queueSnapshotJSON": value(m.queueSnapshotJSON),
            "currentTrackId": value(m.currentTrackId),
            "currentPositionMs": value(m.currentPositionMs),
            "contextSummaryJSON": value(m.contextSummaryJSON),
        ])
    }

    private static func archive(_ m: InboxItem) throws -> LegacyModelArchive {
        try row(m.id, [
            "id": value(m.id),
            "trackId": value(m.trackId),
            "trackTitle": value(m.trackTitle),
            "artist": value(m.artist),
            "albumTitle": value(m.albumTitle),
            "durationSeconds": value(m.durationSeconds),
            "youTubeId": value(m.youTubeId),
            "artworkUrl": value(m.artworkUrl),
            "addedAt": value(m.addedAt),
            "sourceRaw": value(m.sourceRaw),
            "stateRaw": value(m.stateRaw),
            "snoozeUntil": value(m.snoozeUntil),
            "listenedMs": value(m.listenedMs),
            "notes": value(m.notes),
        ])
    }

    private static func archive(_ m: AutomationRule) throws -> LegacyModelArchive {
        try row(m.id, [
            "id": value(m.id),
            "name": value(m.name),
            "enabled": value(m.enabled),
            "triggerRaw": value(m.triggerRaw),
            "conditionsJSON": value(m.conditionsJSON),
            "actionRaw": value(m.actionRaw),
            "cooldownMs": value(m.cooldownMs),
            "lastFiredAt": value(m.lastFiredAt),
        ])
    }
}
