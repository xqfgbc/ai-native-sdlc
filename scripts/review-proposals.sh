#!/usr/bin/env bash
# scripts/review-proposals.sh — AI pre-judgement for knowledge proposals (never activates).
#
# Usage:
#   review-proposals.sh [<management-repo>]            # write knowledge/reviews/<id>.json + SUMMARY.md
#   review-proposals.sh stats                          # agreement rate from recorded human decisions
#   review-proposals.sh record <proposal-id> --decision promote-deterministic|promote-advisory|debt|reject \
#        --owner <name> [--note text]
#   review-proposals.sh cluster [--json]               # group proposals that duplicate an active item
#                                                      # (shared distinctive tokens) and mark the review
#                                                      # suggestion reject-duplicate. Never activates.
#
# The suggestion is advisory: a human still signs via signoff.py / promote-proposal.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MGMT="${1:-.}"
[ "$MGMT" = "stats" ] || [ "$MGMT" = "record" ] || [ "$MGMT" = "cluster" ] || true
if [ "${1:-}" = "stats" ] || [ "${1:-}" = "record" ] || [ "${1:-}" = "cluster" ]; then
  MGMT="."
else
  MGMT="${1:-.}"
fi
cd "$MGMT"
MGMT_ABS="$(pwd)"
REVIEWS="knowledge/reviews"
PROPOSALS="knowledge/proposals"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
# Semantic duplicate signal: shared distinctive ASCII tokens. CJK titles have no
# reliable tokenizer here, so those stay "unique" and a human decides.
TOK_STOP='the|and|for|with|use|must|only|from|into|not|are|was|has|have|all|any|its'
tokens_of() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
    | grep -oE '[a-z][a-z0-9]{2,}' | grep -vxE "$TOK_STOP" | sort -u || true
}
shared_of() {
  comm -12 <(printf '%s' "$1" | grep -v '^$' | sort -u) \
           <(printf '%s' "$2" | grep -v '^$' | sort -u) || true
}

case "${1:-}" in
  cluster)
    JSON_OUT=0; [ "${2:-}" = "--json" ] && JSON_OUT=1
    PACK_JSON="knowledge/pack.json"
    [ -f "$PACK_JSON" ] || { echo "review: missing $PACK_JSON" >&2; exit 1; }
    CLUSTERS="[]"; UNIQUE="[]"
    shopt -s nullglob
    for prop in knowledge/proposals/*.json; do
      [ -f "$prop" ] || continue
      pid="$(jq -r '.id' "$prop")"
      ptitle="$(jq -r '.title // ""' "$prop")"
      ptoks="$(tokens_of "$ptitle")"
      if [ -z "$ptoks" ]; then
        UNIQUE="$(printf '%s' "$UNIQUE" | jq --arg id "$pid" '. + [$id]')"
        echo "cluster: $pid -> unique (no distinctive tokens)"
        continue
      fi

      best_id=""; best_title=""; best_shared=""
      while IFS=$'\t' read -r aid atitle; do
        [ -n "$aid" ] || continue
        shared="$(shared_of "$ptoks" "$(tokens_of "$atitle")")"
        n="$(printf '%s\n' "$shared" | grep -c . 2>/dev/null || true)"
        if [ "$n" -ge 2 ]; then
          best_id="$aid"; best_title="$atitle"; best_shared="$shared"
          break
        fi
      done <<< "$(jq -r '.items[]?|select(.status=="active")|"\(.id)\t\(.title)"' "$PACK_JSON" 2>/dev/null || true)"

      if [ -n "$best_id" ]; then
        tokens_json="$(printf '%s\n' "$best_shared" | jq -R -s 'split("\n")|map(select(length>0))')"
        CLUSTERS="$(printf '%s' "$CLUSTERS" | jq \
          --arg pid "$pid" --arg cid "$best_id" --arg ctitle "$best_title" --argjson toks "$tokens_json" \
          '. + [{kind:"active-duplicate", canonical:{source:"pack",id:$cid,title:$ctitle},
                 members:[{id:$pid,sharedTokens:$toks}]}]')"
        # Advisory only: flag the review, never resolve or activate anything.
        mkdir -p knowledge/reviews
        RF="knowledge/reviews/$pid.json"
        if [ ! -f "$RF" ]; then
          jq -n --arg id "$pid" --arg at "$NOW" --arg cid "$best_id" --argjson toks "$tokens_json" \
            '{apiVersion:"sdlc/v1",kind:"ProposalReview",proposalId:$id,generatedAt:$at,
              ai:{suggestion:"reject-duplicate",confidence:"high",risk:"low",
                  reasons:["an active item already covers this: "+$cid],gateHits:[],
                  service:"",repeatCount:1,duplicateOf:$cid,sharedTokens:$toks},human:null}' > "$RF"
        else
          tmp="$(mktemp)"
          jq --arg cid "$best_id" --argjson toks "$tokens_json" \
            'if .human != null then . else
               .ai.suggestion="reject-duplicate" | .ai.confidence="high"
               | .ai.duplicateOf=$cid | .ai.sharedTokens=$toks
               | .ai.reasons=(((.ai.reasons // []) + ["an active item already covers this: "+$cid]) | unique)
             end' "$RF" > "$tmp" && mv "$tmp" "$RF"
        fi
        echo "cluster: $pid -> duplicate of active $best_id ($(printf '%s' "$best_shared" | paste -sd, -))"
      else
        UNIQUE="$(printf '%s' "$UNIQUE" | jq --arg id "$pid" '. + [$id]')"
        echo "cluster: $pid -> unique"
      fi
    done

    REPORT="$(jq -n --arg at "$NOW" --argjson clusters "$CLUSTERS" --argjson unique "$UNIQUE" \
      '{apiVersion:"sdlc/v1",kind:"ProposalClusters",generatedAt:$at,clusters:$clusters,unique:$unique}')"
    mkdir -p knowledge/reviews
    printf '%s\n' "$REPORT" > knowledge/reviews/clusters.json
    {
      echo "# Proposal clusters — $NOW"; echo
      echo "## Duplicate of an active item"; echo
      echo "| Proposal | Active item | Shared tokens |"; echo "|---|---|---|"
      printf '%s' "$REPORT" | jq -r '.clusters[] | .canonical as $c | .members[] | "| \(.id) | \($c.id) | \(.sharedTokens|join(", ")) |"'
      echo; echo "## Unique"; echo
      printf '%s' "$REPORT" | jq -r '.unique[] | "- \(.)"'
    } > knowledge/reviews/clusters.md
    if [ "$JSON_OUT" = 1 ]; then
      printf '%s\n' "$REPORT"
    else
      echo "cluster: $(printf '%s' "$REPORT" | jq '.clusters|length') duplicate(s), $(printf '%s' "$REPORT" | jq '.unique|length') unique -> knowledge/reviews/clusters.{json,md}"
    fi
    exit 0
    ;;
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

# Gate evidence is looked for in the control plane tooling and in each service's
# main/gate files, not in arbitrary test code.
SEARCH_PATHS=(hooks .githooks scripts)
if [ -f "$SERVICES_JSON" ]; then
  while IFS= read -r repo; do
    [ -n "$repo" ] || continue
    local_path="$repo"
    if [ ! -d "$local_path" ] && [ "${repo#*/}" != "$repo" ]; then
      local_path="$(dirname "$MGMT_ABS")/${repo##*/}"
    fi
    [ -d "$local_path" ] || continue
    for sub in src/main hooks scripts; do
      [ -e "$local_path/$sub" ] && SEARCH_PATHS=("${SEARCH_PATHS[@]}" "$local_path/$sub")
    done
    while IFS= read -r arch; do
      [ -n "$arch" ] && SEARCH_PATHS=("${SEARCH_PATHS[@]}" "$arch")
    done <<< "$(find "$local_path/src/test" -name ArchitectureTest.java 2>/dev/null || true)"
  done <<< "$(jq -r '.services[].repo' "$SERVICES_JSON")"
