#!/usr/bin/env bash
#
# hooks/spring-guard.sh — deterministic Spring Boot 4 / JPA guardrail.
# Blocks pre-Boot-4 APIs and unsafe persistence/config that agents commonly
# generate. Universal: git pre-commit (staged files) or PreToolUse (stdin JSON).
# Exit 0 = clean, exit 1 = findings (blocked).
#
# Covers: @MockBean/@SpyBean, pre-4 starters, Jackson 2, javax.*, Lombok @Data
# on @Entity, open-in-view:true, ddl-auto update/create in prod config (incl.
# config (infra repo)/), actuator "*" exposure. Findings cite the fixing skill.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

has_jq=0
command -v jq >/dev/null 2>&1 && has_jq=1

files=""
# Never block on an open pipe with no data (CI / agent shells): regular-file
# stdin is read in full; otherwise read one line with a 1s bound.
if [ "$has_jq" -eq 1 ] && [ ! -t 0 ]; then
  payload=""
  if [ -f /dev/stdin ]; then
    payload="$(cat 2>/dev/null || true)"
  else
    IFS= read -r -t 1 payload || true
  fi
  if [ -n "$payload" ]; then
    p="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || true)"
    [ -n "$p" ] && files="$p"
  fi
fi
if [ -z "$files" ]; then
  files="$(git -C "$root" diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)"
fi
[ -n "$files" ] || { echo "spring-guard: nothing to check"; exit 0; }

found=0
fail() { echo "SPRING-GUARD: $1" >&2; found=1; }

while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in build/*|*/.gradle/*|*/build/*) continue ;; esac
  [ -f "$f" ] || continue
  rel="${f#"$root"/}"

  case "$rel" in
    *.java)
      grep -nE '@MockBean|@SpyBean' "$f" \
        && fail "$rel uses @MockBean/@SpyBean — Boot 4 removed them; use @MockitoBean/@MockitoSpyBean (spring-boot-4-migration)."
      grep -nE 'com\.fasterxml\.jackson' "$f" \
        && fail "$rel imports Jackson 2 — Boot 4 uses Jackson 3 (tools.jackson); see spring-boot-4-migration."
      grep -nE '^import javax\.' "$f" \
        && fail "$rel imports javax.* — Boot 4 is Jakarta EE 11; use jakarta.*."
      if grep -qE '@Entity' "$f" && grep -qE '@Data|@EqualsAndHashCode' "$f"; then
        fail "$rel applies Lombok @Data/@EqualsAndHashCode to an @Entity — use explicit equals/hashCode (spring-data-jpa)."
      fi
      ;;
    *.gradle.kts|*.gradle|pom.xml)
      grep -nE 'spring-boot-starter-web([^a-zA-Z-]|$)' "$f" \
        && fail "$rel uses spring-boot-starter-web — use spring-boot-starter-webmvc (Boot 4)."
      grep -nE 'spring-cloud-starter-gateway([^a-zA-Z-]|$)' "$f" \
        && fail "$rel uses spring-cloud-starter-gateway — use spring-cloud-starter-gateway-server-webflux (Cloud 2025.1)."
      ;;
    *.yml|*.yaml)
      grep -nE '^\s*open-in-view:\s*true' "$f" \
        && fail "$rel sets spring.jpa.open-in-view: true — set it to false (spring-data-jpa)."
      grep -nE 'include:\s*["'"'"']?\*' "$f" \
        && fail "$rel exposes all actuator endpoints (include: \"*\") — expose an explicit allow-list (secure-api-review)."
      case "$rel" in
        *application.yml|*application-dev.yml|*application-uat.yml|*application-prod.yml|*config/*.yml)
          grep -nE 'ddl-auto:\s*(update|create|create-drop)' "$f" \
            && fail "$rel sets ddl-auto to update/create in shared/prod config — use validate + versioned migrations (aws-postgres)."
          ;;
      esac
      ;;
  esac
done <<< "$files"

if [ "$found" -eq 0 ]; then
  echo "spring-guard: clean"
else
  echo "spring-guard: fix the findings above; these are deterministic gates, not suggestions." >&2
fi
exit "$found"
