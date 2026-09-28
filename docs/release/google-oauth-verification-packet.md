# Google OAuth verification packet — draft, not submitted

Updated 2026-09-27 against code `eb36a02`. The owner confirmed Audience is **Testing** and verification is **not complete**. This is a confirmed external public-release gate; successful owner sign-in does not close it. No Cloud configuration, branding publication or verification submission was performed.

## Submission prerequisites

The official process requires matching app branding, public homepage/privacy links, domain ownership evidence, declared scopes and feature justification. Branding must be published before requesting data-access verification. The demonstration must show the English consent flow, app identity/client ID and the features using each requested scope. Follow the live Verification Center for requested evidence. Source: [Google sensitive-scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification).

Testing allows only listed test users (up to 100); test authorizations expire after seven days, with documented exceptions for basic identity scopes. Muses requests YouTube account access rather than only basic identity. Moving Audience to production alone does not prove verification or unrestricted public access. Source: [Google Manage App Audience](https://support.google.com/cloud/answer/15549945?hl=en).

Public pages are prepared under `docs/site` but remain unpublished. Domain proof, provider/privacy decisions and final policy reconciliation must precede submitting their URLs as release evidence. GitHub Issues remains public support; Google requires its separate console contact fields. See [domain checklist](privacy-domain-check.md) and [publication package](github-publication.md).

## Requested scope and justification draft

Only `https://www.googleapis.com/auth/youtube.readonly` is allowed by the current OAuth implementation. Confirm its live classification in Data Access; no profile/email or write scope is requested by Muses.

> Muses Erato uses youtube.readonly to display the signed-in user's owned YouTube playlists, subscriptions and supported channel information. Users can select an owned playlist and import its video identifiers and ordered occurrences into a local library. Public API-key access cannot retrieve private account collections or the user's owned-playlist list. Read-only access is sufficient: Muses does not create, edit or delete YouTube playlists, subscriptions or account data. Local playlist, favorite, queue and note changes remain local. Playback uses the official visible YouTube player.

Verify this wording against the actual submission build and enabled UI. Do not claim complete YouTube Music library synchronization or background audio.

## App demonstration script to record with an approved test account

1. Identify the exact app build and project being submitted. Start from Settings and initiate Google sign-in. Capture the English consent flow, matching app identity and requested scope; retain the client-ID evidence Google requests using the supported system browser flow. Do not substitute a fabricated web OAuth client.
2. Return to Muses. Open Library → Playlists → Import. Show automatic owned-playlist loading, select a harmless test playlist, wait for all import pages and verify its source name/count.
3. Save the local copy. Show its ordered entries and visible playback. Show Songs Cards / List and explain that the local library does not write changes to the Google account.
4. Show supported subscriptions/channel views currently enabled by this scope. Do not demonstrate absent features.
5. Demonstrate sign-out and account-access removal. Explain that local data deletion, Google permission revocation and system-browser cookies have separate boundaries; avoid claiming removal of provider-side history or backups.
6. Review recording for passwords, verification codes, tokens, private playlists or unrelated personal content. The owner must supply the requested demonstration link and submission correspondence privately. This packet neither records nor uploads a video.

## Evidence still needed

| Item | Status |
| --- | --- |
| Audience / verification | Owner reports Testing / not completed |
| Public homepage, privacy and terms | Prepared locally, unpublished |
| Domain ownership / authorized-domain acceptance | Unverified |
| Brand publication and data-access approval | Not completed |
| Actual English consent/feature demonstration | Not recorded by this packet |
| Independent public-user authorization and refresh | Unverified |
| Final embedded-provider privacy declarations | Open; separate from OAuth approval |

Record only redacted statuses, build/commit, approved scope set, public URLs and outcome dates. Never commit secrets, personal review credentials or private contact correspondence.

## Follow-up: selected host / content status

The owner selected `xiaotwu.github.io`; see [deployment plan](pages-deployment-plan.md) for required host-root proof and currently unavailable URLs. The new [content-status restriction](content-status-validation.md) must be shown in the final demonstration/build description. The previously exported 79eff2e IPA predates this change; use a fresh final candidate when recording/submitting. Audience remains Testing and no verification evidence is closed by these local preparations.
