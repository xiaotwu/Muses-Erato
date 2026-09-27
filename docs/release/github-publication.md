# GitHub support and privacy publication

The owner selected GitHub for public support and documentation. Issues are enabled;
Discussions are currently disabled. Support URL: https://github.com/xiaotwu/Muses-Erato/issues.
Use public issues only for redacted questions and app behavior, not account data.

The app's bundled policy is the source at `Sources/Muses/Resources/PublicPrivacyPolicy.md`.
Run `python3 scripts/build-privacy-site.py` to prepare `docs/site/privacy.html` for
GitHub Pages. The generated HTML includes provider and support links, has no third-party
scripts/images, and does not publish itself. Keep the app policy version and rendered
page synchronized whenever practices change.

## Publication gate

Before publishing, verify the final build implements the policy: metadata expiry,
Keychain/cache revocation, website-data cleanup, migration/recovery deletion, pending
cleanup errors and the pre-feature agreement gate. Reconcile App Privacy and Google
OAuth consent declarations. The policy draft worksheet is not the user-facing page.

After final review, push the reviewed branch and publish `docs/site` through GitHub
Pages. Confirm the actual public URL returns the expected policy and remains accessible
without login; then use that URL in App Store Connect and Google consent configuration.
Do not claim `https://xiaotwu.github.io/Muses-Erato/privacy.html` is active until Pages
configuration and an HTTP check confirm it. Google's domain verification and developer
contact requirements remain separate platform checks; a public Issues URL does not
automatically satisfy them.

No Pages deployment, Discussions enablement, remote configuration or store submission
has been performed by this preparation step.
