#!/usr/bin/env bash
# scripts/sync-cognition-remote.sh — distribute the cognition pack to a service repo
# that is not available locally: clone, pin the version, push a branch and open a PR.
#
# Usage: sync-cognition-remote.sh <management-repo> <org/repo> [--dry-run]
#
# Transport preflight:
#   1. gh installed + authenticated            -> gh CLI path
#   2. GH_TOKEN / GITHUB_TOKEN present         -> git + GitHub REST API path (no gh)
#   3. neither                                 -> prints install / web-edit instructions, exit 2
# Test the fallback with SDL_FORCE_NO_GH=1.
set -euo pipefail
MGMT="${1:-}"; REPO="${2:-}"; DRY=0
[ "${3:-}" = "--dry-run" ] && DRY=1
[ -n "$MGMT" ] && [ -n "$REPO" ] || { echo "Usage: $0 <management-repo> <org/repo> [--dry-run]" >&2; exit 1; }
[ -f "$MGMT/knowledge/pack.json" ] || { echo "ERROR: missing $MGMT/knowledge/pack.json" >&2; exit 1; }
MGMT_ABS="$(cd "$MGMT" && pwd)"
PACK="$MGMT_ABS/knowledge/pack.json"
VER="$(jq -r '.metadata.version' "$PACK")"
BRANCH="sync/cognition-pack-v${VER}"
TITLE="chore(cognition): adopt pack v${VER}"
BODY="Cognition pack v${VER} from the project control plane. This PR pins \`.sdlc/cognition-pack.json\` and \`service.json\`; review the pack diff before merging."

TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
GH_OK=0
if [ "${SDL_FORCE_NO_GH:-0}" != "1" ] && command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  GH_OK=1
fi
TRANSPORT="none"
[ "$GH_OK" = "1" ] && TRANSPORT="gh"
[ "$GH_OK" = "0" ] && [ -n "$TOKEN" ] && TRANSPORT="token"

guidance() {
  cat >&2 <<EOF
sync-remote: need a way to push a branch and open a PR for $REPO.
  A) install and log in to gh:   brew install gh && gh auth login
  B) provide a token:            export GH_TOKEN=<fine-grained PAT with repo scope>
  C) edit in the web UI (manual, two files):
     https://github.com/$REPO/edit/<default-branch>/.sdlc/cognition-pack.json
     https://github.com/$REPO/edit/<default-branch>/service.json   (set cognitionPack.version = "$VER")
     package source: $PACK
EOF
}

if [ "$TRANSPORT" = "none" ]; then
  if [ "$DRY" = "1" ]; then
    echo "dry-run: transport=none (no gh, no GH_TOKEN)"; guidance; exit 0
  fi
  guidance; exit 2
fi

if [ "$DRY" = "1" ]; then
  echo "dry-run: repo=$REPO base=<default branch> pack=v$VER transport=$TRANSPORT"
  if [ "$TRANSPORT" = "gh" ]; then
    echo "dry-run: gh repo clone $REPO <tmp> -- --depth 1 --branch <default>"
    echo "dry-run: gh pr create --repo $REPO --base <default> --head $BRANCH --title \"$TITLE\""
  else
    echo "dry-run: git clone https://github.com/$REPO.git (Authorization header from GH_TOKEN)"
    echo "dry-run: curl -X POST https://api.github.com/repos/$REPO/pulls (Authorization: Bearer \$GH_TOKEN)"
  fi
  echo "dry-run: copy knowledge/pack.json -> .sdlc/cognition-pack.json"
  echo "dry-run: jq '.cognitionPack.version=\"$VER\"' service.json"
  echo "dry-run: git commit -m \"[AI-Agent] #N/A chore: adopt cognition pack v$VER\""
  echo "dry-run: git push -u origin $BRANCH"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
AUTH=""
if [ "$TRANSPORT" = "token" ]; then
  AUTH="$(printf 'x-access-token:%s' "$TOKEN" | base64 | tr -d '\n')"
  BASE="$(curl -fsS -H "Authorization: Bearer $TOKEN" "https://api.github.com/repos/$REPO" | jq -r '.default_branch // empty')"
  [ -n "$BASE" ] || { echo "ERROR: cannot resolve default branch for $REPO via API" >&2; exit 1; }
  git -c "http.extraheader=Authorization: Basic $AUTH" clone --depth 1 --branch "$BASE" --quiet \
    "https://github.com/$REPO.git" "$TMP/svc"
