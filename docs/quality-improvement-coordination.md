# Quality improvement coordination

User authorization (2026-09-29): design and implement first-launch privacy, Home, Library, Search and Settings improvements; remove Podcasts; fix Public regression tests/CI, independent favorites/history, playback/network recovery and gradually split session responsibilities. Discuss design and integrate in the coordinating chat. Separate local Codex chats share this checkout. Do not publish, upload or change external accounts.

## Confirmed design

Home is content first (explicit user selection): recently played and playlists when populated; search, open link and import actions when empty. Preserve gold accents, native system content surfaces and Home/Search/Library tabs. Use native Liquid Glass for presentation and controls on iOS 26+, with iOS 18–25 and accessibility fallbacks. Do not turn every content card into glass.

First launch is a concise modal introduction with an accurate foreground-playback summary, complete policy/YouTube terms links and explicit versioned consent before constructing network/session services. Complete policy is accessible in Settings > Privacy. Handle missing policy, refusal/dismissal, large text and changed policy versions. Preserve cleanup protections.

Library: all saved videos, playlists, independent favorites and independent confirmed playback history. Remove duplicate Songs navigation and unsupported Podcasts; preserve legacy model compatibility and scoped deletion semantics. Persist display preference. Search: explicit initial/loading/results/empty/error states, actionable recovery and local result provenance. Settings: retain useful groups, add build/version and readable Privacy, use operation-specific feedback.

## File ownership

| Workstream | Owned files | Boundary |
| --- | --- | --- |
| Design | docs/quality-ui-design.md | Read-only app inspection |
| Tests/CI | project.yml, project-public.yml, test composition, .github/workflows quality workflow | No production UI/session/network edits |
| Networking | Packages/MusesNetworking and its tests | Backwards-compatible budget injection; session integration belongs to session stream |
| Session/library/playback | PublicYouTubeApp.swift, new session/controller files, required domain/queue/persistence files, PublicYouTubeFlowTests | No UI/project manifest edits; report new source paths |
| Privacy/Settings UI | PublicPrivacyView.swift, PublicSettingsViews.swift, PublicServiceLinks.swift, policy resource, privacy/settings tests | No RootView/session/project edits |
| Home/Library/Search UI | PublicRootView.swift, PublicHomeContent.swift, PublicLibraryHeroViews.swift, PublicCollectionDeck.swift, PublicCatalogViews.swift, corresponding UI tests | No session/privacy/settings/project edits |

Do not commit unless the coordinator requests it. Never reset, stash or overwrite shared edits. New filenames must be unique. Use unique DerivedData/results paths; reserve simulator ownership before UI runs. Adapt outdated test expectations to the approved behavior without discarding meaningful coverage. Send API requirements through written handoff notes for coordinator integration.

## Acceptance

Confirm a concrete design specification before visual implementation. Integrate and run package tests plus Public/Native builds and regression tests. Verify first launch; populated/empty Home and Library; favorites/history across relaunch; Search failures; Settings/Privacy; playback retry; scoped deletion. Capture current screenshots and report accessibility/device limits. Coordinator reconciles APIs and exact source allowlists.

Reference review: docs/project-quality-review-2026-09-29.md. Design reference screenshots: .artifacts/quality-review-2026-09-29/screenshots. These are not evidence of the changed app.

## Working chats

- Design: 01a0efed-a998-7e92-9749-0ae6d4c4e9e7
- Tests/CI: 01a0efed-e94b-7692-ace3-bd3cd12a0880
- Networking: 01a0efee-2cb1-7393-abcb-e2fdd6c4cb2b
- Session/library/playback: 01a0efee-6c70-79b0-98fe-768aba6610b9
- Privacy/Settings: 01a0efee-b023-7531-8ab6-fe7ca4dd492a
- Home/Library/Search: 01a0efee-f7d6-7fe0-ae4d-d2fc7a2b4c00

Main UI audit simulator 46441BA0-866C-4A6B-91D2-7547AC7CC613 is reserved for coordinator final QA. Other chats should use a dedicated simulator or compile/package verification.
