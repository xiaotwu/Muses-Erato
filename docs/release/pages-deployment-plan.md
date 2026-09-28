# Selected Pages host and deployment plan

Owner choice: **xiaotwu.github.io**, confirmed in this chat on 2026-09-27. This selects the host; it does not certify Google ownership or authorize unresolved policy claims. Prepared locally, not deployed.

## Reviewable artifacts

- `.github/workflows/publish-policy-site.yml` is manual (`workflow_dispatch`) only. It checks reproducible site output, rejects extra files/symlinks, uploads **only `docs/site`**, and deploys through `github-pages` with minimal job permissions. It follows [GitHub's custom workflow requirements](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages). No automatic push trigger or Cloud change exists. The workflow must reach the default branch, Pages must use Actions, and environment protections must permit the approved deployment before it can run.
- `docs/host-root/index.html` is a passive starter homepage for a separately approved **xiaotwu/xiaotwu.github.io** user-site repository. Copy this file to that repository's root, not the Muses-Erato project artifact. It links the project's homepage/privacy/terms and Issues. Its links will be unavailable until both deployments exist. It has no verification token, script, remote media or analytics.
- Project homepage: `https://xiaotwu.github.io/Muses-Erato/`; privacy: `/Muses-Erato/privacy.html`; terms: `/Muses-Erato/terms.html`. These are selected candidate paths, not live evidence.

## Read-only observations (2026-09-27)

The repository API confirms Muses-Erato is public, default branch `main`, and the authenticated user has admin access. `GET repos/xiaotwu/Muses-Erato/pages` returned 404; no configured Pages site was established by that read. `GET repos/xiaotwu/xiaotwu.github.io` returned 404, so no accessible host-root repository was found. Anonymous HTTPS probes of both `https://xiaotwu.github.io/` and the project homepage returned **404**. No repository, Pages setting, DNS record, deployment or public page was created by these checks.

## Required owner / Google steps

1. Review final policies after retained-ID, legacy-copy and embedded-provider decisions. Deployment is the final publication step after that reconciliation; keep draft claims local until reviewed.
2. Prepare the user-site repository/Pages root and the project's Actions source after publication approval. The project site cannot host a Google proof at the host root. Creating that separate public repository is a distinct publication action, not something the local starter file has performed.
3. In Search Console with the project-associated Google owner/editor account, add the appropriately scoped **HTTPS URL-prefix property `https://xiaotwu.github.io/`** and obtain an actual offered HTML verification file or tag. DNS verification of `github.io` is outside repository-owner control. A proof scoped only to `/Muses-Erato/` must not be presented as host ownership.
4. If Google offers file verification, place its exact filename/content at the user-site root and retain it in future releases. If it offers a meta tag, insert the authentic tag into the maintained root homepage head. Do not fabricate proof or substitute another account's token. The proof is intended to be publicly served; passwords, OAuth tokens, verification codes and private contact details are never needed.
5. Verify the exact public proof URL and homepage anonymously, complete Search Console verification, then confirm Auth Platform accepts `xiaotwu.github.io` as the relevant authorized domain. Retain a redacted status/scope record. If Google rejects this host/scope, resolve the supported ownership route with Google before claiming success.
6. Separately publish branding, record readonly scope classification, record the English consent/feature demo, submit data-access verification and confirm approval. Audience production status alone cannot replace approval. Platform contact fields are filled privately in Google/ASC.

Sources: [Google brand verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/brand-verification), [Search Console ownership methods](https://support.google.com/webmasters/answer/9008080?hl=en), and the existing [verification packet](google-oauth-verification-packet.md). Host verification and public hosting do not close provider privacy, retention, TestFlight or App Review gates.
