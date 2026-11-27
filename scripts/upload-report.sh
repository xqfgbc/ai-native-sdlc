#!/usr/bin/env bash
# scripts/upload-report.sh — remote push channel (P2): open a PR adding one execution report
# to the management repo. No-op when remote config is absent, so it is safe to call from CI.
#
# Usage: upload-report.sh <org/management-repo> <report-file> <stage> <service> <toSha>
#                         [--base <branch>] [--dry-run] [--json]
#
# The base branch is detected from the repo's default branch unless --base is given;
# clone and PR creation always use the same branch (main is not assumed).
set -euo pipefail

BASE=""; DRY=0; JSON=0; ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE="${2:-}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --json) JSON=1; shift ;;
    -*) echo "upload-report: unknown option $1" >&2; exit 1 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
set -- ${ARGS[@]+"${ARGS[@]}"}
MGMT_REPO="${1:-}"; REPORT="${2:-}"; STAGE="${3:-}"; SERVICE="${4:-}"; SHA="${5:-}"

if [ -z "${GH_TOKEN:-}" ] || [ -z "$MGMT_REPO" ] || [ ! -f "${REPORT:-/nonexistent}" ]; then
  echo "upload-report: skipped (no GH_TOKEN/MANAGEMENT_REPO or report missing)"
  exit 0
fi
[ -n "$STAGE" ] && [ -n "$SERVICE" ] && [ -n "$SHA" ] || {
  echo "Usage: $0 <org/repo> <report-file> <stage> <service> <toSha> [--base <branch>] [--dry-run] [--json]" >&2
  exit 1; }

if [ -z "$BASE" ]; then
  BASE="$(gh repo view "$MGMT_REPO" --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || true)"
  [ -n "$BASE" ] || {
    echo "upload-report: cannot resolve the default branch of $MGMT_REPO (pass --base <branch>)" >&2
    exit 1; }
fi

if [ "$DRY" = "1" ]; then
  if [ "$JSON" = "1" ]; then
    jq -n --arg repo "$MGMT_REPO" --arg base "$BASE" --arg report "$REPORT" \
      --arg stage "$STAGE" --arg service "$SERVICE" --arg sha "$SHA" \
      '{repo:$repo,base:$base,report:$report,stage:$stage,service:$service,sha:$sha}'
  else
    echo "upload-report: dry-run repo=$MGMT_REPO base=$BASE report=$REPORT stage=$STAGE service=$SERVICE sha=$SHA"
  fi
  exit 0
fi

BR="sync/${SERVICE}/${SHA}"
F="execution/${STAGE}/${SERVICE}/reports/${SHA}.json"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

gh repo clone "$MGMT_REPO" "$TMP/m" -- --depth 1 --branch "$BASE" --quiet
cd "$TMP/m"
mkdir -p "$(dirname "$F")"
cp "$REPORT" "$F"
git checkout -q -b "$BR"
git add "$F"
git -c user.name="sdlc-bot" -c user.email="sdlc-bot@users.noreply.github.com" \
  commit -q -m "chore(report): ${SERVICE} ${SHA}"
git push -q -u origin "$BR"
gh pr create --repo "$MGMT_REPO" \
  --title "report: ${SERVICE} ${SHA}" \
  --body "Execution report from \`${SERVICE}\` at \`${SHA}\` (stage: ${STAGE}). Auto-generated; reports may auto-merge, cognition changes require human sign-off (D19)." \
  --head "$BR" --base "$BASE"
echo "upload-report: PR opened for ${SERVICE} ${SHA} (base ${BASE})"
