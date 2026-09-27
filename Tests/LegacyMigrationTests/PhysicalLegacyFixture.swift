import Foundation
import SwiftData
import SQLite3
import MusesPersistence
@testable import Muses

/// Writes the ORIGINAL 19 model types. Expected fields are recorded from input values,
/// independently of LegacyStoreReader, before any snapshot is opened.
@MainActor
final class PhysicalLegacyFixture {
    let container: ModelContainer
    let url: URL
    let domain = "muses.migration-proof." + UUID().uuidString
    let defaults = UserDefaults.standard
    var expected: [String: [LegacyModelArchive]] = [:]
    var explicitSettings: [String: Any] = [:]
    var pin: OpaquePointer?
    let trackID = UUID()
    let importID = UUID()
    let revisionID = UUID()
    let batchID = UUID()
    let playlistID = UUID()
    let sessionID = UUID()
    let epoch = Date(timeIntervalSinceReferenceDate: 765432100.125)

    init(url: URL) throws {
        self.url = url
        container = try ModelContainer(for: MusesSchema.current,
            configurations: [ModelConfiguration(schema: MusesSchema.current, url: url, cloudKitDatabase: .none)])
        // Pin the empty database snapshot so the later committed fixture lives in WAL.
        guard sqlite3_open(url.path, &pin) == SQLITE_OK,
              sqlite3_exec(pin, "PRAGMA wal_checkpoint(TRUNCATE); BEGIN; SELECT count(*) FROM ZTRACK;", nil, nil, nil) == SQLITE_OK else {
            throw PersistenceError.corruptRecord("fixture WAL pin")
        }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let mYouTubePlaylistRevision = YouTubePlaylistRevision(importID: importID, accountChannelID: nil, kind: .base, snapshotData: Data(), fingerprint: "")
        context.insert(mYouTubePlaylistRevision)
        let mYouTubeSyncBatch = YouTubeSyncBatch(importID: importID, accountChannelID: nil, playlistID: "", baseRevisionID: revisionID, localRevisionID: revisionID, remoteRevisionID: revisionID, expectedRemoteFingerprint: "", desiredSnapshotData: Data(), preRemoteSnapshotData: Data())
        context.insert(mYouTubeSyncBatch)
        let mYouTubeSyncOperation = YouTubeSyncOperation(importID: importID, accountChannelID: nil, batchID: batchID, sequence: 0, kind: .insert, playlistItemID: nil, videoID: "abcdefghijk")
        context.insert(mYouTubeSyncOperation)
        let mCatalogRelease = CatalogRelease(stableID: "", title: "", artistName: "")
        context.insert(mCatalogRelease)
        let mCatalogArtist = CatalogArtist(stableID: "", name: "")
        context.insert(mCatalogArtist)
        let mFocusSession = FocusSession()
        context.insert(mFocusSession)
        let mTrack = Track(title: "", artist: "", youTubeId: "abcdefghijk")
        context.insert(mTrack)
        let mYouTubeImport = YouTubeImport(playlistId: "", url: "", title: "", channel: "")
        context.insert(mYouTubeImport)
        let mYouTubeImportItem = YouTubeImportItem(youTubeId: "abcdefghijk", title: "", artist: "")
        context.insert(mYouTubeImportItem)
        let mPlaylistItem = PlaylistItem(order: 0)
        context.insert(mPlaylistItem)
        let mTrackNote = TrackNote(trackId: trackID)
        context.insert(mTrackNote)
        let mTrackBookmark = TrackBookmark(trackId: trackID, timestampMs: 0)
        context.insert(mTrackBookmark)
        let mListeningEvent = ListeningEvent(trackId: trackID, trackTitle: "", artist: "", startedAt: epoch, outcome: .completed)
        context.insert(mListeningEvent)
        let mQueueState = QueueState(itemsJSON: "[]", currentIndex: -1, upNextJSON: "[]", historyJSON: "[]", repeatModeRaw: "off", shuffle: false)
        context.insert(mQueueState)
        let mEQPreset = EQPreset(name: "", bandsJSON: "[]")
        context.insert(mEQPreset)
        let mPlaylist = Playlist(name: "")
        context.insert(mPlaylist)
        let mListeningSession = ListeningSession()
        context.insert(mListeningSession)
        let mInboxItem = InboxItem(trackId: trackID, trackTitle: "", artist: "", albumTitle: nil, durationSeconds: 0, youTubeId: "abcdefghijk", artworkUrl: nil)
        context.insert(mInboxItem)
        let mAutomationRule = AutomationRule(name: "", trigger: .trackStarted, action: .likeTrack)
        context.insert(mAutomationRule)
        let duplicatePlaylistItem = PlaylistItem(order: 1, playlist: mPlaylist, track: mTrack)
        let duplicateImportItem = YouTubeImportItem(youTubeId: "abcdefghijk", title: "duplicate", artist: "artist", order: 1, playlistItemID: "remote-duplicate")
        context.insert(duplicatePlaylistItem)
        context.insert(duplicateImportItem)
        duplicateImportItem.import_ = mYouTubeImport
        duplicateImportItem.track = mTrack
        let group = QueueGroup(name: "保留 group", order: 0, collapsed: true)
        let queueTrack = TrackSnapshot(id: trackID, title: "queue title", artist: "queue artist", albumTitle: nil,
            durationSeconds: 12.5, youTubeId: "abcdefghijk", artworkUrl: nil, sampleRate: nil,
            bitDepth: nil, codec: nil, isLossless: false, liked: true, lyrics: "line\n歌词", lyricsOffsetMs: -250)
        func queueJSON(_ history: Bool = false) throws -> String {
            String(decoding: try JSONEncoder().encode([QueueItem(track: queueTrack, queuedAt: epoch,
                fromContext: .playlist, locked: true, groupId: group.id, priority: 7,
                historyState: history ? .skipped : nil)]), as: UTF8.self)
        }
        let itemsJSON = try queueJSON()
        let upNextJSON = try queueJSON()
        let historyJSON = try queueJSON(true)
        let groupsJSON = String(decoding: try JSONEncoder().encode([group]), as: UTF8.self)
        mYouTubePlaylistRevision.id = revisionID
        mYouTubeSyncBatch.id = batchID
        mYouTubeSyncOperation.id = UUID()
        mCatalogRelease.id = UUID()
        mCatalogArtist.id = UUID()
        mFocusSession.id = UUID()
        mTrack.id = trackID
        mYouTubeImport.id = importID
        mYouTubeImportItem.id = UUID()
        mPlaylistItem.id = UUID()
        mTrackNote.id = UUID()
        mTrackBookmark.id = UUID()
        mListeningEvent.id = UUID()
        mQueueState.id = UUID()
        mEQPreset.id = UUID()
        mPlaylist.id = playlistID
        mListeningSession.id = sessionID
        mInboxItem.id = UUID()
        mAutomationRule.id = UUID()
        let syncSnapshot = YouTubePlaylistSnapshot(playlistID: "PL-fixture", accountChannelID: "UC-fixture",
            title: "Connected playlist", capturedAt: epoch, items: [
                YouTubePlaylistItemSnapshot(id: mYouTubeImportItem.id, playlistItemID: "remote-first",
                    videoID: "abcdefghijk", title: "Original", artist: "Artist", durationMs: 12500,
                    order: 0, availability: .available),
                YouTubePlaylistItemSnapshot(id: duplicateImportItem.id, playlistItemID: "remote-duplicate",
                    videoID: "abcdefghijk", title: "Duplicate", artist: "Artist", durationMs: 12500,
                    order: 1, availability: .available)
            ], pagination: .init(completeness: .complete, pageCount: 1, nextPageToken: nil, itemCount: 2))
        let syncData = try JSONEncoder().encode(syncSnapshot)
        let contextJSON = String(decoding: try JSONEncoder().encode(ListeningContext(hour: 10, dayOfWeek: 2,
            isWeekend: false, frontmostAppBundleId: nil, outputDeviceName: "Headphones", isHeadphones: true)), as: UTF8.self)
        let conditionsJSON = String(decoding: try JSONEncoder().encode(AutomationConditions(timeBand: .morning,
            isHeadphones: true)), as: UTF8.self)
        var fYouTubePlaylistRevision: [String: Any] = [:]
        try assign(mYouTubePlaylistRevision, \.id, mYouTubePlaylistRevision.id, "id", &fYouTubePlaylistRevision)
        try assign(mYouTubePlaylistRevision, \.importID, importID, "importID", &fYouTubePlaylistRevision)
        try assign(mYouTubePlaylistRevision, \.accountChannelID, "YouTubePlaylistRevision.accountChannelID — 用户编辑", "accountChannelID", &fYouTubePlaylistRevision)
        try assign(mYouTubePlaylistRevision, \.kindRaw, "base", "kindRaw", &fYouTubePlaylistRevision)
        try assign(mYouTubePlaylistRevision, \.createdAt, epoch.addingTimeInterval(4), "createdAt", &fYouTubePlaylistRevision)
        try assign(mYouTubePlaylistRevision, \.snapshotData, syncData, "snapshotData", &fYouTubePlaylistRevision)
        try assign(mYouTubePlaylistRevision, \.fingerprint, syncSnapshot.fingerprint, "fingerprint", &fYouTubePlaylistRevision)
        try assign(mYouTubePlaylistRevision, \.pinned, true, "pinned", &fYouTubePlaylistRevision)
        var fYouTubeSyncBatch: [String: Any] = [:]
        try assign(mYouTubeSyncBatch, \.id, mYouTubeSyncBatch.id, "id", &fYouTubeSyncBatch)
        try assign(mYouTubeSyncBatch, \.importID, importID, "importID", &fYouTubeSyncBatch)
        try assign(mYouTubeSyncBatch, \.accountChannelID, "YouTubeSyncBatch.accountChannelID — 用户编辑", "accountChannelID", &fYouTubeSyncBatch)
        try assign(mYouTubeSyncBatch, \.playlistID, "YouTubeSyncBatch.playlistID — 用户编辑", "playlistID", &fYouTubeSyncBatch)
        try assign(mYouTubeSyncBatch, \.stateRaw, "started", "stateRaw", &fYouTubeSyncBatch)
        try assign(mYouTubeSyncBatch, \.baseRevisionID, revisionID, "baseRevisionID", &fYouTubeSyncBatch)
        try assign(mYouTubeSyncBatch, \.localRevisionID, revisionID, "localRevisionID", &fYouTubeSyncBatch)
        try assign(mYouTubeSyncBatch, \.remoteRevisionID, revisionID, "remoteRevisionID", &fYouTubeSyncBatch)
        try assign(mYouTubeSyncBatch, \.expectedRemoteFingerprint, syncSnapshot.fingerprint, "expectedRemoteFingerprint", &fYouTubeSyncBatch)
        try assign(mYouTubeSyncBatch, \.desiredSnapshotData, syncData, "desiredSnapshotData", &fYouTubeSyncBatch)
        try assign(mYouTubeSyncBatch, \.preRemoteSnapshotData, syncData, "preRemoteSnapshotData", &fYouTubeSyncBatch)
        try assign(mYouTubeSyncBatch, \.createdAt, epoch.addingTimeInterval(11), "createdAt", &fYouTubeSyncBatch)
        try assign(mYouTubeSyncBatch, \.startedAt, epoch.addingTimeInterval(12), "startedAt", &fYouTubeSyncBatch)
        try assign(mYouTubeSyncBatch, \.remoteObservedAt, epoch.addingTimeInterval(13), "remoteObservedAt", &fYouTubeSyncBatch)
        try assign(mYouTubeSyncBatch, \.completedAt, epoch.addingTimeInterval(14), "completedAt", &fYouTubeSyncBatch)
        try assign(mYouTubeSyncBatch, \.invalidatedReason, "YouTubeSyncBatch.invalidatedReason — 用户编辑", "invalidatedReason", &fYouTubeSyncBatch)
        var fYouTubeSyncOperation: [String: Any] = [:]
        try assign(mYouTubeSyncOperation, \.id, mYouTubeSyncOperation.id, "id", &fYouTubeSyncOperation)
        try assign(mYouTubeSyncOperation, \.idempotencyKey, "YouTubeSyncOperation.idempotencyKey — 用户编辑", "idempotencyKey", &fYouTubeSyncOperation)
        try assign(mYouTubeSyncOperation, \.importID, importID, "importID", &fYouTubeSyncOperation)
        try assign(mYouTubeSyncOperation, \.accountChannelID, "YouTubeSyncOperation.accountChannelID — 用户编辑", "accountChannelID", &fYouTubeSyncOperation)
        try assign(mYouTubeSyncOperation, \.batchID, batchID, "batchID", &fYouTubeSyncOperation)
        try assign(mYouTubeSyncOperation, \.sequence, 106, "sequence", &fYouTubeSyncOperation)
        try assign(mYouTubeSyncOperation, \.kindRaw, "move", "kindRaw", &fYouTubeSyncOperation)
        try assign(mYouTubeSyncOperation, \.stateRaw, "needsConfirmation", "stateRaw", &fYouTubeSyncOperation)
        try assign(mYouTubeSyncOperation, \.playlistItemID, "YouTubeSyncOperation.playlistItemID — 用户编辑", "playlistItemID", &fYouTubeSyncOperation)
        try assign(mYouTubeSyncOperation, \.videoID, "abcdefghijk", "videoID", &fYouTubeSyncOperation)
        try assign(mYouTubeSyncOperation, \.fromPosition, 111, "fromPosition", &fYouTubeSyncOperation)
        try assign(mYouTubeSyncOperation, \.toPosition, 112, "toPosition", &fYouTubeSyncOperation)
        try assign(mYouTubeSyncOperation, \.previousPlaylistItemID, "YouTubeSyncOperation.previousPlaylistItemID — 用户编辑", "previousPlaylistItemID", &fYouTubeSyncOperation)
        try assign(mYouTubeSyncOperation, \.nextPlaylistItemID, "YouTubeSyncOperation.nextPlaylistItemID — 用户编辑", "nextPlaylistItemID", &fYouTubeSyncOperation)
        try assign(mYouTubeSyncOperation, \.remoteResultID, "YouTubeSyncOperation.remoteResultID — 用户编辑", "remoteResultID", &fYouTubeSyncOperation)
        try assign(mYouTubeSyncOperation, \.attempts, 116, "attempts", &fYouTubeSyncOperation)
        try assign(mYouTubeSyncOperation, \.lastError, "YouTubeSyncOperation.lastError — 用户编辑", "lastError", &fYouTubeSyncOperation)
        try assign(mYouTubeSyncOperation, \.createdAt, epoch.addingTimeInterval(17), "createdAt", &fYouTubeSyncOperation)
        try assign(mYouTubeSyncOperation, \.startedAt, epoch.addingTimeInterval(18), "startedAt", &fYouTubeSyncOperation)
        try assign(mYouTubeSyncOperation, \.remoteObservedAt, epoch.addingTimeInterval(19), "remoteObservedAt", &fYouTubeSyncOperation)
        try assign(mYouTubeSyncOperation, \.completedAt, epoch.addingTimeInterval(20), "completedAt", &fYouTubeSyncOperation)
        var fCatalogRelease: [String: Any] = [:]
        try assign(mCatalogRelease, \.id, mCatalogRelease.id, "id", &fCatalogRelease)
        try assign(mCatalogRelease, \.stableID, "CatalogRelease.stableID — 用户编辑", "stableID", &fCatalogRelease)
        try assign(mCatalogRelease, \.title, "CatalogRelease.title — 用户编辑", "title", &fCatalogRelease)
        try assign(mCatalogRelease, \.artistName, "CatalogRelease.artistName — 用户编辑", "artistName", &fCatalogRelease)
        try assign(mCatalogRelease, \.artistStableID, "CatalogRelease.artistStableID — 用户编辑", "artistStableID", &fCatalogRelease)
        try assign(mCatalogRelease, \.artworkURL, "CatalogRelease.artworkURL — 用户编辑", "artworkURL", &fCatalogRelease)
        try assign(mCatalogRelease, \.year, 107, "year", &fCatalogRelease)
        try assign(mCatalogRelease, \.kindRaw, "album", "kindRaw", &fCatalogRelease)
        try assign(mCatalogRelease, \.refreshedAt, epoch.addingTimeInterval(8), "refreshedAt", &fCatalogRelease)
        try assign(mCatalogRelease, \.unavailable, true, "unavailable", &fCatalogRelease)
        var fCatalogArtist: [String: Any] = [:]
        try assign(mCatalogArtist, \.id, mCatalogArtist.id, "id", &fCatalogArtist)
        try assign(mCatalogArtist, \.stableID, "CatalogArtist.stableID — 用户编辑", "stableID", &fCatalogArtist)
        try assign(mCatalogArtist, \.name, "CatalogArtist.name — 用户编辑", "name", &fCatalogArtist)
        try assign(mCatalogArtist, \.channelID, "CatalogArtist.channelID — 用户编辑", "channelID", &fCatalogArtist)
        try assign(mCatalogArtist, \.browseID, "CatalogArtist.browseID — 用户编辑", "browseID", &fCatalogArtist)
        try assign(mCatalogArtist, \.artworkURL, "CatalogArtist.artworkURL — 用户编辑", "artworkURL", &fCatalogArtist)
        try assign(mCatalogArtist, \.biography, "CatalogArtist.biography — 用户编辑", "biography", &fCatalogArtist)
        try assign(mCatalogArtist, \.refreshedAt, epoch.addingTimeInterval(7), "refreshedAt", &fCatalogArtist)
        try assign(mCatalogArtist, \.unavailable, true, "unavailable", &fCatalogArtist)
        var fFocusSession: [String: Any] = [:]
        try assign(mFocusSession, \.id, mFocusSession.id, "id", &fFocusSession)
        try assign(mFocusSession, \.startedAt, epoch.addingTimeInterval(1), "startedAt", &fFocusSession)
        try assign(mFocusSession, \.plannedDurationMs, 103, "plannedDurationMs", &fFocusSession)
        try assign(mFocusSession, \.endedAt, epoch.addingTimeInterval(3), "endedAt", &fFocusSession)
        try assign(mFocusSession, \.playlistId, playlistID, "playlistId", &fFocusSession)
        try assign(mFocusSession, \.listeningSessionId, sessionID, "listeningSessionId", &fFocusSession)
        try assign(mFocusSession, \.statusRaw, "completed", "statusRaw", &fFocusSession)
        var fTrack: [String: Any] = [:]
        try assign(mTrack, \.id, mTrack.id, "id", &fTrack)
        try assign(mTrack, \.title, "Track.title — 用户编辑", "title", &fTrack)
        try assign(mTrack, \.artist, "Track.artist — 用户编辑", "artist", &fTrack)
        try assign(mTrack, \.albumTitle, "Track.albumTitle — 用户编辑", "albumTitle", &fTrack)
        try assign(mTrack, \.albumArtist, "Track.albumArtist — 用户编辑", "albumArtist", &fTrack)
        try assign(mTrack, \.durationMs, 106, "durationMs", &fTrack)
        try assign(mTrack, \.trackNo, 107, "trackNo", &fTrack)
        try assign(mTrack, \.discNo, 108, "discNo", &fTrack)
        try assign(mTrack, \.year, 109, "year", &fTrack)
        try assign(mTrack, \.genre, "Track.genre — 用户编辑", "genre", &fTrack)
        try assign(mTrack, \.youTubeId, "abcdefghijk", "youTubeId", &fTrack)
        try assign(mTrack, \.mediaKindRaw, "musicVideo", "mediaKindRaw", &fTrack)
        try assign(mTrack, \.releaseCatalogID, "Track.releaseCatalogID — 用户编辑", "releaseCatalogID", &fTrack)
        try assign(mTrack, \.releaseOrder, 114, "releaseOrder", &fTrack)
        try assign(mTrack, \.artistCatalogID, "Track.artistCatalogID — 用户编辑", "artistCatalogID", &fTrack)
        try assign(mTrack, \.artworkUrl, "Track.artworkUrl — 用户编辑", "artworkUrl", &fTrack)
        try assign(mTrack, \.lyrics, "Track.lyrics — 用户编辑", "lyrics", &fTrack)
        try assign(mTrack, \.lyricsOffsetMs, 118, "lyricsOffsetMs", &fTrack)
        try assign(mTrack, \.replayGain, 18.125, "replayGain", &fTrack)
        try assign(mTrack, \.sampleRate, 120, "sampleRate", &fTrack)
        try assign(mTrack, \.bitDepth, 121, "bitDepth", &fTrack)
        try assign(mTrack, \.codec, "Track.codec — 用户编辑", "codec", &fTrack)
        try assign(mTrack, \.bitRate, 123, "bitRate", &fTrack)
        try assign(mTrack, \.channels, 124, "channels", &fTrack)
        try assign(mTrack, \.isLossless, true, "isLossless", &fTrack)
        try assign(mTrack, \.metadataStatusRaw, "complete", "metadataStatusRaw", &fTrack)
        try assign(mTrack, \.availabilityRaw, "available", "availabilityRaw", &fTrack)
        try assign(mTrack, \.addedAt, epoch.addingTimeInterval(27), "addedAt", &fTrack)
        try assign(mTrack, \.lastPlayedAt, epoch.addingTimeInterval(28), "lastPlayedAt", &fTrack)
        try assign(mTrack, \.playCount, 130, "playCount", &fTrack)
        try assign(mTrack, \.liked, true, "liked", &fTrack)
        var fYouTubeImport: [String: Any] = [:]
        try assign(mYouTubeImport, \.id, mYouTubeImport.id, "id", &fYouTubeImport)
        try assign(mYouTubeImport, \.playlistId, "YouTubeImport.playlistId — 用户编辑", "playlistId", &fYouTubeImport)
        try assign(mYouTubeImport, \.url, "YouTubeImport.url — 用户编辑", "url", &fYouTubeImport)
        try assign(mYouTubeImport, \.title, "YouTubeImport.title — 用户编辑", "title", &fYouTubeImport)
        try assign(mYouTubeImport, \.channel, "YouTubeImport.channel — 用户编辑", "channel", &fYouTubeImport)
        try assign(mYouTubeImport, \.artworkUrl, "YouTubeImport.artworkUrl — 用户编辑", "artworkUrl", &fYouTubeImport)
        try assign(mYouTubeImport, \.importedAt, epoch.addingTimeInterval(6), "importedAt", &fYouTubeImport)
        try assign(mYouTubeImport, \.lastSyncedAt, epoch.addingTimeInterval(7), "lastSyncedAt", &fYouTubeImport)
        try assign(mYouTubeImport, \.accountChannelID, "YouTubeImport.accountChannelID — 用户编辑", "accountChannelID", &fYouTubeImport)
        try assign(mYouTubeImport, \.remoteCheckedAt, epoch.addingTimeInterval(9), "remoteCheckedAt", &fYouTubeImport)
        try assign(mYouTubeImport, \.baseRevisionID, revisionID, "baseRevisionID", &fYouTubeImport)
        try assign(mYouTubeImport, \.remoteShadowRevisionID, revisionID, "remoteShadowRevisionID", &fYouTubeImport)
        try assign(mYouTubeImport, \.deletedAt, epoch.addingTimeInterval(12), "deletedAt", &fYouTubeImport)
        try assign(mYouTubeImport, \.remoteWritable, true, "remoteWritable", &fYouTubeImport)
        var fYouTubeImportItem: [String: Any] = [:]
        try assign(mYouTubeImportItem, \.id, mYouTubeImportItem.id, "id", &fYouTubeImportItem)
        try assign(mYouTubeImportItem, \.youTubeId, "abcdefghijk", "youTubeId", &fYouTubeImportItem)
        try assign(mYouTubeImportItem, \.playlistItemID, "YouTubeImportItem.playlistItemID — 用户编辑", "playlistItemID", &fYouTubeImportItem)
        try assign(mYouTubeImportItem, \.title, "YouTubeImportItem.title — 用户编辑", "title", &fYouTubeImportItem)
        try assign(mYouTubeImportItem, \.artist, "YouTubeImportItem.artist — 用户编辑", "artist", &fYouTubeImportItem)
        try assign(mYouTubeImportItem, \.durationMs, 107, "durationMs", &fYouTubeImportItem)
        try assign(mYouTubeImportItem, \.order, 108, "order", &fYouTubeImportItem)
        try assign(mYouTubeImportItem, \.availabilityRaw, "available", "availabilityRaw", &fYouTubeImportItem)
        var fPlaylistItem: [String: Any] = [:]
        try assign(mPlaylistItem, \.id, mPlaylistItem.id, "id", &fPlaylistItem)
        try assign(mPlaylistItem, \.order, 102, "order", &fPlaylistItem)
        var fTrackNote: [String: Any] = [:]
        try assign(mTrackNote, \.id, mTrackNote.id, "id", &fTrackNote)
        try assign(mTrackNote, \.trackId, trackID, "trackId", &fTrackNote)
        try assign(mTrackNote, \.content, "TrackNote.content — 用户编辑", "content", &fTrackNote)
        try assign(mTrackNote, \.createdAt, epoch.addingTimeInterval(3), "createdAt", &fTrackNote)
        try assign(mTrackNote, \.updatedAt, epoch.addingTimeInterval(4), "updatedAt", &fTrackNote)
        var fTrackBookmark: [String: Any] = [:]
        try assign(mTrackBookmark, \.id, mTrackBookmark.id, "id", &fTrackBookmark)
        try assign(mTrackBookmark, \.trackId, trackID, "trackId", &fTrackBookmark)
        try assign(mTrackBookmark, \.timestampMs, 2.125, "timestampMs", &fTrackBookmark)
        try assign(mTrackBookmark, \.title, "TrackBookmark.title — 用户编辑", "title", &fTrackBookmark)
        try assign(mTrackBookmark, \.note, "TrackBookmark.note — 用户编辑", "note", &fTrackBookmark)
        try assign(mTrackBookmark, \.createdAt, epoch.addingTimeInterval(5), "createdAt", &fTrackBookmark)
        var fListeningEvent: [String: Any] = [:]
        try assign(mListeningEvent, \.id, mListeningEvent.id, "id", &fListeningEvent)
        try assign(mListeningEvent, \.trackId, trackID, "trackId", &fListeningEvent)
        try assign(mListeningEvent, \.trackTitle, "ListeningEvent.trackTitle — 用户编辑", "trackTitle", &fListeningEvent)
        try assign(mListeningEvent, \.artist, "ListeningEvent.artist — 用户编辑", "artist", &fListeningEvent)
        try assign(mListeningEvent, \.albumTitle, "ListeningEvent.albumTitle — 用户编辑", "albumTitle", &fListeningEvent)
        try assign(mListeningEvent, \.startedAt, epoch.addingTimeInterval(5), "startedAt", &fListeningEvent)
        try assign(mListeningEvent, \.endedAt, epoch.addingTimeInterval(6), "endedAt", &fListeningEvent)
        try assign(mListeningEvent, \.listenedMs, 108, "listenedMs", &fListeningEvent)
        try assign(mListeningEvent, \.completionRatio, 8.125, "completionRatio", &fListeningEvent)
        try assign(mListeningEvent, \.outcomeRaw, "completed", "outcomeRaw", &fListeningEvent)
        try assign(mListeningEvent, \.contextSummaryJSON, contextJSON, "contextSummaryJSON", &fListeningEvent)
        try assign(mListeningEvent, \.sessionId, sessionID, "sessionId", &fListeningEvent)
        var fQueueState: [String: Any] = [:]
        try assign(mQueueState, \.id, mQueueState.id, "id", &fQueueState)
        try assign(mQueueState, \.itemsJSON, itemsJSON, "itemsJSON", &fQueueState)
        try assign(mQueueState, \.currentIndex, 0, "currentIndex", &fQueueState)
        try assign(mQueueState, \.upNextJSON, upNextJSON, "upNextJSON", &fQueueState)
        try assign(mQueueState, \.historyJSON, historyJSON, "historyJSON", &fQueueState)
        try assign(mQueueState, \.repeatModeRaw, "all", "repeatModeRaw", &fQueueState)
        try assign(mQueueState, \.shuffle, true, "shuffle", &fQueueState)
        try assign(mQueueState, \.savedAt, epoch.addingTimeInterval(7), "savedAt", &fQueueState)
        try assign(mQueueState, \.currentTrackId, trackID, "currentTrackId", &fQueueState)
        try assign(mQueueState, \.lastPositionMs, 9.125, "lastPositionMs", &fQueueState)
        try assign(mQueueState, \.groupsJSON, groupsJSON, "groupsJSON", &fQueueState)
        var fEQPreset: [String: Any] = [:]
        try assign(mEQPreset, \.id, mEQPreset.id, "id", &fEQPreset)
        try assign(mEQPreset, \.name, "EQPreset.name — 用户编辑", "name", &fEQPreset)
        try assign(mEQPreset, \.bandsJSON, EQPreset.encode(BuiltinEQPresets.hifi()), "bandsJSON", &fEQPreset)
        try assign(mEQPreset, \.createdAt, epoch.addingTimeInterval(3), "createdAt", &fEQPreset)
        var fPlaylist: [String: Any] = [:]
        try assign(mPlaylist, \.id, mPlaylist.id, "id", &fPlaylist)
        try assign(mPlaylist, \.name, "Playlist.name — 用户编辑", "name", &fPlaylist)
        try assign(mPlaylist, \.createdAt, epoch.addingTimeInterval(2), "createdAt", &fPlaylist)
        try assign(mPlaylist, \.pinned, true, "pinned", &fPlaylist)
        var fListeningSession: [String: Any] = [:]
        try assign(mListeningSession, \.id, mListeningSession.id, "id", &fListeningSession)
        try assign(mListeningSession, \.startedAt, epoch.addingTimeInterval(1), "startedAt", &fListeningSession)
        try assign(mListeningSession, \.updatedAt, epoch.addingTimeInterval(2), "updatedAt", &fListeningSession)
        try assign(mListeningSession, \.endedAt, epoch.addingTimeInterval(3), "endedAt", &fListeningSession)
        try assign(mListeningSession, \.statusRaw, "ended", "statusRaw", &fListeningSession)
        try assign(mListeningSession, \.queueSnapshotJSON, itemsJSON, "queueSnapshotJSON", &fListeningSession)
        try assign(mListeningSession, \.currentTrackId, trackID, "currentTrackId", &fListeningSession)
        try assign(mListeningSession, \.currentPositionMs, 7.125, "currentPositionMs", &fListeningSession)
        try assign(mListeningSession, \.contextSummaryJSON, contextJSON, "contextSummaryJSON", &fListeningSession)
        var fInboxItem: [String: Any] = [:]
        try assign(mInboxItem, \.id, mInboxItem.id, "id", &fInboxItem)
        try assign(mInboxItem, \.trackId, trackID, "trackId", &fInboxItem)
        try assign(mInboxItem, \.trackTitle, "InboxItem.trackTitle — 用户编辑", "trackTitle", &fInboxItem)
        try assign(mInboxItem, \.artist, "InboxItem.artist — 用户编辑", "artist", &fInboxItem)
        try assign(mInboxItem, \.albumTitle, "InboxItem.albumTitle — 用户编辑", "albumTitle", &fInboxItem)
        try assign(mInboxItem, \.durationSeconds, 5.125, "durationSeconds", &fInboxItem)
        try assign(mInboxItem, \.youTubeId, "abcdefghijk", "youTubeId", &fInboxItem)
        try assign(mInboxItem, \.artworkUrl, "InboxItem.artworkUrl — 用户编辑", "artworkUrl", &fInboxItem)
        try assign(mInboxItem, \.addedAt, epoch.addingTimeInterval(8), "addedAt", &fInboxItem)
        try assign(mInboxItem, \.sourceRaw, "youTubeImport", "sourceRaw", &fInboxItem)
        try assign(mInboxItem, \.stateRaw, "snoozed", "stateRaw", &fInboxItem)
        try assign(mInboxItem, \.snoozeUntil, epoch.addingTimeInterval(11), "snoozeUntil", &fInboxItem)
        try assign(mInboxItem, \.listenedMs, 12.125, "listenedMs", &fInboxItem)
        try assign(mInboxItem, \.notes, "InboxItem.notes — 用户编辑", "notes", &fInboxItem)
        var fAutomationRule: [String: Any] = [:]
        try assign(mAutomationRule, \.id, mAutomationRule.id, "id", &fAutomationRule)
        try assign(mAutomationRule, \.name, "AutomationRule.name — 用户编辑", "name", &fAutomationRule)
        try assign(mAutomationRule, \.enabled, true, "enabled", &fAutomationRule)
        try assign(mAutomationRule, \.triggerRaw, "trackCompleted", "triggerRaw", &fAutomationRule)
        try assign(mAutomationRule, \.conditionsJSON, conditionsJSON, "conditionsJSON", &fAutomationRule)
        try assign(mAutomationRule, \.actionRaw, "addToInbox", "actionRaw", &fAutomationRule)
        try assign(mAutomationRule, \.cooldownMs, 107, "cooldownMs", &fAutomationRule)
        try assign(mAutomationRule, \.lastFiredAt, epoch.addingTimeInterval(7), "lastFiredAt", &fAutomationRule)
        mTrack.youTubeImportItems = [mYouTubeImportItem, duplicateImportItem]
        fTrack["youTubeImportItems"] = try json([mYouTubeImportItem.id, duplicateImportItem.id].sorted { $0.uuidString < $1.uuidString })
        mYouTubeImport.items = [mYouTubeImportItem, duplicateImportItem]
        fYouTubeImport["items"] = try json([mYouTubeImportItem.id, duplicateImportItem.id].sorted { $0.uuidString < $1.uuidString })
        mPlaylist.items = [mPlaylistItem, duplicatePlaylistItem]
        fPlaylist["items"] = try json([mPlaylistItem.id, duplicatePlaylistItem.id].sorted { $0.uuidString < $1.uuidString })
        mYouTubeImportItem.import_ = mYouTubeImport
        fYouTubeImportItem["import_"] = try json(importID)
        mYouTubeImportItem.track = mTrack
        fYouTubeImportItem["track"] = try json(trackID)
        mPlaylistItem.playlist = mPlaylist
        fPlaylistItem["playlist"] = try json(playlistID)
        mPlaylistItem.track = mTrack
        fPlaylistItem["track"] = try json(trackID)
        // Extra occurrences carry distinct IDs even though they reference the same Track.
        try append("PlaylistItem", duplicatePlaylistItem.id, ["id": json(duplicatePlaylistItem.id),
            "order": 1, "playlist": json(playlistID), "track": json(trackID)])
        try append("YouTubeImportItem", duplicateImportItem.id, ["id": json(duplicateImportItem.id),
            "import_": json(importID), "youTubeId": "abcdefghijk", "playlistItemID": "remote-duplicate",
            "title": "duplicate", "artist": "artist", "durationMs": 0, "order": 1,
            "availabilityRaw": "available", "track": json(trackID)])
        try append("YouTubePlaylistRevision", mYouTubePlaylistRevision.id, fYouTubePlaylistRevision)
        try append("YouTubeSyncBatch", mYouTubeSyncBatch.id, fYouTubeSyncBatch)
        try append("YouTubeSyncOperation", mYouTubeSyncOperation.id, fYouTubeSyncOperation)
        try append("CatalogRelease", mCatalogRelease.id, fCatalogRelease)
        try append("CatalogArtist", mCatalogArtist.id, fCatalogArtist)
        try append("FocusSession", mFocusSession.id, fFocusSession)
        try append("Track", mTrack.id, fTrack)
        try append("YouTubeImport", mYouTubeImport.id, fYouTubeImport)
        try append("YouTubeImportItem", mYouTubeImportItem.id, fYouTubeImportItem)
        try append("PlaylistItem", mPlaylistItem.id, fPlaylistItem)
        try append("TrackNote", mTrackNote.id, fTrackNote)
        try append("TrackBookmark", mTrackBookmark.id, fTrackBookmark)
        try append("ListeningEvent", mListeningEvent.id, fListeningEvent)
        try append("QueueState", mQueueState.id, fQueueState)
        try append("EQPreset", mEQPreset.id, fEQPreset)
        try append("Playlist", mPlaylist.id, fPlaylist)
        try append("ListeningSession", mListeningSession.id, fListeningSession)
        try append("InboxItem", mInboxItem.id, fInboxItem)
        try append("AutomationRule", mAutomationRule.id, fAutomationRule)
        try context.save()
        explicitSettings = ["muses.theme": "dark", "muses.playback.volume": 0.625,
            "muses.ff.notes": true, "muses.webHome.consentVersion": 3,
            "muses.updates.lastCheckAt": epoch, "muses.globalHotkeys.bindings": Data([0, 255]),
            "muses.search.recentQueries": ["Bach", "巴赫"],
            "muses.proof.dictionary": ["nested": ["enabled": true]]]
        defaults.setPersistentDomain(explicitSettings, forName: domain)
    }

    func closePinAndSettings() {
        if let pin { sqlite3_exec(pin, "ROLLBACK", nil, nil, nil); sqlite3_close(pin) }
        pin = nil
        defaults.removePersistentDomain(forName: domain)
    }

    private func assign<M: AnyObject, T: Encodable>(_ model: M, _ key: ReferenceWritableKeyPath<M, T>,
                                                   _ input: T, _ name: String, _ fields: inout [String: Any]) throws {
        model[keyPath: key] = input
        fields[name] = try json(input)
    }
    private func json<T: Encodable>(_ input: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(input), options: [.fragmentsAllowed])
    }
    private func append(_ model: String, _ id: UUID, _ fields: [String: Any]) throws {
        expected[model, default: []].append(.init(id: id,
            fields: try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]), fieldNames: Set(fields.keys)))
    }
}
