# Privacy and Settings implementation plan

Status: implementation authorized and completed; see `docs/quality-privacy-settings-handoff.md` for final code/test/screenshot evidence. Original read-only plan follows for decisions and scope. Planning date: 2026-09-29 (America/Los_Angeles). No application files or project manifests were changed for this plan.

Coordinator confirmation received: the sheet may dismiss or offer “Not now”; both return to the local gate with a “Continue setup” reopening action and no session construction. A full-policy round trip is not consent. The new policy version is `2026-09-29.1`. Missing or empty policy must fail closed for saved consent and test fixtures alike. Native introductory playback copy uses compile-time capability and must not apply Public foreground-only limitations to Native. The coordinator owns local docs/site and builder synchronization; archived/published release candidates remain untouched. Scoped operation state names have been requested from the session stream, with its actual API handoff still pending.

## Ownership and coordination

This workstream owns `PublicPrivacyView.swift`, `PublicSettingsViews.swift`, `PublicServiceLinks.swift`, `Sources/Muses/Resources/PublicPrivacyPolicy.md`, and privacy/settings tests. It does not edit RootView, session, project manifests, or networking. No Git commits or external publication. The coordinating chat handles design discussion, API decisions, integration and simulator reservation.

Read: `docs/quality-improvement-coordination.md`, `docs/project-quality-review-2026-09-29.md`, the owned source/resource/UI test files, and relevant composition/session implementation. The app currently constructs `PublicYouTubeSession` inside `PublicConsentedAppView`, invoked by the gate's content closure. Preserve that lazy boundary.

## Findings and required behavior

1. First launch currently displays the entire policy as one Text, with consent controls in a fixed bottom inset. Replace it with the approved concise native modal introduction and a separate full-policy destination. No account identity, thumbnails, WebView, network-backed content or session creation in the unconsented presentation host.
2. `PublicPrivacyPolicy.version` is `2026-09-28.2`. Consent is stored separately from account/library settings under `eratoPrivacyAcceptedVersion`; preserve this key and separation. Local-data deletion must not remove consent or hide the pending-cleanup session UI.
3. The current gate permits matching saved consent even if the bundled policy is absent; the Continue button only checks availability before *new* acceptance. Require a valid, nonempty full policy before either path enables features. The missing-policy state must offer support and keep features unavailable, including on a previously accepted install.
4. Agreement starts false. Continue requires explicit agreement to the current version and available policy; opening links, closing detail, dismissing the introduction or refusing must never write acceptance or construct content. Version mismatch starts a new consent flow. Recheck eligibility at the acceptance action, not only via button disabled styling.
5. Settings already groups Account, Library & data, Playback, Privacy & support. Preserve the content and all confirmation/cleanup protections. Account and Library currently display session-wide `failureMessage`; unrelated search/player/library errors can appear there. Pager errors are already scoped and should remain scoped.
6. The bundled policy's Cloud Home and account Home recommendation claims do not match the inspected Home implementation. Correct these against the final integrated app, including removing the Account Home cleanup claim if that feature remains absent. Do not alter unrelated retention/deletion guarantees without checking implementation.

## Proposed implementation, subject to approved design

### Consent modal and full policy

- Keep `PublicPrivacyGate` as the lazy conditional content boundary. Present a native SwiftUI sheet from a lightweight branded local host, never from an already-created app/session. Use iOS 26 native presentation/control glass with explicit availability checks; use supported native materials/system surfaces for iOS 18–25 and solid readable surfaces when Reduce Transparency is enabled. Avoid a glass surface for every paragraph.
- Provide the approved short product summary: organize YouTube videos/playlists, notes and time bookmarks; Public playback uses a visible player and pauses when it closes or the app backgrounds. Google receives service requests; sign-in is optional. Avoid promising playback without catalog/status verification. Determine Native-specific wording from compile-time capability without constructing a session; coordinate the exact copy for the Native build.
- Provide a local full-policy navigation action, YouTube terms and Google privacy links before consent. Full-policy navigation does not accept; browser actions are user-initiated and separate from automatic service/network construction. Keep existing `privacy.agreement`, `privacy.continue`, and `privacy.policy` identifiers where their meaning remains valid; add stable identifiers for introduction, policy action, version, terms, missing-policy state and Settings destinations.
- Use semantic heading views for full-policy sections, selectable body text and readable width. Normalize the existing resource to simple explicit Markdown headings, or parse its known section structure locally; use the bundled resource as the sole full-policy body rather than duplicating legal text in Swift. No remote policy load is needed to consent.
- Keep introduction/consent controls reachable at accessibility text sizes and on small screens: vertically scrollable content and actions, no fixed modal height or bottom controls consuming the entire screen. Agree state has a clear accessibility value; headings support VoiceOver navigation. Dismissal or “Not now” returns to the local gate, whose “Continue setup” action reopens the sheet; never expose features or record consent through dismissal.
- Provide Settings > Privacy & support > Privacy policy using the same full-policy component. Show policy version and agreed version/status read-only; do not offer a consent reset that could interrupt active cleanup. Settings can keep the existing browser/support/account-permission links.

### Settings

