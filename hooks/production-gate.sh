#!/usr/bin/env bash
#
# hooks/production-gate.sh — approval gate: production deploys require a named
# release authorization. PreToolUse (Bash) hook for Claude Code / Codex.
# Reads JSON on stdin; exit 2 blocks the action (message goes to the agent).
set -uo pipefail

cmd="$(jq -r '.tool_input.command // empty' </dev/stdin 2>/dev/null || true)"

if [[ "$cmd" == *deploy* && "$cmd" == *production* ]]; then
  if [ -z "${RELEASE_APPROVAL:-}" ]; then
    echo "Production deploys need a release authorization (set RELEASE_APPROVAL to the named approver's sign-off)." >&2
    exit 2
  fi
  echo "Production deploy authorized by: ${RELEASE_APPROVAL}" >&2
fi
exit 0
