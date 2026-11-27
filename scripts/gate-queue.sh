#!/usr/bin/env bash
# scripts/gate-queue.sh — deterministic gate work queue (control plane).
#
# A signed deterministic rule is not "done" until a gate exists. This queue is the
# AI-callable work list: promote-proposal.sh enqueues, an agent claims, implements
# the gate in the authoring repo, and closes with evidence.
#
# Usage:
#   gate-queue.sh add --proposal <id> --title <t> [--repo <authoring>] [--applies-to a,b]
#                [--priority P1|P2|P3] [--json]
#   gate-queue.sh list [--status open|in-progress|done|blocked] [--json]
#   gate-queue.sh show <id> [--json]
#   gate-queue.sh claim <id> --owner <name> [--json]
#   gate-queue.sh done <id> --evidence <text> [--json]
#   gate-queue.sh block <id> --reason <text> [--json]
#   gate-queue.sh path
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
MGMT="$ROOT"
if [ -f "$ROOT/.sdlc/config.json" ]; then
  cand="$(jq -r '.managementRepo // empty' "$ROOT/.sdlc/config.json" 2>/dev/null || true)"
  [ -n "$cand" ] && [ -d "$cand" ] && MGMT="$cand"
fi
FILE="$MGMT/loop/04-build/gates/queue.json"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

init() {
  mkdir -p "$(dirname "$FILE")"
  [ -f "$FILE" ] || printf '%s\n' '{"apiVersion":"sdlc/v1","kind":"GateQueue","updatedAt":"'"$NOW"'","items":[]}' > "$FILE"
}
write_registry() { # jq filter + args
  local filter="$1"; shift
  local tmp; tmp="$(mktemp)"
  jq --arg now "$NOW" "$@" "$filter | .updatedAt=\$now" "$FILE" > "$tmp" && mv "$tmp" "$FILE"
}

cmd="${1:-}"; shift || true
if [ "$cmd" = "path" ]; then init; echo "$FILE"; exit 0; fi
[ -n "$cmd" ] || { sed -n '2,20p' "$0" >&2; exit 1; }
init

