#!/usr/bin/env bash
# scripts/intake-signal.sh — append one intake signal (Slack / Linear / email / alert) to intake/signals/.
# Usage: scripts/intake-signal.sh <tag> <title> [body]
#        echo "<body>" | scripts/intake-signal.sh <tag> <title>
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
TAG="${1:-uncategorized}"
TITLE="${2:-untitled}"
BODY="${3:-}"
if [ -z "$BODY" ] && [ ! -t 0 ]; then BODY="$(cat)"; fi
mkdir -p intake/signals
TS="$(date -u +%Y%m%dT%H%M%SZ)"
SLUG="$(printf '%s' "$TITLE" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//' | cut -c1-40)"
[ -n "$SLUG" ] || SLUG="signal"
F="intake/signals/${TS}-${SLUG}.md"
{ printf '# %s\nTag: %s\n\n%s\n' "$TITLE" "$TAG" "$BODY"; } > "$F"
echo "intake-signal: $F"
