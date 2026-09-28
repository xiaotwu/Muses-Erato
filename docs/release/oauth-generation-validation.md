# OAuth late-response and deletion validation

Date: 2026-09-27. Baseline `7065a17`. This follow-up repairs concrete in-process OAuth races; it does not close retained-identifier, durable cleanup, Google verification or P6 gates.

## Defects found in the baseline

`OAuthClient` is an actor, but its token/remote/cache requests suspend actor execution. The baseline could save a refresh or authorization-code result after local deletion/revocation, and could let an older `invalid_grant` delete a newly completed login. Account replacement also suspends during private-cache deletion before saving new credentials. The session invalidated displayed account pages on sign-out, but token-store writes had no equivalent generation protection.

## Implemented controls

- An account generation is captured before requests and validated after responses and after account-replacement cache cleanup. Deletion and new exchange advance that generation. Stale results cannot write credentials or trigger cleanup of a newer account.
- Each account generation shares one outstanding refresh request; concurrent callers cannot separately rotate the same grant. Caller cancellation is checked before using or saving a result. Deletion cancels the shared request and invalidates every waiter even when a transport does not honor cancellation.
- A deletion-operation count blocks token use and authorization-code completion during both local and remote cleanup. The in-memory invalidation flag continues blocking reuse when Keychain removal throws. Only a successfully completed new user login clears it.
- Existing all-attempts cleanup/error reporting remains: token-store errors do not skip private-cache deletion, storage errors remain distinguishable, and remote failure does not skip local cleanup.
- The public session serializes sign-out and cancels its browser/active sign-in task. Sign-in cannot start while that session's sign-out is unfinished.

## Deterministic verification

`swift test --package-path Platform/iOS/OAuth` passes **14 tests**, log `/tmp/erato-oauth-generation-tests-final.log`. The existing five tests preserve PKCE/state, ordinary exchange/revoke, remote-failure cleanup and Keychain/cache failure combinations. New tests hold responses or private cleanup with continuations and explicitly release them after the competing action:

| Test | Verified outcome |
| --- | --- |
| `testLateRefreshCannotRestoreTokensAfterLocalDeletionOrRevoke` | Delayed successful refresh after either deletion path returns revoked and leaves the store empty. |
| `testLateRevokedRefreshCannotDeleteNewLogin` | Old invalid-grant response cannot erase the new credentials or prevent their subsequent use. |
| `testLateExchangeAfterDeletionCannotCreateCredentials` | A late authorization-code result cannot repopulate deleted credentials. |
| `testPendingRemoteRevokeBlocksTokenUseAndNewExchange` | Existing credentials and new completion are unavailable during revoke; a fresh login after cleanup remains supported. |
| `testCancelledRefreshCannotSaveResponse` | Cancelled caller does not save a late successful response. |
| `testFailedTokenDeletionStillBlocksReuseInCurrentClient` | Reported Keychain deletion failure cannot silently make surviving credentials usable in that client. |
| `testConcurrentRefreshUsesOneProviderRequest` | Concurrent reads share one provider refresh and both receive the resulting access token. |
| `testNewLoginRetriesFailedCacheCleanupEvenWhenTokensWereDeleted` | A new login retries earlier failed cache cleanup before saving credentials, even if the previous token deletion succeeded. |
| `testDeletionDuringAccountReplacementCacheCleanupBlocksTokenSave` | Deletion during the second exchange suspension prevents the final save. |

Mocks exercise actor ordering and failure outcomes, not Google-account revocation, locked physical Keychain behavior or forensic erasure. No new credential material was read, no policy version changed, and no website/Cloud/ASC changes occurred in this follow-up.

## Remaining boundaries

The generation/invalidation state is **in memory**. A restart after failed Keychain deletion can still reload surviving credentials unless a durable cleanup marker is added; sign-out currently has no full-wipe-equivalent tombstone. Durable retry/startup gating remains required. Likewise retained remote playlist/video identifiers and authorized import membership are not deleted by this package fix; archive classification/retirement remains open.

Google may already have processed an in-flight request before cancellation. Discarding a local response is not evidence that Google revoked every grant or deleted provider-side data; account permission review and production revocation acceptance remain separate. [Developer Policies III.D.3 and III.E.4](https://developers.google.com/youtube/terms/developer-policies) require authorized-data deletion and token-validity/retention controls. This fix only prevents the named local resurrection/account-replacement races.

The phone still has the earlier `7065a17` content-status build. No new physical install or acceptance is claimed by this follow-up. The historical 79eff2e IPA remains unsuitable for the changed source. Final Release evidence is recorded in implementation-status.md; no archive/export/upload is inferred.
