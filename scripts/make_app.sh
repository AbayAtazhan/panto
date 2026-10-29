#!/bin/bash
# Builds Panto.app without Xcode (Command Line Tools are enough).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/Panto.app"
BIN="$ROOT/.build/release/Panto"

echo "▸ building release binary"
swift build -c release --package-path "$ROOT"

echo "▸ assembling bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Panto"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

echo "▸ drawing icon"
"$APP/Contents/MacOS/Panto" --icon "$ROOT/build/icon-1024.png"
ICONSET="$ROOT/build/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
SIZE_SPECS=(
  "16 icon_16x16.png"
  "32 icon_16x16@2x.png"
  "32 icon_32x32.png"
  "64 icon_32x32@2x.png"
  "128 icon_128x128.png"
  "256 icon_128x128@2x.png"
  "256 icon_256x256.png"
  "512 icon_256x256@2x.png"
  "512 icon_512x512.png"
)
for spec in "${SIZE_SPECS[@]}"; do
    set -- $spec
    sips -z "$1" "$1" "$ROOT/build/icon-1024.png" --out "$ICONSET/$2" >/dev/null
done
cp "$ROOT/build/icon-1024.png" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "▸ signing (ad-hoc)"
codesign --force --deep --sign - "$APP"

# macOS ties Screen Recording to the binary's code hash. Ad-hoc builds get a new
# hash on every rebuild, which silently invalidates the old grant. Detect it and
# clear the stale entry so the system prompt can appear again.
NEW_HASH=$(codesign -dv --verbose=4 "$APP" 2>&1 | awk -F= '/^CDHash=/{print $2}')
STATE="$ROOT/build/.last-cdhash"
if [ -f "$STATE" ] && [ "$(cat "$STATE")" != "$NEW_HASH" ]; then
    echo "▸ binary changed → resetting stale screen-recording permission"
    tccutil reset ScreenCapture app.panto.recorder >/dev/null 2>&1 || true
    tccutil reset Microphone app.panto.recorder >/dev/null 2>&1 || true
fi
echo "$NEW_HASH" > "$STATE"

echo "▸ done: $APP"
