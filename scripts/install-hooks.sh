#!/usr/bin/env bash
# scripts/install-hooks.sh — enable this repo's deterministic git hooks
# (core.hooksPath=.githooks). Idempotent and safe to run on every session start.
#
# core.hooksPath is local config, so a fresh clone must run this once. Claude Code
# runs it automatically via the SessionStart hook in .claude/settings.json; other
# agents are told to run it at the start of their session (AGENTS.md).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ ! -f .githooks/pre-commit ]; then
  echo "install-hooks: no .githooks/pre-commit here; nothing to install" >&2
  exit 1
fi

chmod +x .githooks/* 2>/dev/null || true
[ -d hooks ] && chmod +x hooks/*.sh 2>/dev/null || true

current="$(git config --local --get core.hooksPath 2>/dev/null || true)"
if [ "$current" = ".githooks" ]; then
  echo "install-hooks: already enabled (core.hooksPath=.githooks)"
  exit 0
fi

git config --local core.hooksPath .githooks
echo "install-hooks: enabled core.hooksPath=.githooks"
