#!/bin/bash
# Builds a drag-to-Applications DMG from build/Panto.app.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/Panto.app"
[ -d "$APP" ] || { echo "Build the app first: ./scripts/make_app.sh"; exit 1; }

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="$ROOT/build/Panto-$VERSION.dmg"
# Stage outside the project so Spotlight/Launchpad never index a second copy.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP" "$STAGE/Panto.app"
# Distribution builds are ad-hoc signed: Gatekeeper treats that as a normal
# "unidentified developer" app, which users can open with right-click → Open.
codesign --force --deep --sign - "$STAGE/Panto.app" >/dev/null 2>&1 || true
ln -s /Applications "$STAGE/Applications"

cat > "$STAGE/Read me.txt" <<'TXT'
Panto — install
===============

1. Drag Panto.app into the Applications folder.

2. First launch: right-click Panto → Open → Open.
   (Panto is open source and not notarized, so macOS asks once.)

   If macOS says the app is damaged, open Terminal and run:
   xattr -dr com.apple.quarantine /Applications/Panto.app

3. Grant Screen Recording (and Microphone for voiceover), then quit Panto
   and open it again — macOS applies the permissions on the next launch.

Source, issues, updates: https://github.com/USER/panto
TXT

rm -f "$DMG"
hdiutil create -volname "Panto" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
echo "▸ dmg: $DMG ($(du -h "$DMG" | cut -f1))"
