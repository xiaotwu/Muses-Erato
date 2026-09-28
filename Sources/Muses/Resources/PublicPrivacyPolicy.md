Muses-Erato privacy policy
Version 2026-09-28.2

Muses-Erato is developed by xiaotwu and uses YouTube API Services. Using its YouTube features means agreeing to the YouTube Terms of Service. The links below provide those terms, Google's privacy policy, support, and Google account permissions.

Search and playback

Search text and requested video, playlist and channel identifiers are sent directly from your device to Google. Google receives network information such as your IP address. YouTube supplies the visible player, content and advertisements. Google may collect playback/device information and use cookies or similar storage in the player's WebView. Thumbnails are requested from Google's image service. Google's privacy policy governs its processing. Before loading an embedded video, Muses requests its current audience and embedding status from YouTube. Videos designated Made for Kids, videos that disallow embedding, and videos whose status cannot be verified are not loaded in the app's player. You can choose to open them in YouTube; that service handles playback under its own policies.

Experimental background audio (IPA builds only)

If you enable Background audio in an experimental IPA build, Muses resolves playable media URLs locally using YouTubeKit and streams them directly from YouTube through the system audio player. Video identifiers and normal network information are sent to Google; this resolver does not receive your Google OAuth credentials or use a third-party extraction server. No media files are downloaded for offline use. Playback title, progress and artwork are shared with iOS for lock-screen and system playback controls. This playback route is separate from the embedded YouTube player and may be unavailable for some content. The public Release build does not expose it.

Home recommendations

Local Home shelves are built from your playlist membership, favorites and listening history on this device. Cloud Home requests are sent directly to YouTube Music. When signed in, Muses can attempt an account Home request using your Google access token; when account recommendations cannot be confirmed or loaded, the app identifies the available feed as public recommendations. This Music Home interface is separate from the YouTube Data API. Muses does not read or export browser cookies for this feature. Choosing the YouTube Music website opens that service, whose website session can differ from the app’s Google sign-in.

Optional sign-in

Google handles authentication in the system browser. Muses does not ask for or store your Google password. The app requests read-only YouTube access to display supported channel, playlist and subscription information. It does not modify your YouTube subscriptions, playlists or uploads. Access and refresh tokens are stored in this app's device-only Keychain item and used for authorized requests. They are not sent to a developer-operated server.

Local information

Saved video selections, favorites, local playlists, queue order, viewing history, notes and time bookmarks are stored on your device. Local favorites and playlists do not change your YouTube account. New catalog responses and API-provided titles are used during the current app session; the library keeps your selections and your own edits. Authorized catalog caches are cleared on sign-out. Muses has no developer-operated account backend, analytics SDK or advertising SDK; Google still receives information through its services and embedded advertisements.

Upgrades and retention

An upgrade can preserve the earlier local database and recovery copies during migration. These may contain history, playlists, notes, bookmarks, queue entries, settings and earlier metadata. They stay on your device and are separate from newly fetched catalog responses. Local information is retained until you remove it; deleting an editable item does not automatically remove an immutable recovery copy. The full local-data deletion action includes those copies. Device backups and optional system diagnostics depend on your Apple settings.

Your controls

Google sign-in is optional. Sign out removes the app’s local credentials and authorized caches. Revoke access additionally attempts to revoke the app’s Google permission. Account Home display is cleared when the account scope changes. If network revocation fails, review Google Account permissions using the link below. If local cleanup cannot finish, the app reports that it needs retry; a notice is not confirmation that all data was removed.

Deleting local Muses data does not delete your Google account or modify videos, playlists or subscriptions on YouTube. Migration archives, recovery copies and player website storage are included in the local deletion scope. Cleanup that requires restart is reported as pending and prevents reimport of deleted data. You can also revoke Muses access directly through Google Account permissions.

Support and changes

Use the Muses-Erato GitHub Issues support link below for questions or complaints. Issues are public: do not post Google account details, passwords, verification codes, tokens or other private information. Describe the app behavior without identifying your account. Use the app's deletion controls and Google Account permissions to manage your data.

The policy will be updated when data practices change. The app records only the policy version you agreed to and requires agreement to a new version before enabling its features. This non-account agreement remains when library data is cleared.
