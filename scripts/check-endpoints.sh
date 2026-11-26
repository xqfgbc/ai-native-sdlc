#!/usr/bin/env bash
#
# scripts/check-endpoints.sh — heuristic security check used by the
# secure-api-review skill. Flags controller files that declare state-changing
# endpoints (POST/PUT/PATCH/DELETE) without visible @Valid / @Validated.
#
# Exit 0 = no findings. Exit 1 = findings listed (agent must include them).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FOUND=0

for f in $(find "${ROOT_DIR}/services" -path '*/src/main/java/*' -name '*Controller.java' 2>/dev/null | sort); do
  mappings=$(grep -cE '@(Post|Put|Patch|Delete)Mapping' "$f" || true)
  [ "$mappings" -gt 0 ] || continue
  if ! grep -qE '@(Valid|Validated)' "$f"; then
    rel=${f#"${ROOT_DIR}/"}
    echo "FINDING: ${rel} declares ${mappings} state-changing endpoint(s) but no @Valid/@Validated."
    FOUND=1
  fi
done

if [ "$FOUND" -eq 0 ]; then
  echo "check-endpoints: no findings across services/."
fi
exit $FOUND
