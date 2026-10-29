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

echo "▸ done: $APP"