fi

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
  local duplicate="false" dup_of=""
  if [ -f "$PACK_JSON" ]; then
    if jq -e --arg t "$norm" \
        '[.items[]|select((.title|ascii_downcase)==$t)]|length>0' "$PACK_JSON" >/dev/null 2>&1; then
      duplicate="true"
    else
      local pid_tokens; pid_tokens="$(tokens_of "$title")"
      if [ -n "$pid_tokens" ]; then
        while IFS=$'\t' read -r aid atitle; do
          [ -n "$aid" ] || continue
          local shared_n
          shared_n="$(shared_of "$pid_tokens" "$(tokens_of "$atitle")" | grep -c . 2>/dev/null || true)"
          if [ "$shared_n" -ge 2 ]; then duplicate="true"; dup_of="$aid"; break; fi
        done <<< "$(jq -r '.items[]?|select(.status=="active")|"\(.id)\t\(.title)"' "$PACK_JSON" 2>/dev/null || true)"
      fi
    fi
  fi

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
    if grep -rqi -- "$tok" "${SEARCH_PATHS[@]}" 2>/dev/null; then hits+=("$tok"); fi
  done

  local suggestion confidence reasons="[]"
  add_reason() { reasons="$(printf '%s' "$reasons" | jq --arg r "$1" '. + [$r]')"; }
  if [ "$duplicate" = "true" ]; then
    suggestion="reject-duplicate"; confidence="high"
    add_reason "an active item already covers this${dup_of:+: $dup_of}"
  elif [ "$risk" = "high" ]; then
    suggestion="promote-deterministic"; confidence="low"; add_reason "high-risk domain: needs a named security/ops owner and a deterministic gate"
  elif [ "$repeat_count" -ge 2 ] && [ "${#hits[@]}" -gt 0 ]; then
    suggestion="promote-deterministic"; confidence="high"; add_reason "repeated ${repeat_count}x and gate tooling already mentions: ${hits[*]}"
  elif [ "${#hits[@]}" -ge 3 ]; then
    suggestion="promote-deterministic"; confidence="medium"; add_reason "existing gate tooling already implements: ${hits[*]}"
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