- Keep native grouped lists and navigation within the existing Settings sheet. Add app version and build from `CFBundleShortVersionString` and `CFBundleVersion`, with sensible unavailable-value rendering. Show actual Public versus Experimental Native capability from compile conditions; Debug is not a distribution channel. No project Info.plist change is required for existing version/build values.
- Display refresh progress/results with Refresh details; deletion progress/pending-restart/failure with Delete local data; sign-in/sign-out/revocation/cleanup results only with Account. Keep pager errors alongside the matching channel/playlists/subscriptions. Disable repeat operations while active and preserve retry access for pending cleanup.
- Preserve confirmation wording and scope: revocation versus local sign-out; refresh preserves notes and playlist membership; local deletion includes retained originals, credentials and website data but does not change YouTube data. Do not dismiss or report success while deletion is pending.
- Keep Public playback foreground explanation and the existing Native opt-in confirmation. Add playback feedback only if the handed-off operation state warrants it; do not show a general global error here.
- An error snapshot taken from `failureMessage` before/after an action is not sufficient isolation: concurrent work can change it. Wait for scoped session state rather than implementing that workaround in UI.

## Session API requirements for coordinator

These names are proposals, not yet an agreed contract. Existing action methods may remain unchanged if they publish observable operation state.

| Consumer | Required state/semantics |
| --- | --- |
| Account | `accountOperation` with operation identity (sign-in, sign-out, revoke, cleanup), idle/running/success/failure, and optional readable message; observable busy state; cleanup failure remains visible when signed out. Existing `signedIn`, `oauthConfigured`, `accountCleanupPending`, channel/collection pagers remain usable. |
| Refresh details | `metadataRefreshOperation`, independent progress/success/failure; retain `refreshingMetadata` or expose equivalent running state. Handle playlist-title and video metadata refresh failures without accidentally reporting complete success. |
| Delete local data | `localDataDeletionOperation`, including running, failed-before-recording, pending-cleanup/restart, complete; preserve retry/recorded-deletion safeguards and expose the appropriate action availability. Existing `recoveryMessage` can serve as durable cleanup notice if its meaning is documented. |
| Playback settings | Existing `nativePlaybackAvailable`, `nativePlaybackEnabled`, `setNativePlayback`; any configuration failure must be scoped rather than inherited from player/search errors. |

Operation messages must reset only for the matching operation; search or playback must not overwrite/clear account, refresh or deletion feedback. Cancellation/account changes/deletion must invalidate late responses. The session stream owns these changes and unit tests in `PublicYouTubeFlowTests`. UI does not write session internals or clear global messages.

Also request a coordinator-confirmed way to test construction/network absence before consent. Preferred: gate eligibility unit coverage plus a local content-construction probe in a hosted UI test; no RootView edits by this stream. UI absence alone is evidence of navigation gating, not proof that no session/network service was constructed.

## Policy alignment

- Confirm the final Home is local recently played/playlists and optional authorized account playlists; document only the remote calls actually made.
- Keep precise embedding-status/Made for Kids behavior and foreground playback limitations. Describe transient versus persisted display metadata against final session persistence behavior.
- Keep optional read-only OAuth, Keychain, no developer-operated backend, revocation failure/cleanup retry, recovery-copy deletion and consent retention statements where supported.
- Update the resource version and `PublicPrivacyPolicy.version` together to the coordinator-confirmed `2026-09-29.1` when the approved changes are ready. Require resource version/header consistency in verification.
- Hosted policies and release candidate snapshots are outside this workstream's authorized files. Report the new bundled version to the coordinator; no publishing or editing archived candidates. Opening existing service links is not evidence of hosted-policy alignment.

## Test and verification handoff

Extend `PublicPrivacyUITests` for explicit opt-in, same-version relaunch, stale-version re-consent, full-policy round trip without acceptance, refusal/dismissal, missing/empty resource including previously accepted consent, and Settings policy access after consent. Fixture bypass must not bypass missing-policy protection. Any new DEBUG-only launch inputs require a UUID-isolated test suite and must not alter Release behavior. Agree checked then unchecked must disable Continue again.

Add dedicated Settings UI coverage for all destinations, displayed version/build, scoped operation feedback, retained deletion/revocation confirmation, refresh busy state and pending cleanup. Deterministic failure fixtures/state injection depend on the session handoff; use existing catalog fixtures where possible. Session tests must prove error isolation, late-response invalidation and deletion status semantics; do not replace them with UI text assertions alone.

Report new test filenames to Tests/CI ownership for explicit application test source allowlists. Keep app views in the owned existing files unless coordinator approves new source paths. Do not edit project manifests here.

After design/API approval: implement owned files; run relevant Public build/tests with unique DerivedData/results paths and reserved simulator; coordinate Native build coverage. Capture fresh first-launch, full policy, Settings and operation feedback screens. Inspect small screen, largest Dynamic Type, light/dark, Reduce Transparency, iOS 18 fallback and VoiceOver; report unavailable device/OS coverage accurately. No simulator or tests were run in this planning-only turn.

## Ready-to-start conditions

Coordinator supplies the completed design specification and scoped observable session API, plus fixture/testing hooks if needed. Consent dismissal behavior, the policy version and Native capability wording boundary are already confirmed above. Then implement this scope without additional user questions; report unresolved API or policy facts centrally. Until that handoff, wait without polling or scheduling follow-ups.
