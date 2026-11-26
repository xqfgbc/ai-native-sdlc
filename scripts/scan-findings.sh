#!/usr/bin/env bash
# scripts/scan-findings.sh — deterministic foot-gun scan. Appends findings to findings/inbox.md.
# Scanner agents and this script REPORT, they never fix. Humans triage the queue periodically;
# repeated findings reveal a root cause that should become a guardrail (lint/ArchUnit/hook).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
mkdir -p findings
OUT="findings/inbox.md"
[ -f "$OUT" ] || {
  printf '%s\n\n' "# Findings inbox" "> Append-only. Scanner agents / this script add findings; humans triage. Do not fix here." > "$OUT"
}
TS="$(date -u +%FT%TZ)"
add() { printf -- '- [%s] %s\n' "$TS" "$1" >> "$OUT"; }

src_dir="src"
[ -d "$src_dir" ] || { echo "scan-findings: no src/ (not a Java service?)"; exit 0; }

grep -rn --include='*.java' -E '@MockBean|@SpyBean' "$src_dir" 2>/dev/null | while IFS= read -r l; do add "Boot4 API: $l"; done
grep -rn --include='*.java' -E 'new RestTemplate\(' "$src_dir" 2>/dev/null | while IFS= read -r l; do add "unbounded outbound (RestTemplate): $l"; done
grep -rn --include='*.java' -E '@Autowired[[:space:]]*$' "$src_dir" 2>/dev/null | while IFS= read -r l; do add "field injection: $l"; done
grep -rn --include='*.yml' -E 'ddl-auto:[[:space:]]*(update|create)' "$src_dir/main/resources" 2>/dev/null | while IFS= read -r l; do add "schema generation: $l"; done
grep -rn --include='*.yml' -E 'open-in-view:[[:space:]]*true' "$src_dir/main/resources" 2>/dev/null | while IFS= read -r l; do add "OSIV enabled: $l"; done

echo "scan-findings: appended to $OUT ($(grep -c '^- ' "$OUT" 2>/dev/null || echo 0) total findings)"
