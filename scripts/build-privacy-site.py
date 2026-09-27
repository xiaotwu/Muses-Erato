#!/usr/bin/env python3
"""Render the bundled policy for repository-managed hosting; does not publish."""
from pathlib import Path
from html import escape

root = Path(__file__).resolve().parents[1]
policy = (root / "Sources/Muses/Resources/PublicPrivacyPolicy.md").read_text()
sections = {"Search and playback", "Optional sign-in", "Local information", "Upgrades and retention", "Your controls", "Support and changes"}
blocks = []
for index, paragraph in enumerate(policy.strip().split("\n\n")):
    tag = "h1" if index == 0 else "h2" if paragraph in sections else "p"
    blocks.append(f"<{tag}>{escape(paragraph).replace(chr(10), '<br>')}</{tag}>")
links = {
    "GitHub support": "https://github.com/xiaotwu/Muses-Erato/issues",
    "YouTube terms": "https://www.youtube.com/t/terms",
    "Google privacy": "https://policies.google.com/privacy",
    "Google account permissions": "https://security.google.com/settings/security/permissions",
}
navigation = " · ".join(f'<a href="{url}">{label}</a>' for label, url in links.items())
page = '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Muses-Erato privacy policy</title><style>body{font:18px/1.65 system-ui,sans-serif;max-width:780px;margin:auto;padding:28px;color:#242424}h1{font-size:1.8rem}h2{font-size:1.3rem;margin-top:2rem}a{color:#725124}nav{line-height:2}</style></head><body><main>' + "\n".join(blocks) + f'</main><nav aria-label="Support and provider information">{navigation}</nav></body></html>\n'
destination = root / "docs/site"
destination.mkdir(parents=True, exist_ok=True)
(destination / "privacy.html").write_text(page)
(destination / ".nojekyll").touch()
print("Prepared docs/site/privacy.html; no remote publication performed.")