else
  BASE="$(gh repo view "$REPO" --json defaultBranchRef --jq '.defaultBranchRef.name')"
  [ -n "$BASE" ] || { echo "ERROR: cannot resolve default branch for $REPO" >&2; exit 1; }
  gh repo clone "$REPO" "$TMP/svc" -- --depth 1 --branch "$BASE" --quiet
fi

SVC="$TMP/svc"
[ -f "$SVC/service.json" ] || { echo "ERROR: $REPO is not a service repo (no service.json)" >&2; exit 1; }
SVC_NAME="$(jq -r '.name // empty' "$SVC/service.json")"

# Registry bookkeeping: the pinned version only becomes the adopted one once the PR
# merges, so record it as pending until then (validate-project.sh checks drift on
# local clones only). Best effort: silently skip when the service is unregistered.
REG="$MGMT_ABS/loop/04-build/services.json"
registry_set() { # adopted|pending <version> [pr-url]
  local mode="$1" v="$2" pr="${3:-}" at
  [ -f "$REG" ] && [ -n "$SVC_NAME" ] || return 0
  jq -e --arg n "$SVC_NAME" '[.services[]|select(.name==$n)]|length>0' "$REG" >/dev/null 2>&1 || return 0
  at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [ "$mode" = "adopted" ]; then
    jq --arg n "$SVC_NAME" --arg v "$v" --arg at "$at" \
      '(.services[]|select(.name==$n)) |= (.cognitionPack.version=$v
        | del(.cognitionPack.pendingVersion, .cognitionPack.pendingPr) | .updatedAt=$at)' \
      "$REG" > "$REG.tmp" && mv "$REG.tmp" "$REG"
  else
    jq --arg n "$SVC_NAME" --arg v "$v" --arg pr "$pr" --arg at "$at" \
      '(.services[]|select(.name==$n)) |= (.cognitionPack.pendingVersion=$v
        | .cognitionPack.pendingPr=$pr | .updatedAt=$at)' \
      "$REG" > "$REG.tmp" && mv "$REG.tmp" "$REG"
  fi
  echo "registry: $SVC_NAME $mode cognition pack v$v${pr:+ ($pr)}"
}

mkdir -p "$SVC/.sdlc"
cp "$PACK" "$SVC/.sdlc/cognition-pack.json"
tmp="$(mktemp)"; jq --arg v "$VER" '.cognitionPack.version = $v' "$SVC/service.json" > "$tmp" && mv "$tmp" "$SVC/service.json"

cd "$SVC"
if [ -z "$(git status --porcelain)" ]; then
  registry_set adopted "$VER"
  echo "sync-remote: $REPO already at cognition pack v$VER"
  exit 0
fi
git checkout -q -b "$BRANCH"
git add .sdlc/cognition-pack.json service.json
git -c user.name="AI-Agent" -c user.email="ai-agent@users.noreply.github.com" \
  commit -q -m "[AI-Agent] #N/A chore: adopt cognition pack v$VER"

if [ "$TRANSPORT" = "gh" ]; then
  git push -q -u origin "$BRANCH"
  PR_URL="$(gh pr create --repo "$REPO" --base "$BASE" --head "$BRANCH" --title "$TITLE" --body "$BODY")"
else
  git -c "http.extraheader=Authorization: Basic $AUTH" push -q -u origin "$BRANCH"
  PR_URL="$(curl -fsS -X POST "https://api.github.com/repos/$REPO/pulls" \
    -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
    -d "$(jq -n --arg t "$TITLE" --arg h "$BRANCH" --arg b "$BASE" --arg body "$BODY" \
      '{title:$t, head:$h, base:$b, body:$body}')" | jq -r '.html_url // empty')"
fi
registry_set pending "$VER" "${PR_URL:-}"
echo "sync-remote: ${PR_URL:-pushed branch $BRANCH (PR creation returned no URL)}"
