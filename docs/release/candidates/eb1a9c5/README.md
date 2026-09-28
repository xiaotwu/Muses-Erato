# eb1a9c5 simplified Home candidate

Reviewed 2026-09-28. Clean guided UI branch, after fd7935c; not merged into P6. **NO GO** for public release.

## Latest decision and inspected source

User removed unreliable Music recommendation content and unavailable Artists/Albums category placeholders. Home now uses playlist-member Recently Played and On YouTube account playlists, retaining a website entry. Read the latest UI/NomaTune documents and root Home implementation: startup/refresh call loadAccountCollections when signed in; no recommendation model is instantiated by Home. Existing hero cards and playback adapters are unchanged.

Independent xcresult summaries: erato-home-simplified-tests 4/4 and erato-home-simplified-large-final 1/1 passed. The latter repeats the accessibility case after stacking headings/links, not a fifth distinct test. Original thread reports screenshot review, signed Debug build and in-place iPhone install/launch. No device action or live request was repeated here. User visual acceptance and production account playlists/background/lock-screen evidence remain separate.

## Earlier finding is dormant, not repaired

PublicMusicHomeService/Model and session readMusicHome remain in source, but source-reference tracing found no current Home instantiation/call into their browse path. The fd7935c request-side account-isolation finding therefore is not an active Home-path requirement for this candidate. Its underlying service ordering was not repaired; before any future reuse, require the pre-browse account-generation/cancellation guard and held-bootstrap test described in the [earlier review](../fd7935c/README.md). Do not characterize removal of the caller as a tested service fix.

## Final public cleanup and policy reconciliation remain required

The recommendation source is still part of project compilation. Previous cef269d public audit failure is historical; it does not prove that the new binary passes or fails after optimizer dead stripping. Inspect a fresh exact Release artifact and its composition/dependencies. Removing a visible view alone is not a final exclusion/signing/distribution gate. Existing native experiment remains excluded by configuration; physical/native/provider evidence gates still apply.

Bundle privacy text has not changed in eb1a9c5. Version 2026-09-28.2 and the cef269d draft still describe cloud Music Home requests and account Home clearing. Those paragraphs require reconciliation with the now-removed feature before publication/submission. Do not publish the prior recommendation draft unchanged or claim visitor/bearer recommendation traffic still occurs in the current Home. Retain accurate separate official account-playlist requests and external Music website processing. Agreement version and Google verification demo must match the final chosen processing. No policy/source edit in the candidate worktree occurred here.

P6 remains blocked by final public artifact/composition/policy evidence, Google production/domain verification, retained authorized IDs/recovery copies, provider privacy/ATT/App Privacy, and physical/background/user acceptance. No merge, push, deployment/upload or final release approval occurred.
