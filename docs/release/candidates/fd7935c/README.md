# fd7935c Home/Library candidate review

Reviewed 2026-09-28. Clean guided UI branch, following 139b122; not merged into P6. **NO GO** for public release.

## Checked changes and evidence

Read docs/nomatune-home-adaptation.md and Music Home source. Candidate adds the compact Library count-row Cards/List selector, featured/keep-listening/quick-pick/recent/playlist Home shelves, explicit page continuation and memory-only server visitor context. Native playback engine unchanged. No Android backend is integrated. Reference-source/license review is reported by the UI owner; this P6 check does not independently certify source/license provenance.

Independently read xcresult summaries: erato-home-layout-final-tests 5/5, erato-home-continuation-live 1/1 and erato-home-caption-final 1/1 passed with zero failures. The original thread reports an anonymous first-party browse of two initial shelves plus three subsequent shelves, normal/accessibility screenshot review, Debug/Release builds and device install/launch. Anonymous pagination is not account-personalization, audible/background/lock-screen or final user visual acceptance. No live tests or repeat installation were triggered here.

## Source-review finding: request-side account isolation

PublicMusicHomeService.fetch captures contextTicket before awaiting the website bootstrap, but only checks contextTicket against contextGeneration **after the browse response**. After bootstrap resumes, it reads shared visitorData to construct a request while retaining its original accessToken argument. The view model resets visitor context on account-scope change, and a newer fetch may populate that context while the older fetch is suspended.

This is a potential actor-reentrancy gap: an old fetch resuming after scope change can send its old bearer alongside the newer scope's visitor context before the post-response guard rejects it. No actual cross-account provider request was observed or captured; this finding is source-ordering evidence, not a reproduced leak. Response/UI generation guards do not by themselves prove request-side isolation.

Required candidate repair/verification: validate context generation and cancellation after bootstrap and immediately before constructing/sending browse, capture the context for that scope, and test a held bootstrap spanning scope reset/new account response. Assert that the obsolete operation sends no subsequent browse and does not use the newer visitor context. Requests already sent before scope change remain a separate in-flight provider boundary. UI/service ownership remains with the original thread; no candidate files were edited here.

## Privacy and public-release boundary

Server visitor context is received in responseContext and transmitted as client.visitorData on subsequent browse; page continuation is also returned and resent. Cookie rejection and no disk persistence do not mean no provider-issued context or identifier exchange. Final provider data/identifier/linkage/retention assessment and policy/App Privacy review must include this actual flow; no ATT conclusion follows solely from these fields. Bundle policy is unchanged (2026-09-28.2) in this commit. The [cef269d draft](../cef269d/README.md) matches policy text but requires reconciliation with final visitor-context behavior before publication.

Music Home remains the undocumented youtubei/v1 path. Prior public audit failure and endpoint/account authorization gates remain open; a new Release build is not a passing audit/distribution result. Native physical/background and user-failing-track acceptance, retained-data/recovery, Google/domain verification and final release gates remain open. No merge, publication, upload or P6 GO occurred.
