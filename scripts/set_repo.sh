#!/bin/bash
# Usage: ./scripts/set_repo.sh owner/repo
# Replaces the AbayAtazhan/panto placeholder in docs, badges, installer and cask.
set -euo pipefail
REPO="${1:-}"
if [ -z "$REPO" ] || [ "$REPO" = "AbayAtazhan/panto" ]; then
    echo "usage: ./scripts/set_repo.sh your-github-name/panto"
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
