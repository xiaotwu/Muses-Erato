# GitHub static publication package

Prepared against integration `ebeedf4` on 2026-09-27. This package is local and reviewable; it has not been pushed, deployed or verified at a public URL. It does not close P6 or the privacy/retention/verification gates.

## Sources and reproducible output

| Output under `docs/site` | Source |
| --- | --- |
| `index.html` | [Homepage content](../site-content/index.html) and shared builder shell |
| `terms.html` | [Terms content](../site-content/terms.html) and shared builder shell |
| `privacy.html` | [Bundled app policy](../../Sources/Muses/Resources/PublicPrivacyPolicy.md), escaped without rewriting its text; separate website-hosting notice appended |
| `styles.css`, `.nojekyll` | [Builder](../../scripts/build-privacy-site.py) |

Run from the repository root:

```sh
python3 scripts/build-privacy-site.py
python3 scripts/build-privacy-site.py --check
```

The builder needs only Python's standard library and never contacts a network service. `--check` writes nothing: it checks reproducible output, policy parity, balanced supported HTML, one main heading/landmark per page, fragment targets, same-directory navigation, HTTPS external links and absence of active/remote embedded resources. It does not validate external URL availability, browser rendering, Google acceptance or every accessibility criterion. It checks five managed output files, not an arbitrary future deployment directory; inspect any added files before publication. Do not edit generated pages directly.

For local visual review, serve only the output folder:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory docs/site
```

Open the local homepage and inspect narrow/wide layouts, keyboard focus and all three pages; stop the server afterward. The site uses local CSS, system fonts, semantic navigation and no JavaScript, embedded player, forms, remote images or analytics. Ordinary links contact other providers only when followed. Static pages do not imply zero hosting-side processing: the privacy page links GitHub's hosting privacy statement separately from the app policy.

## Product claims and source boundary

The homepage describes implemented search/link opening, local library/favorites/playlists, queue/history, notes/time bookmarks and optional read-only Google account views. Playback is visible and foreground-only; no background audio, offline downloads, App Store availability, Google verification or tracking exemption is claimed. Source: [public app](../../Sources/Muses/App/PublicYouTubeApp.swift), [public views](../../Sources/Muses/Features/Public/PublicRootView.swift) and [IFrame adapter](../../Sources/Muses/Platform/iOS/YouTubeIFrame/YouTubeIFrameAdapter.swift) at the baseline.

The app policy is the single privacy text source. Baseline `ebeedf4` includes live-data persistence sanitization and durable deletion work beyond the historical inventory snapshot. Their presence is not proof that all legacy archive provenance/retention gates are closed. The terms describe recovery-copy limits consistently with that bundled policy. Before publication, owner/integration review must approve the terms and verify final behavior against the policy, including all app-owned copies and failure/restart paths. Change the policy version consistently when practices change; rebuilding HTML alone does not update the in-app agreement version.

## Publish-root decision (owner action, not performed)

All page links are relative, so the same output works at a project path or a custom-domain root. If `docs/site` is deployed as the site artifact root, candidate URLs are:

| Consent/store field | Candidate only, not checked live |
| --- | --- |
| Homepage | `https://xiaotwu.github.io/Muses-Erato/` |
| Privacy policy | `https://xiaotwu.github.io/Muses-Erato/privacy.html` |
| Terms | `https://xiaotwu.github.io/Muses-Erato/terms.html` |
| Public support | `https://github.com/xiaotwu/Muses-Erato/issues` |

GitHub's branch publishing selector supports repository root or `/docs`, **not `/docs/site`**. To obtain the candidate paths, the owner must later choose an approved Actions artifact containing the contents of `docs/site`, or place those contents at the root of a dedicated publishing branch. Selecting `/docs` directly would yield a different path and may expose unrelated release documents. No workflow or publishing branch is added here. See [GitHub publishing sources](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site).

After explicit publication authorization, owner configures the selected source/domain and deploys only the approved artifact. Verify actual anonymous HTTPS responses, redirects, page content/version, same-domain links and provider/support links before copying URLs into Google/ASC. Retain the deployed commit and timestamped checks. An Issues support URL is the selected public contact route; it does not replace the required Google support email, Google developer-contact addresses or Apple's private review contact. See [platform/domain checklist](privacy-domain-check.md).

