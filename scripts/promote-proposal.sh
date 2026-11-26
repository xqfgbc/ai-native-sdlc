#!/usr/bin/env bash
# scripts/promote-proposal.sh — the human sign-off gate for project-level cognition (D19).
# A policy owner promotes a proposal from knowledge/proposals/ to an active item in
# knowledge/pack.json (bumping the pack version). AI/analyzer never calls this; a human does.
# Usage: scripts/promote-proposal.sh <management-repo> <proposal-id> <owner>
set -euo pipefail
MGMT="${1:-}"; ID="${2:-}"; OWNER="${3:-}"; ENFORCEMENT="${4:-advisory}"
[ -n "$MGMT" ] && [ -n "$ID" ] && [ -n "$OWNER" ] || {
  echo "Usage: $0 <management-repo> <proposal-id> <owner> [advisory|deterministic]" >&2; exit 1; }
case "$ENFORCEMENT" in advisory|deterministic) ;; *) echo "enforcement must be advisory|deterministic" >&2; exit 1 ;; esac
cd "$MGMT"
PROP="knowledge/proposals/${ID}.json"
[ -f "$PROP" ] || { echo "ERROR: proposal not found: $PROP" >&2; exit 1; }
[ -f knowledge/pack.json ] || { echo "ERROR: missing knowledge/pack.json" >&2; exit 1; }

TYPE="$(jq -r .type "$PROP")"
case "$TYPE" in
  constraint) TYPE_DIR="constraints" ;;
  skill) TYPE_DIR="skills" ;;
  lesson) TYPE_DIR="lessons" ;;
  context) TYPE_DIR="context" ;;
  *) TYPE_DIR="${TYPE}s" ;;
esac
TITLE="$(jq -r .title "$PROP")"
STMT="$(jq -r .statement "$PROP")"

# Append as an active item to the pack.
jq --arg id "$ID" --arg type "$TYPE" --arg dir "$TYPE_DIR" --arg title "$TITLE" --arg stmt "$STMT" --arg owner "$OWNER" --arg enf "$ENFORCEMENT" '
  .items += [{
    id: $id, type: $type, scope: "project", title: $title, statement: $stmt,
    owner: $owner, status: "active", enforcement: $enf,
    provenance: [], path: ("knowledge/" + $dir + "/" + $id + ".md")
  }]' knowledge/pack.json > knowledge/pack.json.tmp

# Bump patch version (x.y.z -> x.y.(z+1)).
VER="$(jq -r '.metadata.version' knowledge/pack.json)"
MAJOR="${VER%%.*}"; REST="${VER#*.}"; MINOR="${REST%%.*}"; PATCH="${REST#*.}"
NEW="$MAJOR.$MINOR.$((PATCH + 1))"
jq --arg v "$NEW" '.metadata.version = $v' knowledge/pack.json.tmp > knowledge/pack.json
rm -f knowledge/pack.json.tmp

# Materialize the item and retire the proposal.
mkdir -p "knowledge/$TYPE_DIR"
jq --arg owner "$OWNER" --arg enf "$ENFORCEMENT" '.status = "active" | .owner = $owner | .enforcement = $enf' "$PROP" > "knowledge/$TYPE_DIR/$ID.json"
rm -f "$PROP"

# Environment-over-instructions (poteto): deterministic constraints need a guardrail, not prose.
if [ "$ENFORCEMENT" = "deterministic" ]; then
  mkdir -p knowledge/guardrails
  cat > "knowledge/guardrails/$ID.md" <<EOF
# Guardrail $ID

$STMT

## Enforce it in code (do this, not another prompt)
- Add a deterministic gate that fails on violation: hook / ArchUnit rule / lint rule / CI check.
- Reference the rule from AGENTS.md and the relevant service repo skill.
- Remove this stub once the gate exists (the pack item's \`enforcement\` stays \`deterministic\`).
EOF
  echo "promoted $ID ($TYPE) by $OWNER -> pack v$NEW, enforcement=deterministic (guardrail stub: knowledge/guardrails/$ID.md)"
else
  echo "promoted $ID ($TYPE) by $OWNER -> pack v$NEW, enforcement=advisory"
fi
