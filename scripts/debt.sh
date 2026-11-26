#!/usr/bin/env bash
# scripts/debt.sh — project debt registry (works from the control plane or a service repo).
#
# Storage: <control-plane>/loop/07-maintain/debt/debt.json
# A service repo resolves the control plane from .sdlc/config.json (managementRepo).
#
# Usage:
#   debt.sh add --kind <k> --title <t> [--detail] [--source] [--ref] [--stage]
#               [--owner] [--priority P1|P2|P3] [--due YYYY-MM-DD] [--note] [--json]
#   debt.sh list [--status s] [--kind k] [--json]
#   debt.sh show <id> [--json]
#   debt.sh start <id> [--owner o]
#   debt.sh note <id> --text <text>
#   debt.sh close <id> [--note text]
#   debt.sh drop <id> --why <reason>
#   debt.sh due [--days N] [--json]        # due today or within N days, still open
#   debt.sh report [--out <file>]          # markdown summary (default stdout)
#   debt.sh path
#
# Kinds: intent|spec|design|build|test|deploy|ops|tech|security|process|proposal
# Sources: retro|proposal|incident|review|manual|finding
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
MGMT="$ROOT"
if [ -f "$ROOT/.sdlc/config.json" ]; then
  candidate="$(jq -r '.managementRepo // empty' "$ROOT/.sdlc/config.json" 2>/dev/null || true)"
  [ -n "$candidate" ] && [ -d "$candidate" ] && MGMT="$candidate"
fi
REG="$MGMT/loop/07-maintain/debt/debt.json"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TODAY="$(date -u +%Y-%m-%d)"

init() {
  mkdir -p "$(dirname "$REG")"
  [ -f "$REG" ] || printf '%s\n' '{"apiVersion":"sdlc/v1","kind":"DebtRegistry","updatedAt":"'"$NOW"'","items":[]}' > "$REG"
}

usage() { sed -n '2,24p' "$0" >&2; exit 1; }

cmd="${1:-}"; shift || true
case "$cmd" in
  path) init; echo "$REG"; exit 0 ;;
esac
[ -n "$cmd" ] || usage
init

KIND=""; TITLE=""; DETAIL=""; SOURCE="manual"; REF=""; STAGE=""; OWNER=""; PRIORITY="P2"; DUE=""; NOTE=""; JSON=0
STATUS_FILTER=""; KIND_FILTER=""; DAYS=0; OUT=""
ID=""

while [ $# -gt 0 ]; do
  case "$1" in
    --kind) KIND="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    --detail) DETAIL="$2"; shift 2 ;;
    --source) SOURCE="$2"; shift 2 ;;
    --ref) REF="$2"; shift 2 ;;
    --stage) STAGE="$2"; shift 2 ;;
    --owner) OWNER="$2"; shift 2 ;;
    --priority) PRIORITY="$2"; shift 2 ;;
    --due) DUE="$2"; shift 2 ;;
    --note) NOTE="$2"; shift 2 ;;
    --text) NOTE="$2"; shift 2 ;;
    --why) NOTE="$2"; shift 2 ;;
    --status) STATUS_FILTER="$2"; shift 2 ;;
    --days) DAYS="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -*) echo "debt: unknown option $1" >&2; usage ;;
    *) ID="$1"; shift ;;
  esac
done

write_registry() { # jq filter + args... (filter first)
  local filter="$1"; shift
  local tmp; tmp="$(mktemp)"
  jq --arg now "$NOW" "$@" "$filter | .updatedAt=\$now" "$REG" > "$tmp" && mv "$tmp" "$REG"
}

