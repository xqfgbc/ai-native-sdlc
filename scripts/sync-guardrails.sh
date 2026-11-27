#!/usr/bin/env bash
# scripts/sync-guardrails.sh — push the factory's hooks/scripts into existing service repos.
#
# Generators copy guardrails once; fixes made in the framework afterwards (no-secrets,
# commit-msg, app-verify, collect, ...) otherwise drift per repo. This compares every
# registered service's local clone with the framework and optionally writes the files.
#
# Usage: sync-guardrails.sh <control-plane-repo> [--source <framework-repo>] [--write] [--check] [--service <name>] [--json]
#   default   dry-run: list differences, write nothing
#   --write   copy the framework files into each local service repo and re-install hooks
#   --check   exit 1 when any drift exists (CI)
set -euo pipefail
MGMT="${1:-}"; shift || true
[ -n "$MGMT" ] && [ -d "$MGMT" ] && [ -f "$MGMT/loop/04-build/services.json" ] || {
  echo "Usage: $0 <control-plane-repo> [--write] [--check] [--service <name>] [--json]" >&2
  echo "sync-guardrails: not a management repo: ${MGMT:-<unset>}" >&2
  exit 1; }
SOURCE="${SDL_FRAMEWORK_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MGMT_ABS="$(cd "$MGMT" && pwd)"
REG="$MGMT_ABS/loop/04-build/services.json"

WRITE=0; CHECK=0; ONLY=""; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --write) WRITE=1; shift ;;
    --check) CHECK=1; shift ;;
    --service) ONLY="${2:-}"; shift 2 ;;
    --source) SOURCE="${2:-}"; shift 2 ;;
    --json) JSON=1; shift ;;
    *) echo "sync-guardrails: unknown option $1" >&2; exit 1 ;;
  esac
done
SOURCE="$(cd "$SOURCE" 2>/dev/null && pwd)" || {
  echo "sync-guardrails: framework source not found: ${SOURCE:-<unset>}" >&2; exit 1; }
[ -d "$SOURCE/templates/service-types" ] && [ -f "$SOURCE/scripts/collect.sh" ] || {
  echo "sync-guardrails: $SOURCE is not the framework repo (use --source or SDL_FRAMEWORK_REPO)" >&2
  exit 1; }

# file pairs: <framework path>|<service path>
FILES=(
  "scripts/app-verify.sh|scripts/app-verify.sh"
  "scripts/autopilot-gate.sh|scripts/autopilot-gate.sh"
  "scripts/cognition.sh|scripts/cognition.sh"
  "scripts/collect.sh|.sdlc/collect.sh"
  "scripts/debt.sh|scripts/debt.sh"
  "scripts/install-hooks.sh|scripts/install-hooks.sh"
  "scripts/local-cognition.sh|scripts/local-cognition.sh"
  "scripts/replay-reports.sh|scripts/replay-reports.sh"
  "scripts/scan-findings.sh|scripts/scan-findings.sh"
  "scripts/upload-report.sh|scripts/upload-report.sh"
  "scripts/validate-skills.sh|scripts/validate-skills.sh"
  ".claude/settings.json|.claude/settings.json"
  ".codex/hooks.json|.codex/hooks.json"
)
DIRS=("hooks" ".githooks")

local_path_of() { # <repo> -> local clone path, exit 1 when absent
  local repo="$1" cand
  if [ -d "$repo" ] && [ -f "$repo/service.json" ]; then printf '%s\n' "$repo"; return 0; fi
  cand="$(dirname "$MGMT_ABS")/${repo##*/}"
  if [ -d "$cand" ] && [ -f "$cand/service.json" ]; then printf '%s\n' "$cand"; return 0; fi
  return 1
}

changes_total=0
JSON_SERVICES="[]"
while IFS=$'\t' read -r name repo; do
  [ -n "$name" ] || continue
  [ -n "$ONLY" ] && [ "$name" != "$ONLY" ] && continue
  target="$(local_path_of "$repo" || true)"
  if [ -z "$target" ]; then
    echo "sync-guardrails: skip $name (no local clone for $repo)" >&2
    JSON_SERVICES="$(printf '%s' "$JSON_SERVICES" | jq --arg n "$name" --arg r "$repo" \
      '. + [{name:$n,path:null,skipped:true,changes:[]}]')"
    continue
  fi

  changes=()
  for d in "${DIRS[@]}"; do
    src="$SOURCE/$d"
    [ -d "$src" ] || continue
    while IFS= read -r -d '' f; do
      rel="${f#"$src"/}"
      cmp -s "$f" "$target/$d/$rel" || changes+=("$d/$rel")
    done < <(find "$src" -type f -print0)
  done
  for pair in "${FILES[@]}"; do
    src_rel="${pair%%|*}"; dst_rel="${pair##*|}"
    [ -f "$SOURCE/$src_rel" ] || continue
    cmp -s "$SOURCE/$src_rel" "$target/$dst_rel" || changes+=("$dst_rel")
  done

  n="${#changes[@]}"
  changes_total=$((changes_total + n))
  if [ "$n" -eq 0 ]; then
    echo "sync-guardrails: $name up to date"
  else
    echo "sync-guardrails: $name has $n difference(s)"
    for c in ${changes[@]+"${changes[@]}"}; do echo "  ~ $c"; done
  fi

  if [ "$WRITE" = "1" ] && [ "$n" -gt 0 ]; then
    for d in "${DIRS[@]}"; do
      [ -d "$SOURCE/$d" ] || continue
      mkdir -p "$target/$d"
      cp -R "$SOURCE/$d/." "$target/$d/"
    done
    for pair in "${FILES[@]}"; do
      src_rel="${pair%%|*}"; dst_rel="${pair##*|}"
      [ -f "$SOURCE/$src_rel" ] || continue
      mkdir -p "$(dirname "$target/$dst_rel")"
      cp "$SOURCE/$src_rel" "$target/$dst_rel"
    done
    chmod +x "$target"/hooks/*.sh "$target"/.githooks/* "$target"/scripts/*.sh 2>/dev/null || true
    bash "$target/scripts/install-hooks.sh" >/dev/null 2>&1 || true
    echo "sync-guardrails: wrote $n file(s) into $name"
  fi

  JSON_SERVICES="$(printf '%s' "$JSON_SERVICES" | jq --arg n "$name" --arg p "$target" \
    --argjson ch "$(printf '%s\n' ${changes[@]+"${changes[@]}"} | jq -R -s 'split("\n")|map(select(length>0))')" \
    '. + [{name:$n,path:$p,skipped:false,changes:$ch}]')"
done <<< "$(jq -r '.services[] | [.name,.repo]|@tsv' "$REG")"

if [ "$JSON" = "1" ]; then
  jq -n --arg mgmt "$MGMT_ABS" --argjson dry "$([ "$WRITE" = 1 ] && echo false || echo true)" \
    --argjson svc "$JSON_SERVICES" --argjson total "$changes_total" \
    '{managementRepo:$mgmt,dryRun:$dry,totalChanges:$total,services:$svc}'
else
  echo "sync-guardrails: $changes_total difference(s)$([ "$WRITE" = 1 ] && echo ' (written)' || echo ' (dry-run)')"
fi
[ "$CHECK" = "1" ] && [ "$changes_total" -gt 0 ] && exit 1
exit 0
