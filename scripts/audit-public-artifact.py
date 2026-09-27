#!/usr/bin/env python3
"""Fail closed on public-build capabilities and known inherited media routes.

Usage: audit-public-artifact.py path/to/Muses.app
Run against the .app inside the final archive, not just a build directory.
"""

import pathlib
import plistlib
import subprocess
import sys


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")
    print(f"PASS: {message}")


if len(sys.argv) != 2:
    raise SystemExit("usage: audit-public-artifact.py path/to/Muses.app")

app = pathlib.Path(sys.argv[1]).resolve()
info = plistlib.loads((app / "Info.plist").read_bytes())
binary = app / info["CFBundleExecutable"]
require(binary.is_file(), "main executable exists")
require(info.get("CFBundlePackageType") == "APPL", "artifact is an app")
require(not info.get("UIBackgroundModes"), "no background modes")
require(not info.get("NSSupportsLiveActivities"), "no Live Activities declaration")
require("CarPlay" not in str(info.get("UIApplicationSceneManifest", {})), "no CarPlay scene")
require(not (app / "PlugIns").exists(), "no widget or other extension")
require(not (app / "Watch").exists(), "no Watch app")
require((app / "PublicPrivacyPolicy.md").is_file(), "user-facing privacy policy is bundled")
privacy_path = app / "PrivacyInfo.xcprivacy"
require(privacy_path.is_file(), "privacy accessed-API manifest is bundled")
privacy = plistlib.loads(privacy_path.read_bytes())
reasons = {entry["NSPrivacyAccessedAPIType"]: entry["NSPrivacyAccessedAPITypeReasons"]
           for entry in privacy.get("NSPrivacyAccessedAPITypes", [])}
require("CA92.1" in reasons.get("NSPrivacyAccessedAPICategoryUserDefaults", []),
        "own-app UserDefaults access reason is declared")

signed = subprocess.run(["codesign", "-d", "--entitlements", ":-", str(app)],
                        capture_output=True, check=False)
if signed.returncode == 0 and signed.stdout:
    entitlements = plistlib.loads(signed.stdout)
    require(not any("carplay" in key.lower() for key in entitlements), "no CarPlay entitlement")
    require("com.apple.security.application-groups" not in entitlements, "no App Group entitlement")
else:
    print("UNVERIFIED: unsigned artifact; inspect entitlements on final signed archive")

text = subprocess.run(["strings", "-a", str(binary)], capture_output=True, text=True,
                      check=True).stdout.lower()
for forbidden in (
    "youtubestreamengine", "youtuberesolver", "youtubeplaybackresolver",
    "innertubeclient", "youtubei/v1", "googlevideo.com", "piped.video",
    "invidious", "yt-dlp", "ytdlpdiscoveryprovider", "carplayscenedelegate",
    "phonewatchsession", "mpremotecommandcenter", "watchconnectivity.framework",
):
    require(forbidden not in text, f"executable excludes {forbidden}")
for expected in (
    "https://www.youtube.com/iframe_api",
    "https://www.googleapis.com/youtube/v3/",
    "https://accounts.google.com/o/oauth2/v2/auth",
    "https://oauth2.googleapis.com/token",
):
    require(expected in text, f"expected public endpoint {expected}")

print("Static artifact audit passed. Runtime requests, signing and store review need separate evidence.")
