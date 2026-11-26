#!/usr/bin/env bash
#
# scripts/validate-skills.sh — validate the skill/agent configuration layer.
# Fails when a SKILL.md is malformed, a canonical skill is not mirrored to the
# Claude adapter, or an agent definition lacks name/description. Wire into CI so
# configuration changes (which steer the agents) get the same scrutiny as code.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
fail_msg() { echo "VALIDATE: $1" >&2; fail=1; }

# 1. Canonical skills: .agents/skills/<name>/SKILL.md with name/description.
for d in "$root"/.agents/skills/*/; do
  name="$(basename "$d")"
  f="$d/SKILL.md"
  [ -f "$f" ] || { fail_msg "missing SKILL.md: .agents/skills/$name"; continue; }
  head -1 "$f" | grep -q '^---$' || fail_msg "$name: SKILL.md must start with YAML frontmatter (---)"
  fmname="$(sed -n '2,25p' "$f" | grep -m1 -E '^name:' | sed -E 's/^name:[[:space:]]*//; s/["'\'']//g')"
  [ "$fmname" = "$name" ] || fail_msg "$name: frontmatter name '$fmname' must equal the directory name"
  desc="$(sed -n '2,30p' "$f" | grep -m1 -E '^description:' | sed -E 's/^description:[[:space:]]*//')"
  [ -n "$desc" ] || fail_msg "$name: missing non-empty description"
done

# 2. Claude adapter mirrors canonical skills (run scripts/sync-agent-adapters.sh).
for d in "$root"/.agents/skills/*/; do
  name="$(basename "$d")"
  c="$root/.claude/skills/$name/SKILL.md"
  if [ ! -f "$c" ]; then
    fail_msg "missing Claude adapter for '$name' (run scripts/sync-agent-adapters.sh)"
  elif ! cmp -s "$d/SKILL.md" "$c"; then
    fail_msg "Claude adapter for '$name' is stale (run scripts/sync-agent-adapters.sh)"
  fi
done

# 3. Agents have name + description (Claude Markdown, Codex TOML).
for f in "$root"/.claude/agents/*.md; do
  [ -f "$f" ] || continue
  name="$(basename "$f" .md)"
  head -1 "$f" | grep -q '^---$' || fail_msg "agent $name: missing frontmatter"
  sed -n '2,20p' "$f" | grep -q -E '^name:' || fail_msg "agent $name: missing name"
  sed -n '2,20p' "$f" | grep -q -E '^description:' || fail_msg "agent $name: missing description"
done
for f in "$root"/.codex/agents/*.toml; do
  [ -f "$f" ] || continue
  name="$(basename "$f" .toml)"
  grep -q '^name = ' "$f" || fail_msg "codex agent $name: missing name"
  grep -q '^description = ' "$f" || fail_msg "codex agent $name: missing description"
done

skills="$(find "$root/.agents/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
agents="$(find "$root/.claude/agents" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')"
if [ "$fail" -eq 0 ]; then
  echo "validate-skills: OK ($skills skills, $agents agents)"
else
  echo "validate-skills: FAILED" >&2
fi
exit "$fail"