case "$cmd" in
  add)
    [ -n "$KIND" ] && [ -n "$TITLE" ] || { echo "debt: add needs --kind and --title" >&2; exit 1; }
    case "$KIND" in intent|spec|design|build|test|deploy|ops|tech|security|process|proposal) ;; *)
      echo "debt: invalid --kind '$KIND'" >&2; exit 1 ;; esac
    case "$PRIORITY" in P1|P2|P3) ;; *) echo "debt: priority must be P1|P2|P3" >&2; exit 1 ;; esac
    seq="$(jq --arg p "D-$(date -u +%Y%m%d)-" '[.items[]|select(.id|startswith($p))]|length+1' "$REG")"
    ID="$(printf 'D-%s-%03d' "$(date -u +%Y%m%d)" "$seq")"
    write_registry '.items += [{id:$id,kind:$kind,title:$title,detail:$detail,source:$source,ref:$ref,stage:$stage,owner:$owner,priority:$priority,status:"open",due:$due,createdAt:$now,updatedAt:$now,notes:(if $note=="" then [] else [{at:$now,text:$note}] end)}]' \
      --arg id "$ID" --arg kind "$KIND" --arg title "$TITLE" --arg detail "$DETAIL" --arg source "$SOURCE" \
      --arg ref "$REF" --arg stage "$STAGE" --arg owner "$OWNER" --arg priority "$PRIORITY" --arg due "$DUE" --arg note "$NOTE"
    if [ "$JSON" = 1 ]; then jq --arg id "$ID" '.items[]|select(.id==$id)' "$REG"; else echo "debt: added $ID ($PRIORITY $KIND) $TITLE"; fi
    ;;
  list)
    if [ "$JSON" = 1 ]; then
      jq --arg st "$STATUS_FILTER" --arg k "$KIND_FILTER" \
        '[.items[] | select(($st=="" or .status==$st) and ($k=="" or .kind==$k))] | sort_by(.priority, .due)' "$REG"
    else
      jq -r --arg st "$STATUS_FILTER" --arg k "$KIND_FILTER" \
        '.items | map(select(($st=="" or .status==$st) and ($k=="" or .kind==$k))) | sort_by(.priority, .due)
         | .[] | "\(.id)  \(.priority)  \(.status)  due=\(.due // "-")  \(.kind)  \(.title)"' "$REG"
    fi
    ;;
  show)
    [ -n "$ID" ] || { echo "debt: show needs an id" >&2; exit 1; }
    jq --arg id "$ID" '.items[]|select(.id==$id)' "$REG" || { echo "debt: not found $ID" >&2; exit 1; }
    ;;
  start)
    [ -n "$ID" ] || { echo "debt: start needs an id" >&2; exit 1; }
    write_registry '(.items[]|select(.id==$id)) |= (.status="in-progress" | .owner=(if $owner=="" then .owner else $owner end))' --arg id "$ID" --arg owner "$OWNER"
    echo "debt: $ID in-progress"
    ;;
  note)
    [ -n "$ID" ] && [ -n "$NOTE" ] || { echo "debt: note needs an id and --text" >&2; exit 1; }
    write_registry '(.items[]|select(.id==$id)) |= (.notes += [{at:$now,text:$note}] | .updatedAt=$now)' --arg id "$ID" --arg note "$NOTE"
    echo "debt: note added to $ID"
    ;;
  close)
    [ -n "$ID" ] || { echo "debt: close needs an id" >&2; exit 1; }
    write_registry '(.items[]|select(.id==$id)) |= (.status="done" | .closedAt=$now | .notes += (if $note=="" then [] else [{at:$now,text:$note}] end))' --arg id "$ID" --arg note "$NOTE"
    echo "debt: closed $ID"
    ;;
  drop)
    [ -n "$ID" ] && [ -n "$NOTE" ] || { echo "debt: drop needs an id and --why" >&2; exit 1; }
    write_registry '(.items[]|select(.id==$id)) |= (.status="dropped" | .closedAt=$now | .notes += [{at:$now,text:("dropped: "+$note)}])' --arg id "$ID" --arg note "$NOTE"
    echo "debt: dropped $ID"
    ;;
  due)
    limit="$(date -u -v+"${DAYS}"d +%Y-%m-%d 2>/dev/null || date -u -d "+${DAYS} days" +%Y-%m-%d)"
    if [ "$JSON" = 1 ]; then
      jq --arg today "$TODAY" --arg limit "$limit" \
        '[.items[] | select((.status=="open" or .status=="in-progress" or .status=="blocked") and (.due // "")!="" and .due<=$limit)] | sort_by(.due)' "$REG"
    else
      jq -r --arg today "$TODAY" --arg limit "$limit" \
        '.items | map(select((.status=="open" or .status=="in-progress" or .status=="blocked") and (.due // "")!="" and .due<=$limit)) | sort_by(.due)
         | .[] | "\(.id)  due=\(.due)  \(.priority)  \(.status)  \(.kind)  \(.title)"' "$REG"
    fi
    ;;
  report)
    report="$(
      echo "# Debt report — $TODAY"; echo
      echo "## Open by priority"; echo
      jq -r '[.items[]|select(.status=="open" or .status=="in-progress" or .status=="blocked")]|group_by(.priority)|.[]|"### \(.[0].priority) (\(length))","",(.[]|"- \(.id) [\(.kind)/\(.status)] due=\(.due // "-") — \(.title)") ,""' "$REG" 2>/dev/null | sed '/^$/N;/^\n$/D'
      echo "## Overdue / due soon"; echo
      jq -r --arg limit "$(date -u -v+7d +%Y-%m-%d 2>/dev/null || date -u -d '+7 days' +%Y-%m-%d)" \
        '.items[]|select((.status=="open" or .status=="in-progress" or .status=="blocked") and (.due // "")!="" and .due<=$limit)|"- \(.id) due=\(.due) \(.priority) — \(.title)"' "$REG"
    )"
    if [ -n "$OUT" ]; then printf '%s\n' "$report" > "$OUT"; echo "debt: report -> $OUT"; else printf '%s\n' "$report"; fi
    ;;
  *) usage ;;
esac
