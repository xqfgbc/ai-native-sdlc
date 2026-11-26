#!/usr/bin/env bash
#
# scripts/scaffold-project.sh — generate a real project from this framework.
#
# The framework is itself a template. This script:
#   1. copies the framework tree (minus git/build/scratch) to a target dir;
#   2. rewrites the project name and base group;
#   3. initialises git, installs the universal git guardrails, and commits;
#   4. optionally scaffolds the first service.
#
# Usage:
#   ./scripts/scaffold-project.sh <project-name> <target-dir> [base-package] [--first-service <name>]
#
# Example:
#   ./scripts/scaffold-project.sh orders ../orders com.acme --first-service order-service

set -euo pipefail

PROJECT="${1:-}"
TARGET="${2:-}"
PKG_ARG="${3:-com.example}"
FIRST_SERVICE=""

# Parse optional flags after the positional args.
while [ $# -gt 0 ]; do
  case "$1" in
    --first-service) FIRST_SERVICE="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

[ -n "$PROJECT" ] && [ -n "$TARGET" ] || {
  echo "Usage: ./scripts/scaffold-project.sh <project-name> <target-dir> [base-package] [--first-service <name>]" >&2
  exit 1
}

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -e "$TARGET" ]; then
  echo "ERROR: target already exists: $TARGET" >&2
  exit 1
fi

echo "Scaffolding project '$PROJECT' -> $TARGET (package $PKG_ARG)"

# Copy the framework, excluding machine/runtime scratch and framework-internal
# research notes.
mkdir -p "$TARGET"
(
  cd "$SRC"
  tar --exclude='.git' --exclude='build' --exclude='.gradle' \
      --exclude='research' --exclude='.DS_Store' -cf - . \
) | tar -xf - -C "$TARGET"

# Rewrite the Gradle project name and base group.
sed -i.bak "s/spring-cloud-ai-native-sdlc/${PROJECT}/g" "$TARGET/settings.gradle.kts" && rm -f "$TARGET/settings.gradle.kts.bak"
sed -i.bak 's/com\.example/'"${PKG_ARG//./\\.}"'/g' "$TARGET/build.gradle.kts" && rm -f "$TARGET/build.gradle.kts.bak"
# Rewrite the base package used by shared modules.
find "$TARGET/config-server" "$TARGET/gateway" -type f -name '*.java' -print0 \
  | xargs -0 sed -i.bak 's/com\.example/'"${PKG_ARG//./\\.}"'/g' 2>/dev/null || true
find "$TARGET" -name '*.bak' -delete

# Initialise git and the universal guardrails.
(
  cd "$TARGET"
  git init -q
  git config core.hooksPath .githooks
  git add -A
  git commit -q -m "chore: scaffold ${PROJECT} from the AI-Native SDLC framework" || true
)

echo
echo "Done. Next steps (AI-native SDLC):"
[ -n "$FIRST_SERVICE" ] && echo "  ./scripts/new-service.sh $FIRST_SERVICE   # first business service"
echo "  1. File an intent:  intent/$(date +%F)-<slug>/intent.md"
echo "  2. Accept spec.md, then plan.md (plan mode) — nothing is implemented without an accepted plan."
echo "  3. Verify:  make build && make lint && make test && make itest"
echo "  4. Split the infra repo from infra/ and bootstrap Flux (docs/repository-topology.md)."
