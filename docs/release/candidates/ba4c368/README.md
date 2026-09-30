# ba4c368 Music Home candidate — unpublished privacy review draft

Source candidate: `ba4c368` on `codex/erato-guided-ui`, after `5152957`. Reviewed 2026-09-28. It is not merged into the P6 branch. **NO GO** for public release.

## Source changes and evidence boundaries

The candidate changes Library scope to the distinct local-playlist membership union, with Favorites/History intersections; uses channel nickname/avatar in Account; and adds `PublicMusicHomeService`. This service requests `https://music.youtube.com/` for client-version bootstrap and POSTs `https://music.youtube.com/youtubei/v1/browse?prettyPrint=false` with `FEmusic_home`. For a signed-in attempt, `readMusicHome` obtains the existing OAuth access token and sends a bearer header directly to that endpoint. This is not the official Data API route and is outside its existing quota accounting.

An ephemeral URLSession disables cookie acceptance. Account requests use the session's account epoch and outstanding-operation accounting; stale scopes are rejected before publishing. Normalized Home results are cached in view-model memory for five minutes. A `logged_in=1` response signal gates the personalized label; HTTP 200, configured OAuth and DEBUG fixtures cannot establish real account recommendations. The original thread reports only a guest live probe (HTTP 200, two carousels, logged_in=0), two unit tests and five distinct relevant UI passes across runs. Those reports do not establish production authorization or personalized Home. Intermediate Simulator Busy recovery is not acceptance evidence by itself.

The response byte check occurs **after** URLSession has received the response. An 8 MB acceptance check is not a streaming transfer/memory cap; include transport limits/error behavior in final engineering assessment. The bootstrap retains a fixed fallback client version when extraction fails; undocumented-version changes and endpoint availability need an explicit supported-path decision. Neither issue is repaired by this documentation packet.

## Public-composition gate reopened

The existing `scripts/audit-public-artifact.py` denies `youtubei/v1` in the app binary. The candidate's endpoint string conflicts with that frozen public-artifact gate. Earlier official-only static/build passes apply to their named source versions, **not this candidate**. Do not remove the audit restriction merely to make the candidate pass. Decide and document the supported distribution/composition, endpoint authorization and applicable account-permission evidence before changing public routing/contracts or claiming release readiness. User preference for Music recommendations or IPA/TestFlight does not establish those facts.

Playback remains the visible official adapter. No native stream extraction/background path was added. Real account Home, UI acceptance, background feasibility, provider privacy/ATT/App Privacy, retained authorized identifiers/recovery copies, OAuth production verification/domain/quota and final distribution acceptance remain open.

## Prepared static draft

- `PublicPrivacyPolicy.md` is frozen from `git show ba4c368:Sources/Muses/Resources/PublicPrivacyPolicy.md`, version `2026-09-28.1`, with Home processing and separate local-sign-out/revoke wording.
- `site/privacy.html` renders that policy using the existing passive builder with Home recommendations added to the heading set. `site/index.html` and `site/terms.html` are explicitly labeled candidate review drafts, replacing the earlier official-only feature claim. `styles.css` and `.nojekyll` complete the local preview.
- Existing builder `validate` passed for all five site files; checked the policy version, Home heading and escaped Home processing paragraph. No network/publication was performed. The default `docs/site`, bundled policy and builder in this P6 branch still match its unmerged product baseline.
- These files are outside the existing deployment workflow's `docs/site` artifact. They are **not approved for deployment**. After the final candidate/composition is accepted, reconcile source policy, agreement version, builder section set, homepage, terms, Google verification demo/scope explanation and App Privacy answers together, then regenerate the actual deployment artifact. Do not submit the old verification packet as if the Home bearer route were absent.

No private token, account response, browser cookie or personal contact is included. No push, deployment, upload, final archive or independent device action occurred here. The original thread is handling installation and concentrated actual-device feedback.
