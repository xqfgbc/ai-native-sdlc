#!/usr/bin/env bash
# scripts/replay-reports.sh — upload locally collected reports to a management repo.
#
# Collect can run while the management repo is absent (offline, fresh clone): the
# report stays in sync/reports/ and lastCollectedSha advances, while lastUploadedSha
# does not. This replays the backlog idempotently (existing reports are skipped).
#
# Usage: replay-reports.sh <management-repo-dir> [--dry-run] [--json]
set -euo pipefail
MGMT="${1:-}"; shift || true
DRY=0; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --json) JSON=1; shift ;;
    *) echo "replay-reports: unknown option $1" >&2; exit 1 ;;
  esac
done
[ -n "$MGMT" ] && [ -d "$MGMT" ] || {
  echo "Usage: $0 <management-repo-dir> [--dry-run] [--json]" >&2
  echo "replay-reports: management repo is not a local directory: ${MGMT:-<unset>}" >&2
  exit 1; }

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONFIG="$ROOT/.sdlc/config.json"
[ -f "$CONFIG" ] || { echo "replay-reports: run inside a service repo with .sdlc/config.json" >&2; exit 1; }
SERVICE="$(jq -r .service "$CONFIG")"
REPORTS="$ROOT/sync/reports"

shopt -s nullglob
files=("$REPORTS"/*.json)
[ "${#files[@]}" -gt 0 ] || { echo "replay-reports: no reports in $REPORTS"; exit 0; }

uploaded=(); skipped=(); cursor="$(jq -r '.lastUploadedSha // ""' "$CONFIG")"
while IFS=$'\t' read -r _created f; do
  [ -n "${f:-}" ] || continue
  to="$(jq -r '.metadata.toSha' "$f")"
  stage="$(jq -r '.spec.stage' "$f")"
  [ -n "$to" ] && [ -n "$stage" ] || continue
  dest="$MGMT/execution/$stage/$SERVICE/reports/$to.json"
  if [ -f "$dest" ]; then
    skipped+=("$to"); cursor="$to"; continue
  fi
  if [ "$DRY" = "0" ]; then
    mkdir -p "$(dirname "$dest")"
    cp "$f" "$dest"
  fi
  uploaded+=("$to"); cursor="$to"
done <<< "$(
  for f in "${files[@]}"; do
    printf '%s\t%s\n' "$(jq -r '.metadata.createdAt // ""' "$f")" "$f"
  done | sort
)"

if [ "$DRY" = "0" ] && [ -n "$cursor" ] && [ "$cursor" != "$(jq -r '.lastUploadedSha // ""' "$CONFIG")" ]; then
  tmp="$(mktemp)"
  jq --arg up "$cursor" '.lastUploadedSha=$up' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
fi

arr_json() { [ "$#" -eq 0 ] && echo '[]' || printf '%s\n' "$@" | jq -R -s 'split("\n")|map(select(length>0))'; }
if [ "$JSON" = "1" ]; then
  jq -n --arg svc "$SERVICE" --arg mgmt "$MGMT" --arg cursor "$cursor" --argjson dry "$([ "$DRY" = 1 ] && echo true || echo false)" \
    --argjson up "$(arr_json ${uploaded[@]+"${uploaded[@]}"})" \
    --argjson skip "$(arr_json ${skipped[@]+"${skipped[@]}"})" \
    '{service:$svc,managementRepo:$mgmt,dryRun:$dry,uploaded:$up,skipped:$skip,cursor:$cursor}'
else
  echo "replay-reports: uploaded=${#uploaded[@]} skipped=${#skipped[@]} cursor=${cursor:-<none>}$([ "$DRY" = 1 ] && echo ' (dry-run)')"
fi
