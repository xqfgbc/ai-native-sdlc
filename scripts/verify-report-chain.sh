#!/usr/bin/env bash
# scripts/verify-report-chain.sh — verify execution reports form an unbroken hash chain.
#
# collect.sh hashes each report (content without the trailing newline) and stores the
# previous report's hash in metadata.prevHash. This checks, per service and in
# createdAt order, that prevHash matches the previous report and that the file name
# equals metadata.toSha.
#
# Usage: verify-report-chain.sh [<management-repo>] [--json]
set -euo pipefail
MGMT="."; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1; shift ;;
    -*) echo "verify-report-chain: unknown option $1" >&2; exit 1 ;;
    *) MGMT="$1"; shift ;;
  esac
done
cd "$MGMT"
files=()
while IFS= read -r f; do files+=("$f"); done < <(find execution -path '*/reports/*.json' -type f 2>/dev/null | sort || true)
if [ "${#files[@]}" -eq 0 ]; then
  echo "verify-report-chain: no reports" >&2
  [ "$JSON" = 1 ] && printf '%s\n' '{"ok":true,"services":[],"errors":0}'
  exit 0
fi

hash_of() { printf '%s' "$(cat "$1")" | (command -v sha256sum >/dev/null && sha256sum || shasum -a 256) | awk '{print $1}'; }

SERVICES="$(jq -s -r '[.[].metadata.service]|unique[]' ${files[@]+"${files[@]}"})"
JSON_SERVICES="[]"; errs=0
for svc in $SERVICES; do
  count=0; broken=0; midstream=0; prev=""; first=1; last=""
  order="$(
    for f in ${files[@]+"${files[@]}"}; do
      [ "$(jq -r '.metadata.service // ""' "$f" 2>/dev/null)" = "$svc" ] || continue
      printf '%s\t%s\n' "$(jq -r '.metadata.createdAt // ""' "$f")" "$f"
    done | sort | cut -f2
  )"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    to="$(jq -r '.metadata.toSha // ""' "$f")"
    base="$(basename "$f" .json)"
    # A report copied to another stage (e.g. the DORA deploy fixture) is not a
    # second link in the chain: skip it when the canonical <toSha>.json exists.
    if [ "$to" != "$base" ] && [ -n "$(find execution -name "$to.json" -type f 2>/dev/null | head -1)" ]; then
      continue
    fi
    count=$((count+1))
    h="$(hash_of "$f")"
    ph="$(jq -r '.metadata.prevHash // ""' "$f")"
    if [ "$to" != "$base" ]; then
      echo "verify-report-chain: $svc filename/toSha mismatch: $(basename "$f") != $to" >&2
      broken=$((broken+1))
    fi
    if [ "$first" = "1" ]; then
      [ -n "$ph" ] && midstream=1
    else
      if [ -z "$ph" ]; then
        echo "verify-report-chain: $svc missing prevHash at $to" >&2
        broken=$((broken+1))
      elif [ "$ph" != "$prev" ]; then
        echo "verify-report-chain: $svc broken chain at $to (prevHash=$ph expected=$prev)" >&2
        broken=$((broken+1))
      fi
    fi
    prev="$h"; last="$to"; first=0
  done <<< "$order"
  [ "$broken" -gt 0 ] && errs=$((errs+broken))
  JSON_SERVICES="$(printf '%s' "$JSON_SERVICES" | jq --arg s "$svc" --argjson n "$count" \
    --argjson b "$broken" --arg m "$midstream" --arg l "$last" \
    '. + [{service:$s,reports:$n,broken:$b,midstream:($m=="1"),lastToSha:$l}]')"
  if [ "$broken" -eq 0 ]; then
    echo "verify-report-chain: $svc $count report(s), chain ok$([ "$midstream" = "1" ] && echo ' (starts mid-stream)')" >&2
  fi
done

if [ "$JSON" = 1 ]; then
  jq -n --argjson ok "$([ "$errs" -eq 0 ] && echo true || echo false)" \
    --argjson errors "$errs" --argjson services "$JSON_SERVICES" \
    '{ok:$ok,errors:$errors,services:$services}'
else
  [ "$errs" -eq 0 ] && echo "verify-report-chain: OK" || echo "verify-report-chain: FAILED ($errs issue(s))"
fi
[ "$errs" -eq 0 ]
