#!/usr/bin/env bash
# hooks/cognition-context.sh — SessionStart context injection: print active project
# cognition (signed by a human) so the agent sees it before doing anything.
# stdout is added to the agent context (Claude Code SessionStart).
set -uo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
PACK=""
if [ -f "$ROOT/.sdlc/cognition-pack.json" ]; then PACK="$ROOT/.sdlc/cognition-pack.json"
elif [ -f "$ROOT/knowledge/pack.json" ]; then PACK="$ROOT/knowledge/pack.json"
elif [ -f "$ROOT/.sdlc/config.json" ]; then
  mgmt="$(jq -r '.managementRepo // empty' "$ROOT/.sdlc/config.json" 2>/dev/null || true)"
  [ -n "$mgmt" ] && [ -f "$mgmt/knowledge/pack.json" ] && PACK="$mgmt/knowledge/pack.json"
fi
[ -n "$PACK" ] || exit 0
VER="$(jq -r '.metadata.version // "?"' "$PACK" 2>/dev/null || echo '?')"
COUNT="$(jq '[.items[]|select(.status=="active")]|length' "$PACK" 2>/dev/null || echo 0)"
[ "$COUNT" = "0" ] && exit 0
echo "项目认知（pack v${VER}，人工签核 active）："
jq -r '.items[]|select(.status=="active")|"- [\(.enforcement)] \(.statement // .title)（\(.id)）"' "$PACK"
echo "（deterministic 条目同时由 hook/ArchUnit/lint/CI 强制）"
