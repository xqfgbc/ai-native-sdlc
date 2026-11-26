#!/usr/bin/env bash
#
# hooks/session-log-guard.sh — Stop hook for service repos: a session that
# committed real work must leave a session log before it can end.
#
# AGENTS.md §2 ("会话协议（强制）") is otherwise only prose: agents skipped it
# and the knowledge loop lost the human instructions/corrections of whole
# sessions. This makes it deterministic at the one moment it can still be
# fixed — when the agent tries to stop.
#
# Exit 2 blocks the stop once; stop_hook_active prevents a retry loop.
set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
[ -d "sdlc/session-log" ] || exit 0          # framework / control plane: no logs
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
stop_active="$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)"
[ "$stop_active" = "true" ] && exit 0

# A log that is written but not yet committed already satisfies the protocol;
# once it is committed it moves last_sha past this session's work commits.
[ -n "$(git status --porcelain -- sdlc/session-log 2>/dev/null)" ] && exit 0

last_sha="$(git log -1 --format=%H -- sdlc/session-log 2>/dev/null || true)"
range="${last_sha:+$last_sha..HEAD}"
range="${range:-HEAD}"

# Ignore collector/cognition churn: only real work needs a narrative.
work="$(git log "$range" --format=%h -- . \
  ':(exclude).sdlc' ':(exclude)sync' ':(exclude)sdlc/session-log' 2>/dev/null || true)"
[ -n "$work" ] || exit 0

cat >&2 <<'EOF'
会话协议未完成：本会话有代码/文档提交，但 sdlc/session-log/ 没有对应记录。
结束前请写 sdlc/session-log/<YYYYMMDD-HHMM>.md，包含：
  ## 人的指令 / ## AI 实际改动 / ## 人的纠正 / ## 规则缺口 / ## 未决问题
然后随本次改动一起提交——采集器只读取已提交的 session-log。
EOF
exit 2
