#!/usr/bin/env bash
# scripts/review-proposals.sh — AI pre-judgement for knowledge proposals (never activates).
#
# Usage:
#   review-proposals.sh [<management-repo>]            # write knowledge/reviews/<id>.json + SUMMARY.md
#   review-proposals.sh stats                          # agreement rate from recorded human decisions
#   review-proposals.sh record <proposal-id> --decision promote-deterministic|promote-advisory|debt|reject \
#        --owner <name> [--note text]
#
# The suggestion is advisory: a human still signs via signoff.py / promote-proposal.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MGMT="${1:-.}"
[ "$MGMT" = "stats" ] || [ "$MGMT" = "record" ] || true
if [ "${1:-}" = "stats" ] || [ "${1:-}" = "record" ]; then MGMT="."; else MGMT="${1:-.}"; fi
cd "$MGMT"
MGMT_ABS="$(pwd)"
REVIEWS="knowledge/reviews"
PROPOSALS="knowledge/proposals"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

case "${1:-}" in
  stats)
    shopt -s nullglob
    files=( "$REVIEWS"/*.json )
    total=0; agreed=0; by_risk_high_total=0; by_risk_high_agreed=0
    for f in "${files[@]}"; do
      [ -f "$f" ] || continue
      [ "$(jq -r '.human == null' "$f")" = "true" ] && continue
      total=$((total+1))
      [ "$(jq -r '.human.agreed // false' "$f")" = "true" ] && agreed=$((agreed+1))
      if [ "$(jq -r '.ai.risk // "low"' "$f")" = "high" ]; then
        by_risk_high_total=$((by_risk_high_total+1))
        [ "$(jq -r '.human.agreed // false' "$f")" = "true" ] && by_risk_high_agreed=$((by_risk_high_agreed+1))
      fi
    done
    pct() { [ "$1" -eq 0 ] && echo "n/a" || awk -v a="$1" -v t="$2" 'BEGIN{printf "%.0f%%", a*100/t}'; }
    echo "reviews with human decision: $total"
    echo "agreement: $(pct "$agreed" "$total") ($agreed/$total)"
    echo "high-risk agreement: $(pct "$by_risk_high_agreed" "$by_risk_high_total") ($by_risk_high_agreed/$by_risk_high_total)"
    exit 0
    ;;
  record)
    ID="${2:-}"; shift 2 || true
    DECISION=""; OWNER=""; NOTE=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --decision) DECISION="$2"; shift 2 ;;
        --owner) OWNER="$2"; shift 2 ;;
        --note) NOTE="$2"; shift 2 ;;
        *) echo "review: unknown option $1" >&2; exit 1 ;;
      esac
    done
    [ -n "$ID" ] && [ -n "$DECISION" ] && [ -n "$OWNER" ] || {
      echo "review: record needs <id> --decision <d> --owner <o>" >&2; exit 1; }
    case "$DECISION" in promote-deterministic|promote-advisory|debt|reject) ;; *)
      echo "review: invalid decision '$DECISION'" >&2; exit 1 ;; esac
    F="$REVIEWS/$ID.json"
    mkdir -p "$REVIEWS"
    [ -f "$F" ] || printf '{"apiVersion":"sdlc/v1","kind":"ProposalReview","proposalId":"%s","generatedAt":"%s","ai":{},"human":null}\n' "$ID" "$NOW" > "$F"
    SUG="$(jq -r '.ai.suggestion // ""' "$F")"
    AGREED="false"; [ "$SUG" = "$DECISION" ] && AGREED="true"
    # promote-advisory and promote-deterministic are both "promote"; compare the family too.
    case "$SUG:$DECISION" in
      promote-deterministic:promote-advisory|promote-advisory:promote-deterministic) AGREED="true" ;;
      defer:debt|reject-duplicate:reject) AGREED="true" ;;
    esac
    tmp="$(mktemp)"
    jq --arg d "$DECISION" --arg o "$OWNER" --arg n "$NOTE" --arg at "$NOW" --argjson a "$AGREED" \
      '.human = {decision:$d, owner:$o, at:$at, agreed:$a, note:$n}' "$F" > "$tmp" && mv "$tmp" "$F"
    echo "review: recorded $DECISION for $ID (agreed with AI: $AGREED)"
    exit 0
    ;;
esac

mkdir -p "$REVIEWS"
PACK_JSON="knowledge/pack.json"
SERVICES_JSON="loop/04-build/services.json"
ACTIVE_TITLES="[]"
[ -f "$PACK_JSON" ] && ACTIVE_TITLES="$(jq '[.items[].title]' "$PACK_JSON")"
SERVICE_NAMES="[]"
[ -f "$SERVICES_JSON" ] && SERVICE_NAMES="$(jq '[.services[].name]' "$SERVICES_JSON")"

SUMMARY="$REVIEWS/SUMMARY.md"
{
  echo "# Proposal review — $(date -u +%FT%TZ)"
  echo
  echo "| Proposal | Suggestion | Confidence | Risk | Reasons |"
  echo "|---|---|---|---|---|"
} > "$SUMMARY"

write_review() { # file
  local prop="$1"
  local id title statement repeat_count prov
  id="$(jq -r '.id' "$prop")"
  title="$(jq -r '.title // ""' "$prop")"
  statement="$(jq -r '.statement // ""' "$prop")"
  repeat_count="$(jq -r '.repeatCount // 1' "$prop")"
  prov="$(jq -r '[.provenance[]?]|join(",")' "$prop")"

  local norm; norm="$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' ' ' | sed 's/^ *//; s/ *$//')"
  local duplicate="false"
  if [ "$(printf '%s' "$ACTIVE_TITLES" | jq --arg t "$norm" '[.[]|select((.|ascii_downcase)=$t)]|length')" != "0" ]; then duplicate="true"; fi

  local risk="low"
  printf '%s %s' "$title" "$statement" | grep -qiE 'secret|credential|auth|token|pii|gdpr|payment|money|prod|production|schema|migration|contract|security' && risk="high"
  printf '%s %s' "$title" "$statement" | grep -qiE 'architect|layer|module|database|api' && [ "$risk" = "low" ] && risk="medium"

  local service=""
  local name
  for name in $(printf '%s' "$SERVICE_NAMES" | jq -r '.[]'); do
    case "$id" in "P-$name-"*) service="$name"; break ;; esac
  done
  [ -z "$service" ] && service="$(printf '%s' "$id" | sed -E 's/^P-([a-z0-9-]+)-.*/\1/')"

  # Gate evidence: distinctive tokens from the title found in hooks/scripts/skills.
  local tokens=() hits=() tok
  while IFS= read -r tok; do tokens+=("$tok"); done < <(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | grep -oE '[a-z][a-z0-9-]{4,}' | sort -u | head -4)
  for tok in "${tokens[@]:-}"; do
    [ -n "$tok" ] || continue
    if grep -rqi -- "$tok" hooks .githooks scripts .agents/skills 2>/dev/null; then hits+=("$tok"); fi
  done

  local suggestion confidence reasons="[]"
  add_reason() { reasons="$(printf '%s' "$reasons" | jq --arg r "$1" '. + [$r]')"; }
  if [ "$duplicate" = "true" ]; then
    suggestion="reject-duplicate"; confidence="high"; add_reason "an active pack item already carries this title"
  elif [ "$risk" = "high" ]; then
    suggestion="promote-deterministic"; confidence="low"; add_reason "high-risk domain: needs a named security/ops owner and a deterministic gate"
  elif [ "$repeat_count" -ge 2 ] && [ "${#hits[@]}" -gt 0 ]; then
    suggestion="promote-deterministic"; confidence="high"; add_reason "repeated ${repeat_count}x and gate tooling already mentions: ${hits[*]}"
  elif [ "${#hits[@]}" -ge 2 ] && printf '%s %s' "$title" "$statement" | grep -qiE '必须|禁止|不得|never|must|always'; then
    suggestion="promote-deterministic"; confidence="medium"; add_reason "normative wording and existing gate tooling mentions: ${hits[*]}"
  elif [ "$repeat_count" -ge 2 ]; then
    suggestion="promote-advisory"; confidence="medium"; add_reason "repeated ${repeat_count}x but no deterministic gate detected yet"
  else
    suggestion="defer"; confidence="low"; add_reason "single occurrence with no gate evidence: register debt or wait for a repeat"
  fi

  local review="$REVIEWS/$id.json"
  if [ -f "$review" ]; then
    local keep; keep="$(jq '.human' "$review")"
    jq --arg at "$NOW" --arg s "$suggestion" --arg c "$confidence" --arg r "$risk" --argjson reasons "$reasons" \
      --argjson hits "$(printf '%s\n' "${hits[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
      --arg svc "$service" --argjson repeat "$repeat_count" --argjson human "$keep" \
      '.generatedAt=$at | .ai={suggestion:$s,confidence:$c,risk:$r,reasons:$reasons,gateHits:$hits,service:$svc,repeatCount:$repeat} | .human=$human' \
      "$review" > "$review.tmp" && mv "$review.tmp" "$review"
  else
    jq -n --arg id "$id" --arg at "$NOW" --arg s "$suggestion" --arg c "$confidence" --arg r "$risk" \
      --argjson reasons "$reasons" --argjson hits "$(printf '%s\n' "${hits[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
      --arg svc "$service" --argjson repeat "$repeat_count" \
      '{apiVersion:"sdlc/v1",kind:"ProposalReview",proposalId:$id,generatedAt:$at,
        ai:{suggestion:$s,confidence:$c,risk:$r,reasons:$reasons,gateHits:$hits,service:$svc,repeatCount:$repeat},human:null}' > "$review"
  fi
  {
    printf '| %s | %s | %s | %s | %s |\n' "$id" "$suggestion" "$confidence" "$risk" "$(printf '%s' "$reasons" | jq -r 'join("; ")')"
  } >> "$SUMMARY"
  echo "review: $id -> $suggestion ($confidence, risk=$risk)"
}

shopt -s nullglob
found=0
for prop in "$PROPOSALS"/*.json; do
  [ -f "$prop" ] || continue
  found=$((found+1))
  write_review "$prop"
done
[ "$found" -eq 0 ] && echo "review: no proposals" && exit 0
echo "review: $found proposal(s), summary -> $SUMMARY"
