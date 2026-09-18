#!/bin/bash
# Run on Tony's Mac from Muses-Erato checkout (feat/liquid-glass-ui).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SIM="8A78910A-EFBA-487B-B904-D411E680CAA6"
BUNDLE="com.xiaotwu.muses.erato"
UDID="$SIM"

git pull --ff-only origin feat/liquid-glass-ui || true
xcodegen generate
xcodebuild -project Muses.xcodeproj -scheme Muses -configuration Debug \
  -destination "platform=iOS Simulator,id=${UDID}" -derivedDataPath /tmp/MusesDerived build | tail -30

APP=$(find /tmp/MusesDerived/Build/Products/Debug-iphonesimulator -name 'Muses.app' -maxdepth 2 | head -1)
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"

xcrun simctl spawn "$UDID" defaults write "$BUNDLE" muses.debug.seedPlaylistURL -string "https://music.youtube.com/playlist?list=PLVRppllwHcDw"
xcrun simctl spawn "$UDID" defaults delete "$BUNDLE" muses.debug.seedPlaylistDone 2>/dev/null || true
xcrun simctl spawn "$UDID" defaults write "$BUNDLE" muses.debug.autoPlaySeed -bool true

xcrun simctl launch "$UDID" "$BUNDLE"
echo "Launched. Import may take 30–90s. Screenshots → ${ROOT}/.ui-shots/"
mkdir -p "${ROOT}/.ui-shots"
sleep 45
xcrun simctl io "$UDID" screenshot "${ROOT}/.ui-shots/home-ambient.png" || true