## Google Search Console proof: owner runbook

1. Choose the actual hostname before configuring consent URLs. For the candidate Pages host, `xiaotwu.github.io` is the candidate top private domain, subject to Google acceptance; repository ownership or a project-path prefix is not proof of host-wide ownership. `github.com` blob links do not solve this requirement. Google's [brand verification instructions](https://developers.google.com/identity/protocols/oauth2/production-readiness/brand-verification) require the relevant ownership relationship to the Cloud project.
2. Sign in privately with an appropriate project-associated Google account. Add the correctly scoped Search Console property. A custom-domain Domain property requires DNS proof. For the `github.io` host, consider an HTTPS URL-prefix property at the host root and a method offered by Google; confirm this scope satisfies OAuth authorized-domain verification. A proof at `/Muses-Erato/` alone must not be presented as proof of the entire host.
3. Obtain the **actual** HTML verification file/tag or DNS record from Search Console. No token, verification meta tag, DNS record, CNAME or purported verified status is fabricated in this package. A root HTML file belongs at the exact public URL Google specifies. A project artifact mounted under `/Muses-Erato/` cannot alone serve a host-root verification file; owner may need the separate user Pages site or an owned custom domain. Confirm ownership/control before changing another site.
4. For file verification, preserve Google's filename and content and keep the file in the publication source across future deployments. The builder only writes its five managed files and will not erase an additional owner-supplied file; `--check` does not certify that file. For meta verification, place the authentic tag in the appropriate homepage's `<head>` through its maintained source, not a generated page that the next build replaces. DNS proof belongs in the owner's DNS provider. Do not add analytics solely to obtain verification.
5. After separately authorized deployment, confirm unauthenticated access at the required location, complete Verify in Search Console, and retain the proof. Record property scope, verification status, associated Cloud role and the actual Auth Platform authorized-domain acceptance in a redacted release record. Then separately complete branding and scope verification. Search Console verification is not OAuth approval.

The proof types, exact-file requirements and ongoing token retention follow [Search Console ownership documentation](https://support.google.com/webmasters/answer/9008080?hl=en). If using a custom domain with Pages, [GitHub's domain verification](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/verifying-your-custom-domain-for-github-pages) is another independent step; its DNS challenge does not replace Google's.

## Required acceptance before release

- Final policy/terms reflect demonstrated local deletion, metadata persistence and legacy recovery retention. Resolve P6-ARCHIVE; do not rely on the word “archive” as an exemption.
- Owner approves terms/publication, establishes hosting/domain proof and checks real URLs. No live status is established here.
- Owner supplies platform contact fields privately, completes OAuth production/scope approval and verifies corrected API-key restrictions.
- Complete [embedded-player privacy/ATT evidence](youtube-embed-privacy-review.md), App Privacy declarations and final archived-build checks. A static-site check is not app privacy approval.

## Follow-up: selected host and prepared deployment

The owner selected `xiaotwu.github.io` on 2026-09-27. [The deployment plan](pages-deployment-plan.md) records actual 404 observations, the new manual project Pages workflow and the passive separate host-root homepage. This supersedes the earlier statement that no workflow is prepared; neither artifact has been pushed/deployed and no root verification token exists. Policy and terms now use version `2026-09-27.2` to reflect content-status checks; retention/provider reconciliation remains open before public publication.

## Family migration — 2026-09-30

Project-Muses is now the sole website publication repository. The former Erato Pages workflow is removed. Reviewed local output from `scripts/build-privacy-site.py` is mirrored into the parent `docs/ios/` via `scripts/sync-site-assets.py`; run its `--check` parity gate before publishing. URLs are `https://xiaotwu.github.io/Project-Muses/ios/`, `.../ios/privacy.html` and `.../ios/terms.html`. Historical `/Muses-Erato/` deployment instructions above are superseded. Google Cloud consent URLs, App Store Connect metadata and host ownership verification must be updated separately; moving source does not change those service settings or certify verification.
