#!/usr/bin/env bash
# scripts/new-project.sh — generate a project control-plane repo from the template.
#
# Repo naming rule: <project>-control-plane   e.g. ses-control-plane
# (legacy projects named <project>-management are still accepted by the generators,
#  but new projects use the control-plane suffix so they cannot be confused with
#  service repos named <project>-<service>-management.)
#
# Usage: scripts/new-project.sh <project> [target-dir] [--allow-custom-name]
#        scripts/new-project.sh --print-name <project>
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ALLOW_CUSTOM=0
PRINT_NAME=0
ARGS=()
for a in "$@"; do
  case "$a" in
    --allow-custom-name) ALLOW_CUSTOM=1 ;;
    --print-name) PRINT_NAME=1 ;;
    *) ARGS+=("$a") ;;
  esac
done
PROJECT="${ARGS[0]:-}"
TARGET="${ARGS[1]:-}"

[ -n "$PROJECT" ] || { echo "Usage: $0 <project> [target-dir] [--allow-custom-name]" >&2; exit 1; }
printf '%s' "$PROJECT" | grep -qE '^[a-z][a-z0-9-]*$' || { echo "ERROR: project must be kebab-case: '$PROJECT'" >&2; exit 1; }

REPO_NAME="${PROJECT}-control-plane"
if [ "$PRINT_NAME" = 1 ]; then
  printf '%s\n' "$REPO_NAME"
  exit 0
fi

TARGET="${TARGET:-./$REPO_NAME}"
TARGET_BASE="$(basename "$TARGET")"
if [ "$TARGET_BASE" != "$REPO_NAME" ] && [ "$ALLOW_CUSTOM" = 0 ]; then
  echo "ERROR: target dir '$TARGET_BASE' does not follow the naming rule for the project control repo (expected '$REPO_NAME')." >&2
  echo "       Pass --allow-custom-name to override." >&2
  exit 1
fi
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

# Deterministic guardrails: ship the universal hooks with the control repo.
cp -R "$ROOT/hooks" "$TARGET/"
cp -R "$ROOT/.githooks" "$TARGET/"
chmod +x "$TARGET"/hooks/*.sh "$TARGET"/.githooks/*

# Seed cognition pack.
cat > "$TARGET/knowledge/pack.json" <<EOF
{"apiVersion":"sdlc/v1","kind":"CognitionPack","metadata":{"name":"${PROJECT}-cognition","version":"0.1.0"},"items":[]}
EOF

( cd "$TARGET" && git init -q && git add -A && git commit -q -m "chore: bootstrap ${PROJECT} control-plane repo" ) || true
# Enable the hooks only after the bootstrap commit (factory content is trusted).
( cd "$TARGET" && git config core.hooksPath .githooks ) || true
echo "Created control-plane repo: $TARGET"
echo "Next: scripts/new-service-repo.sh <type> <name> $TARGET"
