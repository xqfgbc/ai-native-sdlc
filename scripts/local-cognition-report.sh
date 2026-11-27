#!/usr/bin/env bash
# scripts/local-cognition-report.sh — aggregate S1 evidence reported by services.
#
# Reports carry origin/problem/summary/gate for service-local rules, never the
# statement. This builds wiki/local-cognition.md plus a JSON view, flags gates
# whose path no longer exists, and suggests cross-service promotion candidates
# (same gate name or same problem across >=2 services).
#
# Usage: local-cognition-report.sh [<management-repo>] [--json] [--out <file>]
set -euo pipefail
MGMT="."; JSON=0; OUT="wiki/local-cognition.md"
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --out) OUT="${2:-}"; shift 2 ;;
    -*) echo "local-cognition-report: unknown option $1" >&2; exit 1 ;;
    *) MGMT="$1"; shift ;;
  esac
done
cd "$MGMT"
MGMT_ABS="$(pwd)"
REG="loop/04-build/services.json"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

files=()
while IFS= read -r f; do files+=("$f"); done < <(find execution -path '*/reports/*.json' -type f 2>/dev/null || true)
if [ "${#files[@]}" -eq 0 ]; then
  echo "local-cognition-report: no execution reports"; exit 0
fi

SERVICES="$(jq -s '
  group_by(.metadata.service)
  | map(max_by(.metadata.createdAt))
  | map({service:.metadata.service, report:.metadata.toSha, createdAt:.metadata.createdAt,
         items:(.spec.localCognition // [])})' ${files[@]+"${files[@]}"})"

# Stale: a deterministic gate path that no longer exists in the local clone.
STALE="[]"
for svc in $(printf '%s' "$SERVICES" | jq -r '.[].service'); do
  repo="$(jq -r --arg n "$svc" '.services[]|select(.name==$n)|.repo // empty' "$REG" 2>/dev/null || true)"
  path=""
  if [ -n "$repo" ] && [ -d "$repo" ] && [ -f "$repo/service.json" ]; then path="$repo"
  elif [ -n "$repo" ]; then
    cand="$(dirname "$MGMT_ABS")/${repo##*/}"
    [ -d "$cand" ] && [ -f "$cand/service.json" ] && path="$cand"
  fi
  [ -n "$path" ] || continue
  while IFS=$'\t' read -r iid gp; do
    [ -n "$iid" ] || continue
    [ -n "$gp" ] || continue
    if [ ! -f "$path/$gp" ]; then
      STALE="$(printf '%s' "$STALE" | jq --arg s "$svc" --arg id "$iid" --arg p "$gp" \
        '. + [{service:$s,id:$id,path:$p}]')"
    fi
  done <<< "$(printf '%s' "$SERVICES" | jq -r --arg s "$svc" \
    '.[]|select(.service==$s)|.items[]|select((.gate.path // "")!="")|"\(.id)\t\(.gate.path)"')"
done

ITEMS="$(printf '%s' "$SERVICES" | jq '[.[] as $s | $s.items[] | {service:$s.service,id,kind,enforcement,problem,summary,gate}]')"
CANDIDATES="$(printf '%s' "$ITEMS" | jq '
  . as $items
  | ( [ $items[] | select((.gate.name // "") != "") ]
      | group_by(.gate.name)
      | map(select((map(.service)|unique|length) >= 2))
      | map({kind:"gate", key:.[0].gate.name, services:(map(.service)|unique), items:.}) )
  + ( [ $items[] | select((.problem // "") != "") ]
      | group_by(.problem|ascii_downcase)
      | map(select((map(.service)|unique|length) >= 2))
      | map({kind:"problem", key:.[0].problem, services:(map(.service)|unique), items:.}) )')"

REPORT="$(jq -n --arg at "$NOW" --argjson services "$SERVICES" --argjson stale "$STALE" \
  --argjson items "$ITEMS" --argjson candidates "$CANDIDATES" '
  {apiVersion:"sdlc/v1",kind:"LocalCognitionReport",generatedAt:$at,
   services:($services | map(. as $s | . + {stale:([ $stale[] | select(.service==$s.service) | .id ])})),
   itemCount:($items|length), stale:$stale, promotionCandidates:$candidates}')"

if [ -n "$OUT" ]; then
  mkdir -p "$(dirname "$OUT")"
  {
    echo "# Local cognition (S1) — $NOW"; echo
    echo "> 服务本地规则只在本仓生效；这里只展示上报的证据与背景，不含规则正文。"; echo
    echo "| Service | Items | Deterministic | Stale |"; echo "|---|---|---|---|"
    printf '%s' "$REPORT" | jq -r '.services[] | "| \(.service) | \(.items|length) | \([.items[]|select(.enforcement=="deterministic")]|length) | \(.stale|length) |"'
    echo; echo "## Stale gates"; echo
    printf '%s' "$REPORT" | jq -r 'if (.stale|length)==0 then "_None._" else (.stale[]|"- \(.service) \(.id) — missing \(.path)") end'
    echo; echo "## Promotion candidates"; echo
    printf '%s' "$REPORT" | jq -r 'if (.promotionCandidates|length)==0 then "_None._" else
      (.promotionCandidates[]|"- [\(.kind)] \(.key) — services: \(.services|join(", "))") end'
    echo; echo "## Items"; echo
    printf '%s' "$REPORT" | jq -r '.services[] as $s | $s.items[] | "- \($s.service) \(.id) [\(.enforcement)] — \(.problem // "")"'
  } > "$OUT"
fi

if [ "$JSON" = 1 ]; then printf '%s\n' "$REPORT"; else
  printf '%s' "$REPORT" | jq -r '"local-cognition-report: \(.itemCount) item(s), \(.stale|length) stale, \(.promotionCandidates|length) promotion candidate(s)"'
fi
