#!/usr/bin/env bash
# scripts/sync-project-gates.sh — distribute project-level (S2) gates from the
# control plane to the services they apply to.
#
# A gate lives under <control-plane>/guardrails/<gate-id>/:
#   manifest.json  {id, proposalId, appliesTo:[service...], files:[{src,dest}], evidence}
#   <src files>
#
# Usage: sync-project-gates.sh <control-plane> [--write] [--check] [--service <name>] [--json]
#   default   dry-run: list drift
#   --write   copy files into the local service repos
#   --check   exit 1 when drift exists
set -euo pipefail
MGMT="${1:-}"; shift || true
[ -n "$MGMT" ] && [ -d "$MGMT" ] && [ -f "$MGMT/loop/04-build/services.json" ] || {
  echo "Usage: $0 <control-plane> [--write] [--check] [--service <name>] [--json]" >&2
  echo "sync-project-gates: not a management repo: ${MGMT:-<unset>}" >&2
  exit 1; }
MGMT_ABS="$(cd "$MGMT" && pwd)"
REG="$MGMT_ABS/loop/04-build/services.json"

WRITE=0; CHECK=0; ONLY=""; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --write) WRITE=1; shift ;;
    --check) CHECK=1; shift ;;
    --service) ONLY="${2:-}"; shift 2 ;;
    --json) JSON=1; shift ;;
    *) echo "sync-project-gates: unknown option $1" >&2; exit 1 ;;
  esac
done

local_path_of() {
  local name="$1" repo cand
  repo="$(jq -r --arg n "$name" '.services[]|select(.name==$n)|.repo' "$REG")"
  [ -n "$repo" ] || return 1
  if [ -d "$repo" ] && [ -f "$repo/service.json" ]; then printf '%s\n' "$repo"; return 0; fi
  cand="$(dirname "$MGMT_ABS")/${repo##*/}"
  if [ -d "$cand" ] && [ -f "$cand/service.json" ]; then printf '%s\n' "$cand"; return 0; fi
  return 1
}

changes_total=0
JSON_SERVICES="[]"
shopt -s nullglob
for manifest in "$MGMT_ABS"/guardrails/*/manifest.json; do
  [ -f "$manifest" ] || continue
  gdir="$(dirname "$manifest")"
  gid="$(jq -r '.id // ""' "$manifest")"
  [ -n "$gid" ] || gid="$(basename "$gdir")"
  gstatus="$(jq -r '.status // "active"' "$manifest" 2>/dev/null || echo active)"
  while IFS= read -r svc; do
    [ -n "$svc" ] || continue
    [ -n "$ONLY" ] && [ "$svc" != "$ONLY" ] && continue
    target="$(local_path_of "$svc" || true)"
    if [ -z "$target" ]; then
      echo "sync-project-gates: skip $gid -> $svc (no local clone)" >&2
      continue
    fi
    changes=()
    if [ "$gstatus" = "retired" ]; then
      # Desired state for a retired gate: the files are gone.
      while IFS=$'\t' read -r src dest; do
        [ -n "$src" ] || continue
        [ -f "$target/$dest" ] && changes+=("$dest (retired)")
      done <<< "$(jq -r '.files[]? | [.src,.dest]|@tsv' "$manifest")"
    else
      while IFS=$'\t' read -r src dest; do
        [ -n "$src" ] || continue
        srcf="$gdir/$src"; destf="$target/$dest"
        cmp -s "$srcf" "$destf" || changes+=("$dest")
      done <<< "$(jq -r '.files[]? | [.src,.dest]|@tsv' "$manifest")"
    fi
    n="${#changes[@]}"
    changes_total=$((changes_total + n))
    if [ "$n" -eq 0 ]; then
      echo "sync-project-gates: $gid -> $svc up to date"
    else
      echo "sync-project-gates: $gid -> $svc has $n difference(s)"
      for c in ${changes[@]+"${changes[@]}"}; do echo "  ~ $c"; done
      if [ "$WRITE" = "1" ]; then
        while IFS=$'\t' read -r src dest; do
          [ -n "$src" ] || continue
          if [ "$gstatus" = "retired" ]; then
            rm -f "$target/$dest"
          else
            mkdir -p "$(dirname "$target/$dest")"
            cp "$gdir/$src" "$target/$dest"
          fi
        done <<< "$(jq -r '.files[]? | [.src,.dest]|@tsv' "$manifest")"
        if [ "$gstatus" = "retired" ]; then
          echo "sync-project-gates: pruned retired gate files from $svc"
        else
          echo "sync-project-gates: wrote $n file(s) into $svc"
        fi
      fi
    fi
    JSON_SERVICES="$(printf '%s' "$JSON_SERVICES" | jq --arg g "$gid" --arg s "$svc" --arg p "$target" --arg gs "$gstatus" \
      --argjson ch "$(printf '%s\n' ${changes[@]+"${changes[@]}"} | jq -R -s 'split("\n")|map(select(length>0))')" \
      '. + [{gate:$g,status:$gs,service:$s,path:$p,changes:$ch}]')"
  done <<< "$(jq -r '.appliesTo[]?' "$manifest")"
done

if [ "$JSON" = "1" ]; then
  jq -n --arg mgmt "$MGMT_ABS" --argjson dry "$([ "$WRITE" = 1 ] && echo false || echo true)" \
    --argjson total "$changes_total" --argjson entries "$JSON_SERVICES" \
    '{managementRepo:$mgmt,dryRun:$dry,totalChanges:$total,entries:$entries}'
else
  echo "sync-project-gates: $changes_total difference(s)$([ "$WRITE" = 1 ] && echo ' (written)' || echo ' (dry-run)')"
fi
[ "$CHECK" = "1" ] && [ "$changes_total" -gt 0 ] && exit 1
exit 0
