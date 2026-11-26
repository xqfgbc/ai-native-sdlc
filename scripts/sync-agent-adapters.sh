#!/usr/bin/env bash
#
# scripts/sync-agent-adapters.sh — regenerate per-agent adapters from the
# canonical agent-agnostic layer.
#
# Canonical source of truth:
#   .agents/skills/<name>/SKILL.md   (Agent Skills standard)
#   .claude/agents/<name>.md         (subagent definitions, Claude/openCode style)
#
# Which agent reads what (see docs/agent-support-matrix.md):
#   Claude Code  .claude/skills/   .claude/agents/   (needs a copy)
#   Codex        .agents/skills/   .codex/agents/    (skills read natively)
#   opencode     .agents/skills/   .opencode/agents/ (skills read natively)
#   DSH          .agents/skills/   presets (bundle)  (skills read natively)
#
# Only Claude Code needs skills copied; everything else reads the canonical
# .agents/skills/ directly. Run this after adding/editing skills so the Claude
# Code adapter stays in sync.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT_DIR}/.agents/skills"
DST="${ROOT_DIR}/.claude/skills"

mkdir -p "${DST}"

# Remove stale adapter dirs that no longer have a canonical skill.
for d in "${DST}"/*/; do
  name="$(basename "${d}")"
  [ -d "${SRC}/${name}" ] || rm -rf "${d}"
done

# Copy each canonical skill into the Claude Code adapter.
for src_skill in "${SRC}"/*/; do
  name="$(basename "${src_skill}")"
  mkdir -p "${DST}/${name}"
  cp "${src_skill}/SKILL.md" "${DST}/${name}/SKILL.md"
done

echo "Synced $(find "${SRC}" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ') skills from .agents/skills -> .claude/skills"
