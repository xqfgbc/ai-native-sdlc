#!/usr/bin/env bash
#
# hooks/test-freeze.sh — during a bug-fix task (CLAUDE_FIX_TASK=1), block edits
# to test files so the agent cannot weaken the check on the code it is fixing.
# PreToolUse hook for Claude Code / Codex. Reads JSON on stdin; exit 2 blocks.
set -uo pipefail

[ "${CLAUDE_FIX_TASK:-}" = "1" ] || exit 0

path="$(jq -r '.tool_input.file_path // empty' </dev/stdin 2>/dev/null || true)"
case "$path" in
  src/test/*|src/itest/*)
    echo "Bug-fix task in progress: test files are frozen (write the failing test first, then fix the code without editing tests)." >&2
    exit 2
    ;;
esac
exit 0
