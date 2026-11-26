#!/usr/bin/env bash
# scripts/intake.sh — cluster raw intake signals into candidate intents (the outer intelligence loop).
# Reads intake/signals/*.md, groups by a `Tag:` line (fallback: uncategorized), and writes
# intake/candidates/<date>-<tag>.md with a suggested intent skeleton. Humans promote a candidate
# to loop/01-intent/INT-*/intent.md; this script never creates real intents.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
mkdir -p intake/candidates
SIGNALS="$(find intake/signals -maxdepth 1 -type f -name '*.md' 2>/dev/null | grep -v 'README.md' | sort || true)"
if [ -z "$SIGNALS" ]; then echo "intake: no signals"; exit 0; fi
DATE="$(date -u +%Y-%m-%d)"

while IFS= read -r s; do
  [ -n "$s" ] || continue
  tag="$(grep -m1 -E '^Tag:' "$s" | sed 's/^Tag:[[:space:]]*//' | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//' || true)"
  [ -n "$tag" ] || tag="uncategorized"
  title="$(grep -m1 -E '^# ' "$s" | sed 's/^# //' || true)"
  [ -n "$title" ] || title="$(basename "$s" .md)"
  summary="$(grep -vE '^(#|Tag:)' "$s" | sed '/^[[:space:]]*$/d' | head -2 | tr '\n' ' ' || true)"
  out="intake/candidates/${DATE}-${tag}.md"
  if [ ! -f "$out" ]; then
    printf '# Intake candidate: %s (%s)\n\n> Clustered by intake.sh from intake/signals/. Promote to loop/01-intent/ when ready.\n\n' "$tag" "$DATE" > "$out"
  fi
  {
    printf '## %s\n\n' "$title"
    printf -- '- Source: `%s`\n' "$s"
    printf -- '- %s\n\n' "$summary"
  } >> "$out"
done <<< "$SIGNALS"

echo "intake: candidates in intake/candidates/ ($(ls intake/candidates/*.md 2>/dev/null | wc -l | tr -d ' ') files)"
