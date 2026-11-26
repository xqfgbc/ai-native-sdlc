#!/usr/bin/env bash
# scripts/cognition.sh — AI-facing access to the signed (active) project cognition.
#
# Resolution: <repo>/.sdlc/cognition-pack.json -> <repo>/knowledge/pack.json ->
# <managementRepo>/knowledge/pack.json (from .sdlc/config.json).
#
# Usage:
#   cognition.sh version
#   cognition.sh list [--json]
#   cognition.sh show <id> [--json]
#   cognition.sh context        # markdown block for prompts/context injection
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

PACK=""
if [ -f "$ROOT/.sdlc/cognition-pack.json" ]; then
  PACK="$ROOT/.sdlc/cognition-pack.json"
elif [ -f "$ROOT/knowledge/pack.json" ]; then
  PACK="$ROOT/knowledge/pack.json"
elif [ -f "$ROOT/.sdlc/config.json" ]; then
  mgmt="$(jq -r '.managementRepo // empty' "$ROOT/.sdlc/config.json" 2>/dev/null || true)"
  [ -n "$mgmt" ] && [ -f "$mgmt/knowledge/pack.json" ] && PACK="$mgmt/knowledge/pack.json"
fi

if [ -z "$PACK" ]; then
  echo "cognition: no pack found (sync one with scripts/sync-cognition.sh)" >&2
  exit 1
fi

cmd="${1:-list}"; shift || true
JSON=0
ID=""
for arg in "$@"; do
  case "$arg" in
    --json) JSON=1 ;;
    *) ID="$arg" ;;
  esac
done
VER="$(jq -r '.metadata.version // "?"' "$PACK")"

case "$cmd" in
  version) echo "$VER" ;;
  list)
    if [ "$JSON" = 1 ]; then
      jq '{version:.metadata.version, items:[.items[]|select(.status=="active")]}' "$PACK"
    else
      jq -r '.items[]|select(.status=="active")|"- [\(.enforcement)] \(.id): \(.statement // .title) (owner: \(.owner // "-"))"' "$PACK"
      [ "$(jq '[.items[]|select(.status=="active")]|length' "$PACK")" = "0" ] && echo "（无 active 条目）"
    fi
    ;;
  show)
    [ -n "$ID" ] || { echo "cognition: show needs an id" >&2; exit 1; }
    jq --arg id "$ID" '.items[]|select(.id==$id)' "$PACK"
    ;;
  context)
    echo "## 项目认知（pack v${VER}，人工签核 active）"
    echo
    if [ "$(jq '[.items[]|select(.status=="active")]|length' "$PACK")" = "0" ]; then
      echo "当前无 active 条目。"
    else
      jq -r '.items[]|select(.status=="active")|"- [\(.enforcement)] \(.statement // .title)（\(.id)）"' "$PACK"
      echo
      echo "> deterministic 条目由对应 hook/ArchUnit/lint/CI 强制；advisory 条目按此执行。"
      echo "> 查询：bash scripts/cognition.sh list --json"
    fi
    ;;
  *)
    echo "usage: $0 [version|list|show <id>|context] [--json]" >&2
    exit 1
    ;;
esac
