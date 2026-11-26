#!/usr/bin/env bash
# scripts/upload-report.sh — remote push channel (P2): open a PR adding one execution report
# to the management repo. No-op when remote config is absent, so it is safe to call from CI.
# Usage: upload-report.sh <org/management-repo> <report-file> <stage> <service> <toSha>
set -euo pipefail
MGMT_REPO="${1:-}"; REPORT="${2:-}"; STAGE="${3:-}"; SERVICE="${4:-}"; SHA="${5:-}"

if [ -z "${GH_TOKEN:-}" ] || [ -z "$MGMT_REPO" ] || [ ! -f "${REPORT:-/nonexistent}" ]; then
  echo "upload-report: skipped (no GH_TOKEN/MANAGEMENT_REPO or report missing)"
  exit 0
fi
[ -n "$STAGE" ] && [ -n "$SERVICE" ] && [ -n "$SHA" ] || {
  echo "Usage: $0 <org/repo> <report-file> <stage> <service> <toSha>" >&2; exit 1; }

BR="sync/${SERVICE}/${SHA}"
F="execution/${STAGE}/${SERVICE}/reports/${SHA}.json"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

gh repo clone "$MGMT_REPO" "$TMP/m" -- --depth 1 --branch main --quiet
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
  --head "$BR" --base main
echo "upload-report: PR opened for ${SERVICE} ${SHA}"
