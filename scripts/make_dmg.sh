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
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -volname "Panto" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
echo "▸ dmg: $DMG ($(du -h "$DMG" | cut -f1))"
