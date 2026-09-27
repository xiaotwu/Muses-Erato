# Muses-Erato privacy policy — release draft

Prepared 2026-09-27 for the public iOS implementation. **Not published or release approved.** Before publication, replace the contact placeholders, verify deletion/retention against the final build, and supply an accessible public policy URL. The app must present this policy for agreement before accessing YouTube features and keep it accessible in Settings.

## About this app

Muses-Erato is developed by xiaotwu. It uses YouTube API Services to browse YouTube content and show videos in the official embedded player. By using the YouTube features, you agree to the [YouTube Terms of Service](https://www.youtube.com/t/terms). Google's handling of data is described in the [Google Privacy Policy](https://policies.google.com/privacy).

## Information used and where it goes

- **Searches and content requests:** Your search text, requested video/channel/playlist identifiers and pagination parameters are sent directly from your device to Google to obtain results. Requests carry the app's project credential or, where applicable, an OAuth access token. Google receives network information such as your IP address.
- **Optional Google sign-in:** Google's system browser handles authentication. Muses does not ask for or store your Google password. With your consent, read-only YouTube access lets Muses display your channel, playlists and subscriptions. The current scope is `youtube.readonly`; Muses does not modify your YouTube subscriptions, playlists or uploads.
- **Tokens:** Access and refresh tokens are stored in the app's device-only Keychain item. They are used to make authorized requests and refresh access. The app does not send tokens to a developer-operated server.
- **Local library:** Saved video identifiers, favorites, local playlists, queue order and local viewing history are stored on your device. Notes and time bookmarks, when enabled in the release, are also local. A local playlist or favorite does not change your YouTube account.
- **Content metadata and artwork:** Muses obtains titles, channel information and thumbnails from Google. Catalog responses may be cached to reduce repeated requests. User-authored information and video identifiers are separate from API-derived metadata; the final release must enforce the documented metadata refresh/deletion limits.
- **Embedded playback:** YouTube serves video, controls and advertisements inside the player. Google may collect playback, device and network information and use cookies or similar storage in the app's WebView. Thumbnail requests also go to Google's image service. This third-party processing is covered by Google's policy. Muses does not remove advertisements or extract media files.
- **Imported libraries:** Upgrading an earlier Muses installation can preserve the old local database and a recovery archive while migration is verified. Those files may contain playlists, notes, bookmarks, queue entries, history and settings. They remain on the device and require the same privacy and deletion treatment as the active library.

The current public implementation has no developer-operated account backend, advertising SDK or analytics SDK. This statement does not mean Google receives no data through API requests, images, authentication or playback. Device backup behavior and Apple's optional diagnostic collection depend on your system settings; the final build's backup exclusions must be verified separately.

## Retention and your controls

You can use video links without Google sign-in. Signing in is optional for read-only account features. Signing out removes Muses' local account credentials and private catalog cache and attempts to revoke access with Google. If network revocation fails, local removal still occurs and Muses shows a notice. You can revoke access directly at [Google Account permissions](https://security.google.com/settings/security/permissions).

The local-data deletion action removes the app's local library and related state. It does not delete your Google account or alter videos, playlists or subscriptions on YouTube. The final release must include migration archives, recovery copies and player website storage in the stated deletion scope. If cleanup needs a restart, the app must report the pending cleanup and prevent reimport of deleted data. **Release verification pending: do not publish a claim of complete deletion until these paths pass.**

Public API metadata must be refreshed or removed within the policy's permitted storage period; keeping your local favorite or note does not justify indefinitely retaining an expired API title. Authorized responses must be cleared on sign-out/revocation and remain subject to Google's retention rules. Specific cache lifetime and refresh behavior will be recorded against the final release build.

## Contact and changes

For questions or complaints, use [Muses-Erato GitHub Issues](https://github.com/xiaotwu/Muses-Erato/issues). Do not send account passwords, verification codes, tokens or other private account data. Issues are public; describe the app behavior without identifying your Google account. Use the app's local deletion controls and Google's account-permissions page to manage your data.

We will update the policy when the app's data practices change. The released app must identify the current policy version and ask for renewed agreement when a change requires it.

## Publication checklist

- Confirm developer identity, contact channel, support URL and privacy-policy URL.
- Replace the pending retention/deletion statements with measured release behavior.
- Inventory Google embedded processing; decide App Privacy declarations and any ATT requirement from actual processing, not merely the absence of an analytics SDK.
- Verify app container backups, Keychain removal failures, network revoke failures, recovery archives and website data cleanup.
- Implement pre-feature agreement and Settings access; include Google policy, YouTube terms and Google revocation links.
- Match Google OAuth consent configuration, App Store Connect privacy answers and this document.

Sources: [YouTube API Developer Policies, III.A and III.E](https://developers.google.com/youtube/terms/developer-policies), [App Review Guidelines, 5.1](https://developer.apple.com/app-store/review/guidelines/#privacy).
