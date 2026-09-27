#!/usr/bin/env python3
"""Create a private xcconfig from owner-supplied files without printing credentials."""
import argparse
import os
from pathlib import Path
import plistlib
import re
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--oauth-plist", type=Path, required=True)
parser.add_argument("--api-key-file", type=Path)
parser.add_argument("--development-team")
parser.add_argument("--output", type=Path, default=Path.home() / ".config/muses-erato/Local.xcconfig")
args = parser.parse_args()
with args.oauth_plist.expanduser().open("rb") as source:
    oauth = plistlib.load(source)
if oauth.get("BUNDLE_ID") != "com.xiaotwu.muses.erato":
    raise SystemExit("OAuth Bundle ID does not match the app.")
client = oauth.get("CLIENT_ID", "")
scheme = oauth.get("REVERSED_CLIENT_ID", "")
if not re.fullmatch(r"[A-Za-z0-9._-]+\.apps\.googleusercontent\.com", client):
    raise SystemExit("Invalid Google iOS client ID (value hidden).")
if not re.fullmatch(r"com\.googleusercontent\.apps\.[A-Za-z0-9._-]+", scheme):
    raise SystemExit("Invalid Google callback scheme (value hidden).")
lines = ["// Private local configuration. Do not commit this file.",
         "MUSES_GOOGLE_IOS_CLIENT_ID = " + client,
         "MUSES_GOOGLE_REDIRECT_SCHEME = " + scheme]
if args.api_key_file:
    keys = re.findall(r"AIza[0-9A-Za-z_-]{35}", args.api_key_file.expanduser().read_text())
    if len(keys) != 1:
        raise SystemExit("Expected exactly one API key (values hidden).")
    lines.append("MUSES_YOUTUBE_API_KEY = " + keys[0])
if args.development_team:
    if not re.fullmatch(r"[A-Z0-9]{10}", args.development_team):
        raise SystemExit("Invalid Apple development team ID.")
    lines.extend(["DEVELOPMENT_TEAM = " + args.development_team, "CODE_SIGN_STYLE = Automatic"])
output = args.output.expanduser().resolve()
# Keep owner credentials outside every checkout, even if a caller selects a custom path.
repo = Path(__file__).resolve().parent.parent
if output == repo or repo in output.parents:
    raise SystemExit("Choose a configuration path outside the repository.")
output.parent.mkdir(parents=True, exist_ok=True)
fd, temporary = tempfile.mkstemp(dir=output.parent, prefix=".google-config-")
try:
    with os.fdopen(fd, "w") as destination:
        destination.write("\n".join(lines) + "\n")
    os.chmod(temporary, 0o600)
    os.replace(temporary, output)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
print("Prepared private local configuration at " + str(output) + "; credential values hidden.")