case "$cmd" in
  add)
    PROP=""; TITLE=""; REPO="control-plane"; APPLIES=""; PRIORITY="P1"; JSON=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --proposal) PROP="${2:-}"; shift 2 ;;
        --title) TITLE="${2:-}"; shift 2 ;;
        --repo) REPO="${2:-}"; shift 2 ;;
        --applies-to) APPLIES="${2:-}"; shift 2 ;;
        --priority) PRIORITY="${2:-}"; shift 2 ;;
        --json) JSON=1; shift ;;
        *) echo "gate-queue: unknown option $1" >&2; exit 1 ;;
      esac
    done
    [ -n "$PROP" ] && [ -n "$TITLE" ] || { echo "gate-queue: add needs --proposal and --title" >&2; exit 1; }
    case "$PRIORITY" in P1|P2|P3) ;; *) echo "gate-queue: priority must be P1|P2|P3" >&2; exit 1 ;; esac
    ID="G-$PROP"
    APPLIES_JSON="$(printf '%s' "$APPLIES" | jq -R 'split(",")|map(select(length>0))')"
    if jq -e --arg id "$ID" '[.items[]|select(.id==$id)]|length>0' "$FILE" >/dev/null 2>&1; then
      if [ "$JSON" = 1 ]; then jq --arg id "$ID" '.items[]|select(.id==$id)' "$FILE"
      else echo "gate-queue: $ID already queued"; fi
      exit 0
    fi
    write_registry '.items += [{id:$id,proposalId:$prop,title:$title,authoringRepo:$repo,
      appliesTo:$applies,priority:$priority,status:"open",owner:"",evidence:"",
      createdAt:$now,updatedAt:$now}]' \
      --arg id "$ID" --arg prop "$PROP" --arg title "$TITLE" --arg repo "$REPO" \
      --argjson applies "$APPLIES_JSON" --arg priority "$PRIORITY"
    if [ "$JSON" = 1 ]; then jq --arg id "$ID" '.items[]|select(.id==$id)' "$FILE"
    else echo "gate-queue: queued $ID ($PRIORITY) $TITLE"; fi
    ;;
  list)
    STATUS=""; JSON=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --status) STATUS="${2:-}"; shift 2 ;;
        --json) JSON=1; shift ;;
        *) echo "gate-queue: unknown option $1" >&2; exit 1 ;;
      esac
    done
    if [ "$JSON" = 1 ]; then
      jq --arg st "$STATUS" '[.items[]|select($st=="" or .status==$st)]|sort_by(.priority,.createdAt)' "$FILE"
    else
      jq -r --arg st "$STATUS" '.items[]|select($st=="" or .status==$st)
        |"\(.id)  \(.priority)  \(.status)  \(.authoringRepo)  \(.title)"' "$FILE"
    fi
    ;;
  show)
    ID="${1:-}"; JSON=0; [ "${2:-}" = "--json" ] && JSON=1
    [ -n "$ID" ] || { echo "gate-queue: show needs an id" >&2; exit 1; }
    if [ "$JSON" = 1 ]; then jq --arg id "$ID" '.items[]|select(.id==$id)' "$FILE"
    else jq -r --arg id "$ID" '.items[]|select(.id==$id)
      |"\(.id)\n  status: \(.status)\n  repo: \(.authoringRepo)\n  appliesTo: \([.appliesTo[]]|join(", "))\n  evidence: \(.evidence // "")\n  owner: \(.owner // "")"' "$FILE"; fi
    ;;
  claim)
    ID="${1:-}"; shift || true; OWNER=""; JSON=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --owner) OWNER="${2:-}"; shift 2 ;;
        --json) JSON=1; shift ;;
        *) echo "gate-queue: unknown option $1" >&2; exit 1 ;;
      esac
    done
    [ -n "$ID" ] && [ -n "$OWNER" ] || { echo "gate-queue: claim needs <id> --owner" >&2; exit 1; }
    write_registry '(.items[]|select(.id==$id)) |= (.status="in-progress" | .owner=$owner)' --arg id "$ID" --arg owner "$OWNER"
    if [ "$JSON" = 1 ]; then jq --arg id "$ID" '.items[]|select(.id==$id)' "$FILE"; else echo "gate-queue: $ID in-progress ($OWNER)"; fi
    ;;
  done)
    ID="${1:-}"; shift || true; EVIDENCE=""; JSON=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --evidence) EVIDENCE="${2:-}"; shift 2 ;;
        --json) JSON=1; shift ;;
        *) echo "gate-queue: unknown option $1" >&2; exit 1 ;;
      esac
    done
    [ -n "$ID" ] && [ -n "$EVIDENCE" ] || { echo "gate-queue: done needs <id> --evidence" >&2; exit 1; }
    write_registry '(.items[]|select(.id==$id)) |= (.status="done" | .evidence=$ev | .closedAt=$now)' --arg id "$ID" --arg ev "$EVIDENCE"
    if [ "$JSON" = 1 ]; then jq --arg id "$ID" '.items[]|select(.id==$id)' "$FILE"; else echo "gate-queue: closed $ID"; fi
    ;;
  block)
    ID="${1:-}"; shift || true; REASON=""; JSON=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --reason) REASON="${2:-}"; shift 2 ;;
        --json) JSON=1; shift ;;
        *) echo "gate-queue: unknown option $1" >&2; exit 1 ;;
      esac
    done
    [ -n "$ID" ] && [ -n "$REASON" ] || { echo "gate-queue: block needs <id> --reason" >&2; exit 1; }
    write_registry '(.items[]|select(.id==$id)) |= (.status="blocked" | .blockedReason=$r)' --arg id "$ID" --arg r "$REASON"
    if [ "$JSON" = 1 ]; then jq --arg id "$ID" '.items[]|select(.id==$id)' "$FILE"; else echo "gate-queue: blocked $ID"; fi
    ;;
  *) sed -n '2,20p' "$0" >&2; exit 1 ;;
esac
