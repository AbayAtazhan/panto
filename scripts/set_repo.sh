#!/bin/bash
# Usage: ./scripts/set_repo.sh owner/repo
# Replaces the current repository path in docs, badges, installer and cask.
set -euo pipefail
REPO="${1:-}"
if ! echo "$REPO" | grep -qE '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'; then
    echo "usage: ./scripts/set_repo.sh owner/repo"
    exit 1
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
FILES=$(grep -rl "AbayAtazhan/panto" . --exclude-dir=.git --exclude-dir=build --exclude-dir=.build || true)
for file in $FILES; do
    sed -i '' "s|AbayAtazhan/panto|$REPO|g" "$file"
done
echo "✔ repository set to $REPO in:"
echo "$FILES" | sed 's|^\./|  |'
