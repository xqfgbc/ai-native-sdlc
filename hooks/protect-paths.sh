#!/usr/bin/env bash
#
# hooks/protect-paths.sh — blocks edits to generated / protected paths.
# Universal: git pre-commit (staged files) or agent PreToolUse (stdin JSON).
# Exit 0 = allow, exit 1 = block.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

files=""
if [ ! -t 0 ]; then
  payload="$(cat 2>/dev/null || true)"
  if [ -n "$payload" ]; then
    p="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || true)"
    [ -n "$p" ] && files="$p"
  fi
fi
if [ -z "$files" ]; then
  files="$(git -C "$root" diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)"
fi
[ -n "$files" ] || { echo "protect-paths: nothing to check"; exit 0; }

found=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  rel="${f#"$root"/}"
  case "$rel" in
    build/*|*/.gradle/*|*/build/*|*/*/build/*|*/generated/*|src/gen/*)
      echo "BLOCKED: protected/generated path: $rel" >&2
      found=1
      ;;
  esac
done <<< "$files"

[ "$found" -eq 0 ] && echo "protect-paths: clean"
exit "$found"
