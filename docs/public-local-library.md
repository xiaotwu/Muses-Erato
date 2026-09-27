# Public local library and playlists

Base: `codex/erato-integration-base` at `dd6fabb`. Work is isolated in `codex/public-local-library`.

The public app now has device-local playlist creation, rename, confirmed deletion, an ordered detail list, a saved-video picker, duplicate-add prevention, swipe removal and native Edit/reorder controls. Video details expose favorite/unfavorite, add to playlist (including creating one with the video), play next, append to queue, and the official visible player / YouTube link. Library displays explicit empty states and local-only wording. Playlist deletion leaves saved videos and favorites intact.

Queue details expose the current item, ordered upcoming occurrences, native removal/reorder, append whole playlist, open next and confirmed clear-upcoming. Repeated videos retain distinct queue-entry UUIDs. The visible player offers inline move-to-next/remove actions without navigating away from its IFrame. At the end of the last video the app no longer reloads the same video. Restoring the app preserves queue order and leaves playback paused with the player closed.

History records only accepted current-generation IFrame playing events, once per queue occurrence. The library displays each video's most recent occurrence with stable identity; clearing history is confirmed and does not delete tracks, favorites or playlists. Favorite, playlist and structural queue edits publish to UI only after a successful save. Persistence failures remain visible.

## Data compatibility

- No schema reset or filename change. V1 public tracks, favorites, queue and initial history JSON remain readable.
- `localPlaylist` is a new record kind. Existing legacy `playlist` and `playlistItem` projections are never decoded as this new contract.
- Unknown record versions, invalid playlist order and broken library references fail closed. Future-version records cannot be overwritten; context saves/deletions roll back on failure.
- Native legacy SQLite/WAL/SHM still trigger the existing recovery gate. A public WAL/SHM without its main database also blocks fresh-store creation. Corrupt stores are not replaced. Automatic native-legacy migration is still a release blocker owned by the migration integration work.
- Debug UI testing uses a UUID-scoped separate store directory, reused across relaunches. It does not reset user stores and is excluded from Release.

## Verification

On 2026-09-27, Xcode 27 SDK / iOS 26.5 simulators:

- `swift test --package-path Packages/MusesDomain`: 3 passed.
- `swift test --package-path Packages/MusesQueue`: 3 passed.
- `swift test --package-path Packages/MusesPersistence`: 16 passed, including two new local-library disk/validation tests.
- iPhone 17e: 7 app unit tests and 3 UI tests passed. The app unit suite covers library/playlist/queue persistence, current-generation history, corrupt and partial store recovery, and rejected writes. UI suite covers empty installation, visible IFrame routing, favorites, playlist creation/add/reorder/rename/removal/deletion, queue reorder/removal/clear, and relaunch persistence.
- iPad mini (A17 Pro): 2 UI tests passed, covering sidebar navigation, visible IFrame routing, empty library, creating an empty playlist and its saved-video picker.
- Release simulator build passed. `scripts/audit-public-artifact.py` passed against that Release `.app`: no background modes/extensions or forbidden resolver symbols; official IFrame/Data API/OAuth endpoints remain. This is an unsigned simulator artifact, not a signed archive entitlement check. The Debug XCTest host embeds a test bundle and is not the artifact used for release auditing.

Commands (derived data and logs are outside the worktree):

```sh
xcodebuild -project Muses.xcodeproj -scheme Muses \
  -destination 'platform=iOS Simulator,id=780AC25A-56B5-40AF-9159-E96554EEA6D2' \
  -derivedDataPath /tmp/erato-local-library-build test
xcodebuild -project Muses.xcodeproj -scheme Muses \
  -destination 'platform=iOS Simulator,id=6A5B3E52-5047-4AD6-A304-E3AACCE9DF72' \
  -derivedDataPath /tmp/erato-local-library-ipad \
  -only-testing:MusesPublicUITests/PublicSmokeTests \
  -only-testing:MusesPublicUITests/PublicLocalLibraryUITests/testEmptyLibraryAndPlaylistCreation test
xcodebuild -project Muses.xcodeproj -scheme Muses -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/erato-local-library-release build
python3 scripts/audit-public-artifact.py \
  /tmp/erato-local-library-release/Build/Products/Release-iphonesimulator/Muses.app
```

## Remaining release limits

No new account playlist write API, media download, unofficial catalog/resolver, background audio or source-allowlist expansion is introduced. Playlists are local to the device and do not sync to YouTube. This work does not establish real-device IFrame playback, OAuth, App Store approval, minimum-iOS accessibility or very large library performance. Queue position remains checkpointed by the existing adapter integration; restoring the native snapshot does not yet seek the IFrame to that position.
