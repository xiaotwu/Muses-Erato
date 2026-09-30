#!/usr/bin/env python3
"""Build/check the local static publication package. Never contacts or publishes remotely."""
import argparse
from html import escape
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "docs/site"
SOURCE = ROOT / "docs/site-content"
SECTIONS = {"Search and playback", "Optional sign-in", "Local information", "Upgrades and retention", "Your controls", "Support and changes"}
PAGES = {"index.html": "Muses-Erato", "terms.html": "Terms of use", "privacy.html": "Privacy policy"}
SUPPORT = "https://github.com/xiaotwu/Muses-Erato/issues"
CSS = """*{box-sizing:border-box}html{color-scheme:light}body{margin:0;background:#faf8f4;color:#272521;font:18px/1.65 system-ui,sans-serif}header,main,footer{max-width:780px;margin:auto;padding:24px}header{border-bottom:1px solid #ded9cf}nav{display:flex;flex-wrap:wrap;gap:12px 24px}a{color:#654a21;text-underline-offset:4px}a:focus-visible{outline:3px solid #654a21;outline-offset:4px}h1{font-size:clamp(2rem,6vw,3rem);line-height:1.15}h2{font-size:1.3rem;margin-top:2rem}.lead{font-size:1.3rem}li{margin-bottom:.5rem}footer{border-top:1px solid #ded9cf;font-size:.9rem}a[aria-current=page]{font-weight:700}.skip{position:absolute;left:-10000px}.skip:focus{left:16px;top:8px;background:white;padding:8px}p,li{overflow-wrap:anywhere}@media(max-width:420px){header,main,footer{padding:20px}}\n"""


def render_page(filename, title, content):
    navigation = "\n".join(
        f'<a href="{name}"' + (' aria-current="page"' if name == filename else '') + f'>{escape(label)}</a>'
        for name, label in PAGES.items()
    )
    return f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="referrer" content="strict-origin-when-cross-origin">
<title>{escape(title)} — Muses-Erato</title>
<link rel="stylesheet" href="styles.css">
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
<header><nav aria-label="Main navigation">{navigation}</nav></header>
<main id="main">
{content.strip()}
</main>
<footer><p>Developed by xiaotwu · <a href="{SUPPORT}">GitHub Issues support</a></p>
<nav aria-label="Provider information"><a href="https://www.youtube.com/t/terms">YouTube terms</a><a href="https://policies.google.com/privacy">Google privacy</a><a href="https://security.google.com/settings/security/permissions">Google account permissions</a></nav>
<p>Support issues are public. Do not post account details or credentials.</p></footer>
</body>
</html>
'''


def expected_files():
    policy = (ROOT / "Sources/Muses/Resources/PublicPrivacyPolicy.md").read_text(encoding="utf-8")
    blocks = []
    for index, paragraph in enumerate(policy.strip().split("\n\n")):
        if index == 0:
            title, *remaining = paragraph.split("\n", 1)
            title = title.removeprefix("# ")
            blocks.append(f"<h1>{escape(title)}</h1>")
            if remaining:
                blocks.append(f"<p>{escape(remaining[0])}</p>")
        elif paragraph.startswith("## ") and "\n" not in paragraph:
            blocks.append(f"<h2>{escape(paragraph.removeprefix('## '))}</h2>")
        else:
            tag = "h2" if paragraph in SECTIONS else "p"
            blocks.append(f"<{tag}>{escape(paragraph).replace(chr(10), '<br>')}</{tag}>")
    blocks.append('<section aria-label="Website information"><h2>About this website</h2><p>These pages contain no embedded player, analytics scripts or remote images. When hosted on GitHub Pages, GitHub handles website requests under its <a href="https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement">privacy statement</a>. Following an external link opens that provider\'s service.</p></section>')
    result = {"styles.css": CSS, ".nojekyll": ""}
    for filename, title in PAGES.items():
        content = "\n".join(blocks) if filename == "privacy.html" else (SOURCE / filename).read_text(encoding="utf-8")
        result[filename] = render_page(filename, title, content)
    return result


class PageAudit(HTMLParser):
    """Check the small static package's links, semantics and network-bearing elements."""
    allowed = {"html", "head", "meta", "title", "link", "body", "a", "header", "nav", "main", "footer", "section", "h1", "h2", "p", "ul", "li", "br"}
    void = {"meta", "link", "br"}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.links, self.ids, self.stack = [], set(), []
        self.h1 = self.main = 0

    def handle_starttag(self, tag, attributes):
        if tag not in self.allowed:
            raise ValueError(f"Unexpected/active element: {tag}")
        attrs = dict(attributes)
        if any(key.startswith("on") or key in {"src", "srcset", "style", "ping"} for key in attrs):
            raise ValueError(f"Unexpected active or resource attribute: {tag}")
        if tag == "meta" and "http-equiv" in attrs:
            raise ValueError("Unexpected HTTP-equivalent metadata")
        if tag == "html" and attrs.get("lang") != "en":
            raise ValueError("Missing document language")
        if tag == "link" and (attrs.get("rel"), attrs.get("href")) != ("stylesheet", "styles.css"):
            raise ValueError("Only the local stylesheet may load automatically")
        if "id" in attrs:
            if attrs["id"] in self.ids:
                raise ValueError("Duplicate element ID")
            self.ids.add(attrs["id"])
        if "href" in attrs:
            self.links.append(attrs["href"])
        self.h1 += tag == "h1"
        self.main += tag == "main"
        if tag not in self.void:
            self.stack.append(tag)

    def handle_endtag(self, tag):
        if not self.stack or self.stack.pop() != tag:
            raise ValueError(f"Unbalanced HTML at {tag}")


def validate(files):
    for filename in PAGES:
        parser = PageAudit()
        parser.feed(files[filename])
        parser.close()
        if parser.stack or parser.h1 != 1 or parser.main != 1:
            raise ValueError(f"{filename}: invalid heading/main structure")
        if not set(PAGES).issubset(parser.links) or SUPPORT not in parser.links:
            raise ValueError(f"{filename}: incomplete same-directory navigation/support")
        for link in parser.links:
            url = urlsplit(link)
            if url.scheme:
                if url.scheme != "https" or not url.netloc:
                    raise ValueError(f"{filename}: external link must use HTTPS")
            elif url.netloc or url.path.startswith("/") or (url.path and url.path not in files):
                raise ValueError(f"{filename}: unresolved or nonportable local link {link}")
            elif url.fragment and not url.path and url.fragment not in parser.ids:
                raise ValueError(f"{filename}: missing fragment {link}")
    if "url(" in files["styles.css"].lower() or "@import" in files["styles.css"].lower():
        raise ValueError("Stylesheet must not load additional resources")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate checked-in output without writing files")
    args = parser.parse_args()
    files = expected_files()
    validate(files)
    if args.check:
        for filename, content in files.items():
            path = DESTINATION / filename
            if not path.is_file() or path.read_text(encoding="utf-8") != content:
                raise SystemExit(f"Stale or missing {path.relative_to(ROOT)}; run the builder")
        print("PASS: 3 pages, local links, HTML structure, passive resources and policy parity; no remote checks.")
    else:
        DESTINATION.mkdir(parents=True, exist_ok=True)
        for filename, content in files.items():
            (DESTINATION / filename).write_text(content, encoding="utf-8")
        print("Prepared docs/site: homepage, terms, privacy, styles and .nojekyll. No publication performed.")


if __name__ == "__main__":
    main()
