# cef269d Native experiment and public Release assessment

Reviewed 2026-09-28, candidate branch codex/erato-guided-ui, after ba4c368. Not merged into P6. **NO GO** for public release.

## Source and configuration boundaries

Read docs/native-audio-and-confirmation-acceptance.md, project.yml and ExperimentalNativePlayback.swift. Debug/Native define MUSES_NATIVE_PLAYBACK and use Info-Native.plist with audio background mode. Release uses ordinary Info.plist without that condition. Resolver call/import is conditional; the nonnative method throws. YouTubeKit is pinned to 0.4.9; local resolution sets useOAuth and allowOAuthCache false. No OAuth bearer is passed into the resolver. Source implements AVPlayer, audio session and lock-screen/system commands for the experiment. These findings do not establish physical behavior or provider/public-distribution authorization.

YouTubeKit remains a target dependency in project.yml, including Release. Conditional call exclusion does not independently prove that every dependency resource/endpoint is absent from a final distribution binary. Final artifact inspection remains required. No project, dependency, audit or UI source changes were made here.

## Observed public audit failure

Applied the integration branch's existing audit-public-artifact.py to the candidate's reported Release simulator build at /tmp/erato-public-release-build/Build/Products/Release-iphonesimulator/Muses.app. Log: /tmp/erato-cef269d-release-audit.log. Checks passed through innertubeclient exclusion, then **failed executable excludes youtubei/v1**. The Music Home composition gate is observed in a loose Release app. This is not a signed distribution IPA or independently rebuilt source/artifact provenance proof. Audit stops at first failure; later exclusions are not claimed to pass. The audit was not weakened.

## Evidence and outstanding acceptance

The original thread reports Native signed optimized/Release simulator build success, fixture/control tests and successful device update/launch. User will test later. Audible native streams, background/lock-screen continuity, remote controls/automatic next, interruption/headphone handling, actual account Home and design acceptance remain pending. No public submission, TestFlight approval or IPA delivery approval follows from a configuration named Native. Signing/export/device eligibility and distribution/provider evidence must be resolved for delivery.

CatalogItem.channelTitle is optional for old JSON compatibility. Creator display/hydration is API-derived metadata, not a resolved artist-credit/retention classification. Library/import/delete/sync confirmations and artwork remain candidate UI work, not independently accepted here.

## Unpublished privacy draft

PublicPrivacyPolicy.md is frozen from git show cef269d:Sources/Muses/Resources/PublicPrivacyPolicy.md, version 2026-09-28.2. Passive site preview renders the experimental background section and prior Music Home/sign-out/revoke descriptions; homepage/terms explicitly identify candidate versus public Release. Passive validation and version/heading checks passed after correcting the local draft heading selector. These isolated files are outside default docs/site deployment; they are unapproved drafts.

The earlier [Music Home assessment](../ba4c368/README.md) remains applicable: undocumented endpoint/account authorization, OAuth verification packet, retention/recovery and provider/ATT/App Privacy gates are unresolved. Reconcile final composition/policies before actual deployment regeneration. No credentials, real account responses or cookies are included; no upload/publication/device action was performed here.
