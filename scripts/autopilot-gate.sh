#!/usr/bin/env bash
# scripts/autopilot-gate.sh — deterministic gate for L3 autopilot merges.
# Exit 0 = eligible; exit 1 = not eligible (prints the reason).
# This is the deterministic half of the trust ladder; a human/CI still owns the merge key at L<3.
set -euo pipefail
SVC="$(pwd)"
[ -f "$SVC/service.json" ] || { echo "autopilot-gate: not a service repo (no service.json)" >&2; exit 1; }

LEVEL="$(jq -r '.trustLevel // "L1"' "$SVC/service.json")"
if [ "$LEVEL" != "L3" ]; then
  echo "autopilot-gate: trustLevel=$LEVEL < L3" >&2; exit 1
fi

# 4. revertable: no one-way-door paths in the change.
CHANGED="$(git diff --name-only HEAD~1 2>/dev/null || true)"
ONE_WAY="$(printf '%s\n' "$CHANGED" | grep -E 'db/migration|security/|SecurityConfig|application-prod|schema' || true)"
if [ -n "$ONE_WAY" ]; then
  echo "autopilot-gate: one-way-door change present:" >&2
  printf '  %s\n' "$ONE_WAY" >&2
  exit 1
fi

# clean working tree.
if [ -n "$(git status --porcelain)" ]; then
  echo "autopilot-gate: dirty working tree" >&2; exit 1
fi

# verification/verifier evidence on the exact head (collector report).
HEAD_SHA="$(git rev-parse HEAD)"
REPORT="sync/reports/${HEAD_SHA}.json"
if [ -f "$REPORT" ]; then
  ST="$(jq -r '.spec.review.status // ""' "$REPORT")"
  case "$ST" in
    auto|approved) : ;;
    *) echo "autopilot-gate: report review.status=${ST:-<empty>} (needs auto|approved)" >&2; exit 1 ;;
  esac
else
  echo "autopilot-gate: no report for head ${HEAD_SHA} (run .sdlc/collect.sh first)" >&2; exit 1
fi

echo "autopilot-gate: eligible (trustLevel=$LEVEL, head=$HEAD_SHA)"
