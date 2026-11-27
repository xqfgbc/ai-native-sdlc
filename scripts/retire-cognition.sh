#!/usr/bin/env bash
# scripts/retire-cognition.sh — retire an active project rule (human decision).
#
# Retiring bumps the pack version, marks the item retired (it stops rendering into
# services), retires linked guardrail manifests and gate-queue tasks, and leaves an
# audit trail. Distribution is separate on purpose:
#   sync-cognition.sh . <service>          # remove it from CLAUDE.md/AGENTS.md
#   sync-project-gates.sh . --write        # prune retired gate files from services
#
# Usage: retire-cognition.sh <management-repo> <item-id> <owner> --reason <text>
#                           [--superseded-by <item-id>] [--json]
set -euo pipefail
MGMT="${1:-}"; ID="${2:-}"; OWNER="${3:-}"; shift 3 || true
[ -n "$MGMT" ] && [ -n "$ID" ] && [ -n "$OWNER" ] || {
  echo "Usage: $0 <management-repo> <item-id> <owner> --reason <text> [--superseded-by <id>] [--json]" >&2
  exit 1; }
REASON=""; SUP=""; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --reason) REASON="${2:-}"; shift 2 ;;
    --superseded-by) SUP="${2:-}"; shift 2 ;;
    --json) JSON=1; shift ;;
    *) echo "retire-cognition: unknown option $1" >&2; exit 1 ;;
  esac
done
[ -n "$REASON" ] || { echo "retire-cognition: --reason is required" >&2; exit 1; }
cd "$MGMT"
[ -f knowledge/pack.json ] || { echo "retire-cognition: missing knowledge/pack.json" >&2; exit 1; }
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

STATUS="$(jq -r --arg id "$ID" '.items[]|select(.id==$id)|.status // ""' knowledge/pack.json)"
if [ -z "$STATUS" ]; then echo "retire-cognition: item not found: $ID" >&2; exit 1; fi
if [ "$STATUS" = "retired" ]; then
  if [ "$JSON" = 1 ]; then jq --arg id "$ID" '.items[]|select(.id==$id)' knowledge/pack.json
  else echo "retire-cognition: $ID already retired"; fi
  exit 0
fi
[ "$STATUS" = "active" ] || { echo "retire-cognition: $ID is $STATUS, not active" >&2; exit 1; }
if [ -n "$SUP" ] && ! jq -e --arg id "$SUP" '[.items[]|select(.id==$id)]|length>0' knowledge/pack.json >/dev/null 2>&1; then
  echo "retire-cognition: --superseded-by item not found: $SUP" >&2; exit 1
fi

tmp="$(mktemp)"
jq --arg id "$ID" --arg at "$NOW" --arg o "$OWNER" --arg r "$REASON" --arg sup "$SUP" '
  (.items[]|select(.id==$id)) |= (
    .status = "retired" | .retiredAt = $at | .retiredBy = $o | .retireReason = $r
    | (if $sup == "" then . else .supersededBy = $sup end)
  )' knowledge/pack.json > "$tmp" && mv "$tmp" knowledge/pack.json

VER="$(jq -r '.metadata.version' knowledge/pack.json)"
MAJOR="${VER%%.*}"; REST="${VER#*.}"; MINOR="${REST%%.*}"; PATCH="${REST#*.}"
NEW="$MAJOR.$MINOR.$((PATCH + 1))"
jq --arg v "$NEW" '.metadata.version = $v' knowledge/pack.json > "$tmp" && mv "$tmp" knowledge/pack.json

if [ -f "knowledge/guardrails/$ID.md" ]; then
  printf '\n## Retired %s by %s\n\n%s\n' "$NOW" "$OWNER" "$REASON" >> "knowledge/guardrails/$ID.md"
fi

# Linked guardrail manifests stop being distributed and are pruned on --write.
for m in $(ls guardrails/*/manifest.json 2>/dev/null || true); do
  if jq -e --arg id "$ID" '(.proposalId == $id or .id == $id)' "$m" >/dev/null 2>&1; then
    tmp="$(mktemp)"
    jq --arg at "$NOW" --arg r "$REASON" '.status="retired" | .retiredAt=$at | .retireReason=$r' "$m" > "$tmp" && mv "$tmp" "$m"
  fi
done

# Open work for a retired rule is no longer work.
if [ -f loop/04-build/gates/queue.json ]; then
  tmp="$(mktemp)"
  jq --arg id "$ID" --arg at "$NOW" --arg r "$REASON" '
    (.items[]|select(.proposalId==$id and .status!="done"))
    |= (.status="retired" | .retiredAt=$at | .retireReason=$r | .updatedAt=$at)' \
    loop/04-build/gates/queue.json > "$tmp" && mv "$tmp" loop/04-build/gates/queue.json
fi

if [ "$JSON" = 1 ]; then
  jq -n --arg id "$ID" --arg v "$NEW" --arg o "$OWNER" --arg r "$REASON" --arg sup "$SUP" \
    '{id:$id,status:"retired",packVersion:$v,owner:$o,reason:$r,supersededBy:$sup}'
else
  echo "retire-cognition: $ID retired by $OWNER -> pack v$NEW${SUP:+ (superseded by $SUP)}"
  echo "retire-cognition: run sync-cognition.sh and sync-project-gates.sh --write to propagate"
fi
