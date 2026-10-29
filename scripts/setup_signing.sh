#!/bin/bash
# One-time setup of a stable code-signing identity for local builds.
#
# Why: macOS ties Screen Recording permission to the binary's code signature.
# Ad-hoc builds get a new hash on every rebuild and lose the grant. A trusted
# self-signed certificate keeps the designated requirement stable, so you grant
# the permission once and keep it across rebuilds.
#
# macOS will ask for your password ONCE (trust settings). That is expected.
set -euo pipefail

KC="$HOME/Library/Keychains/panto-dev.keychain-db"
PASS="panto-dev"
IDENTITY="Panto Dev"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if security find-identity -v -p codesigning "$KC" 2>/dev/null | grep "$IDENTITY" | grep -qv CSSMERR; then
    echo "✔ $IDENTITY is already trusted"
    exit 0
fi

if [ ! -f "$KC" ]; then
    security create-keychain -p "$PASS" "$KC"
fi
security set-keychain-settings -lut 21600 "$KC" >/dev/null
security unlock-keychain -p "$PASS" "$KC" >/dev/null

if ! security find-identity -p codesigning "$KC" 2>/dev/null | grep -q "$IDENTITY"; then
    echo "▸ creating certificate"
    openssl req -x509 -newkey rsa:2048 \
        -keyout "$WORK/key.pem" -out "$WORK/cert.pem" \
        -days 3650 -nodes -subj "/CN=$IDENTITY" \
        -addext "basicConstraints=critical,CA:false" \
        -addext "keyUsage=critical,digitalSignature" \
        -addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null
    openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
        -out "$WORK/identity.p12" -name "$IDENTITY" -passout pass:"$PASS" 2>/dev/null
    security import "$WORK/identity.p12" -k "$KC" -P "$PASS" -T /usr/bin/codesign >/dev/null
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PASS" "$KC" >/dev/null
fi

if [ ! -f "$WORK/cert.pem" ]; then
    security find-certificate -c "$IDENTITY" -p "$KC" > "$WORK/cert.pem"
fi

echo "▸ trusting the certificate (macOS will ask for your password)"
security add-trusted-cert -r trustRoot -k "$KC" "$WORK/cert.pem"

echo "▸ checking"
security find-identity -v -p codesigning "$KC"
echo "✔ done. Rebuild with ./scripts/make_app.sh — it will use the stable identity."
