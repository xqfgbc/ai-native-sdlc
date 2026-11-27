#!/usr/bin/env bash
# hooks/cognition-context.sh — SessionStart context injection.
# Prints (1) the human-signed project pack (S2) and (2) this service's local
# cognition (S1), which never leaves the repo. stdout is added to agent context.
set -uo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
PACK=""
if [ -f "$ROOT/.sdlc/cognition-pack.json" ]; then PACK="$ROOT/.sdlc/cognition-pack.json"
elif [ -f "$ROOT/knowledge/pack.json" ]; then PACK="$ROOT/knowledge/pack.json"
elif [ -f "$ROOT/.sdlc/config.json" ]; then
  mgmt="$(jq -r '.managementRepo // empty' "$ROOT/.sdlc/config.json" 2>/dev/null || true)"
  [ -n "$mgmt" ] && [ -f "$mgmt/knowledge/pack.json" ] && PACK="$mgmt/knowledge/pack.json"
fi

if [ -n "$PACK" ]; then
  VER="$(jq -r '.metadata.version // "?"' "$PACK" 2>/dev/null || echo '?')"
  COUNT="$(jq '[.items[]|select(.status=="active")]|length' "$PACK" 2>/dev/null || echo 0)"
  if [ "$COUNT" -gt 0 ] 2>/dev/null; then
    echo "项目认知（pack v${VER}，人工签核 active）："
    jq -r '.items[]|select(.status=="active")|"- [\(.enforcement)] \(.statement // .title)（\(.id)）"' "$PACK"
    echo "（deterministic 条目同时由 hook/ArchUnit/lint/CI 强制）"
  fi
fi

LOCAL="$ROOT/.sdlc/local-cognition.json"
if [ -f "$LOCAL" ]; then
  N="$(jq '[.items[]|select(.status=="active")]|length' "$LOCAL" 2>/dev/null || echo 0)"
  if [ "$N" -gt 0 ] 2>/dev/null; then
    echo "本服务本地认知（S1，只在本仓生效）："
    jq -r '.items[]|select(.status=="active")|"- [\(.enforcement)] \(.statement)（\(.id)）"' "$LOCAL"
    echo "（本地规则正文不上报；查询：bash scripts/local-cognition.sh list --json）"
  fi
fi
exit 0
