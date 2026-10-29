#!/bin/bash
# Panto one-line installer.
#
#   curl -fsSL https://raw.githubusercontent.com/USER/panto/main/install.sh | bash
#
# Downloads the latest release DMG, installs it into /Applications, clears the
# quarantine flag (Panto is not notarized yet) and opens it.
set -euo pipefail

REPO="${PANTO_REPO:-USER/panto}"
URL="https://github.com/${REPO}/releases/latest/download/Panto.dmg"
TMP="$(mktemp -d)"
MOUNT="$TMP/mnt"

cleanup() {
    hdiutil detach "$MOUNT" -quiet 2>/dev/null || true
    rm -rf "$TMP"
}
trap cleanup EXIT

echo "▸ downloading $URL"
curl -fL --progress-bar "$URL" -o "$TMP/Panto.dmg"

echo "▸ mounting"
mkdir -p "$MOUNT"
hdiutil attach "$TMP/Panto.dmg" -nobrowse -quiet -mountpoint "$MOUNT"

echo "▸ installing to /Applications"
rm -rf "/Applications/Panto.app"
cp -R "$MOUNT/Panto.app" "/Applications/Panto.app"
xattr -dr com.apple.quarantine "/Applications/Panto.app" 2>/dev/null || true

echo "▸ done. Panto needs Screen Recording + Microphone permissions on first launch."
open "/Applications/Panto.app"
