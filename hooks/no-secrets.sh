#!/usr/bin/env bash
#
# hooks/no-secrets.sh — deterministic secret scan. Universal: runs from the git
# pre-commit hook (see .githooks/pre-commit) and as an agent PreToolUse guard.
# Exit 0 = clean, exit 1 = findings (the action/commit is blocked).
#
# Git mode: scans staged files. Agent-tool mode: scans the file in stdin JSON.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

files=""
# Agent PreToolUse JSON on stdin (Claude Code / Codex) — file to be written.
if [ ! -t 0 ]; then
  payload="$(cat 2>/dev/null || true)"
  if [ -n "$payload" ]; then
    p="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || true)"
    [ -n "$p" ] && files="$p"
  fi
fi
# Fall back to staged files (git mode).
if [ -z "$files" ]; then
  files="$(git -C "$root" diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)"
fi
[ -n "$files" ] && echo "$files" || { echo "no-secrets: nothing to scan"; exit 0; }

# Filename blocklist.
blocked_name='\.env$|\.pem$|\.key$|\.p12$|\.pfx$|id_rsa$|credentials$'
# Content patterns (one per line, ERE).
blocked_content='-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|aws_secret_access_key|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|github_pat_|xox[baprs]-|sk-[A-Za-z0-9]{20,}|-----BEGIN RSA PRIVATE KEY-----'

found=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in
    build/*|*/.gradle/*|*/build/*) continue ;;  # ignored paths, not secret material
  esac
  rel="${f#"$root"/}"
  if printf '%s' "$rel" | grep -Eq "$blocked_name"; then
    echo "BLOCKED: secret-looking file staged: $rel" >&2
    found=1
    continue
  fi
  if [ -f "$f" ]; then
    if grep -InE "$blocked_content" "$f" 2>/dev/null; then
      found=1
    fi
  fi
done <<< "$files"

if [ "$found" -ne 0 ]; then
  echo "no-secrets: remove secrets or add an approved exception (never commit them)." >&2
  exit 1
fi
echo "no-secrets: clean"
exit 0
