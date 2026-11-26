#!/usr/bin/env bash
# scripts/new-project.sh — generate a project-management repo from the template.
# Usage: scripts/new-project.sh <project> [target-dir]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${1:-}"
TARGET="${2:-}"
[ -n "$PROJECT" ] || { echo "Usage: $0 <project> [target-dir]" >&2; exit 1; }
TARGET="${TARGET:-./${PROJECT}-management}"
[ -e "$TARGET" ] && { echo "ERROR: target exists: $TARGET" >&2; exit 1; }

mkdir -p "$TARGET"
cp -R "$ROOT/templates/project-management/." "$TARGET/"

# Render placeholders in text files.
find "$TARGET" -type f \( -name '*.md' -o -name '*.json' -o -name '*.yml' -o -name '*.yaml' \) -print0 \
  | while IFS= read -r -d '' f; do
      perl -pi -e "s/\{\{PROJECT\}\}/${PROJECT}/g" "$f"
    done

# Ensure runtime dirs.
mkdir -p "$TARGET"/loop/{01-intent,02-spec,03-plan,04-build,05-test,06-deploy,07-maintain} \
         "$TARGET"/execution "$TARGET"/knowledge/{constraints,skills,lessons,context,proposals} \
         "$TARGET"/wiki/services "$TARGET"/sync/schemas
cp "$ROOT"/schemas/*.json "$TARGET/sync/schemas/" 2>/dev/null || true

# A1: make the management repo self-contained (analyzer/validator/promote/sync run in-repo).
mkdir -p "$TARGET/scripts"
cp "$ROOT/scripts/analyze-reports.sh" "$ROOT/scripts/validate-project.sh" \
   "$ROOT/scripts/promote-proposal.sh" "$ROOT/scripts/sync-cognition.sh" \
   "$ROOT/scripts/intake.sh" "$ROOT/scripts/intake-signal.sh" "$TARGET/scripts/"
chmod +x "$TARGET"/scripts/*.sh

# Seed cognition pack.
cat > "$TARGET/knowledge/pack.json" <<EOF
{"apiVersion":"sdlc/v1","kind":"CognitionPack","metadata":{"name":"${PROJECT}-cognition","version":"0.1.0"},"items":[]}
EOF

( cd "$TARGET" && git init -q && git add -A && git commit -q -m "chore: bootstrap ${PROJECT} management repo" ) || true
echo "Created management repo: $TARGET"
echo "Next: scripts/new-service-repo.sh <type> <name> $TARGET"
