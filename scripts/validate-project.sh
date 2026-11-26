#!/usr/bin/env bash
# scripts/validate-project.sh — validate a management repo's registry, reports, and pack.
# Usage: scripts/validate-project.sh [management-repo-dir]
set -euo pipefail
MGMT="${1:-.}"
cd "$MGMT"
fail=0
fail_msg() { echo "VALIDATE: $1" >&2; fail=1; }

# 1. services.json
REG="loop/04-build/services.json"
if [ ! -f "$REG" ]; then fail_msg "missing $REG"; else
  jq -e '.apiVersion == "sdlc/v1" and .kind == "ServiceRegistry" and (.services|type=="array")' "$REG" >/dev/null \
    || fail_msg "services.json invalid (apiVersion/kind/services)"
  jq -e '.services | all(has("name") and has("type") and has("repo") and has("phase") and has("requirements"))' "$REG" >/dev/null 2>&1 \
    || fail_msg "services.json: entry missing required fields"
fi

# 2. cognition pack
PACK="knowledge/pack.json"
if [ ! -f "$PACK" ]; then fail_msg "missing $PACK"; else
  jq -e '.apiVersion == "sdlc/v1" and .kind == "CognitionPack" and (.items|type=="array")' "$PACK" >/dev/null \
    || fail_msg "pack.json invalid"
fi

# 3. execution reports
REPORTS="$(find execution -path '*/reports/*.json' -type f 2>/dev/null || true)"
for f in $REPORTS; do
  jq -e '.apiVersion == "sdlc/v1" and .kind == "ExecutionReport" and (.metadata.service|length>0) and (.spec.stage|length>0)' "$f" >/dev/null \
    || fail_msg "report invalid: $f"
done

# 4. wiki generated (the wiki is derived from reports; with none, there is nothing to derive)
if [ -n "$REPORTS" ] && [ ! -f wiki/index.md ]; then
  fail_msg "missing wiki/index.md (run analyze-reports.sh)"
fi

if [ "$fail" -eq 0 ]; then
  echo "validate-project: OK ($(jq '.services|length' "$REG" 2>/dev/null || echo 0) services, $(echo "$REPORTS" | grep -c . || true) reports)"
else
  echo "validate-project: FAILED" >&2
fi
exit "$fail"
