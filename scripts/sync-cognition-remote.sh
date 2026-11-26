#!/usr/bin/env bash
# scripts/sync-cognition-remote.sh — distribute the cognition pack to a service repo
# that is not available locally: clone, pin the version, push a branch and open a PR.
#
# Usage: sync-cognition-remote.sh <management-repo> <org/repo> [--dry-run]
# Requires: gh authenticated with repo scope (GH_TOKEN or gh auth login).
set -euo pipefail
MGMT="${1:-}"; REPO="${2:-}"; DRY=0
[ "${3:-}" = "--dry-run" ] && DRY=1
[ -n "$MGMT" ] && [ -n "$REPO" ] || { echo "Usage: $0 <management-repo> <org/repo> [--dry-run]" >&2; exit 1; }
[ -f "$MGMT/knowledge/pack.json" ] || { echo "ERROR: missing $MGMT/knowledge/pack.json" >&2; exit 1; }
PACK="$(cd "$MGMT" && pwd)/knowledge/pack.json"
VER="$(jq -r '.metadata.version' "$PACK")"
BRANCH="sync/cognition-pack-v${VER}"
TITLE="chore(cognition): adopt pack v${VER}"
BODY="Cognition pack v${VER} from the project control plane. This PR pins \`.sdlc/cognition-pack.json\` and \`service.json\`; review the pack diff before merging."

if [ "$DRY" = "1" ]; then
  echo "dry-run: repo=$REPO base=<default branch> pack=v$VER"
  echo "dry-run: gh repo clone $REPO <tmp> -- --depth 1 --branch <default>"
  echo "dry-run: copy knowledge/pack.json -> .sdlc/cognition-pack.json"
  echo "dry-run: jq '.cognitionPack.version=\"$VER\"' service.json"
  echo "dry-run: git commit -m \"[AI-Agent] #N/A chore: adopt cognition pack v$VER\""
  echo "dry-run: git push -u origin $BRANCH"
  echo "dry-run: gh pr create --repo $REPO --base <default> --head $BRANCH --title \"$TITLE\""
  exit 0
fi

command -v gh >/dev/null 2>&1 || { echo "ERROR: gh is required" >&2; exit 1; }
BASE="$(gh repo view "$REPO" --json defaultBranchRef --jq '.defaultBranchRef.name')"
[ -n "$BASE" ] || { echo "ERROR: cannot resolve default branch for $REPO" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
gh repo clone "$REPO" "$TMP/svc" -- --depth 1 --branch "$BASE" --quiet
SVC="$TMP/svc"
[ -f "$SVC/service.json" ] || { echo "ERROR: $REPO is not a service repo (no service.json)" >&2; exit 1; }

mkdir -p "$SVC/.sdlc"
cp "$PACK" "$SVC/.sdlc/cognition-pack.json"
tmp="$(mktemp)"; jq --arg v "$VER" '.cognitionPack.version = $v' "$SVC/service.json" > "$tmp" && mv "$tmp" "$SVC/service.json"

cd "$SVC"
if [ -z "$(git status --porcelain)" ]; then
  echo "sync-remote: $REPO already at cognition pack v$VER"
  exit 0
fi
git checkout -q -b "$BRANCH"
git add .sdlc/cognition-pack.json service.json
git -c user.name="AI-Agent" -c user.email="ai-agent@users.noreply.github.com" \
  commit -q -m "[AI-Agent] #N/A chore: adopt cognition pack v$VER"
git push -q -u origin "$BRANCH"
PR_URL="$(gh pr create --repo "$REPO" --base "$BASE" --head "$BRANCH" \
  --title "$TITLE" --body "$BODY")"
echo "sync-remote: $PR_URL"
