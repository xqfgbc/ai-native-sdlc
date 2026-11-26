#!/usr/bin/env bash
# hooks/commit-guard.sh — PreToolUse guard: reject a non-conforming `git commit -m ...`
# BEFORE it runs, so the agent can fix the subject immediately instead of after commit-msg.
set -uo pipefail

payload=""
if [ ! -t 0 ]; then
  if [ -f /dev/stdin ]; then
    payload="$(cat 2>/dev/null || true)"
  else
    IFS= read -r -t 1 payload || true
  fi
fi
[ -n "$payload" ] || exit 0

cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
case "$cmd" in *"git commit"*) ;; *) exit 0 ;; esac

msg=""
if [[ "$cmd" =~ --message=\"([^\"]*)\" ]]; then msg="${BASH_REMATCH[1]}"
elif [[ "$cmd" =~ --message=\'([^\']*)\' ]]; then msg="${BASH_REMATCH[1]}"
elif [[ "$cmd" =~ -m[[:space:]]+\"([^\"]*)\" ]]; then msg="${BASH_REMATCH[1]}"
elif [[ "$cmd" =~ -m[[:space:]]+\'([^\']*)\' ]]; then msg="${BASH_REMATCH[1]}"
fi
[ -n "$msg" ] || exit 0   # editor or -F: the commit-msg hook is the backstop

first="${msg%%$'\n'*}"
if printf '%s' "$first" | grep -Eq '^\[[^]]+\] #[A-Za-z0-9._/-]+ (feat|fix|refactor|docs|chore|test|perf|ci|build|revert): .+'; then
  exit 0
fi

echo "commit-guard: commit subject must be '[<name>] #<ticket> <type>: <summary>'" >&2
echo "commit-guard: AI-generated code uses [AI-Agent]; no ticket uses #N/A." >&2
echo "commit-guard: example '[AI-Agent] #AC-1020 feat: add new processor for BMI3 calculation'." >&2
echo "commit-guard: got: ${first:-<empty>}" >&2
exit 2
