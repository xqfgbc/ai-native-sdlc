#!/usr/bin/env bash
# scripts/new-service-repo.sh — generate a service repo from a service-type template,
# wire its collector, and register it in the management repo's services.json.
#
# Repo naming rules (derived from <project> = control repo name minus "-control-plane",
# or minus the legacy "-management" suffix):
#   business, frontend-vue   <project>-<service>-management        e.g. ses-speaker-management
#   gateway                  <project>-<usage>-gateway             e.g. ses-api-gateway
#   infra                    <project>-<cloud>-infra               e.g. ses-aws-infra
#   config-server            <project>-config-server               e.g. ses-config-server
#   configuration-data       <project>-<prod|devops>-configuration-data
#                                                                  e.g. ses-prod-configuration-data
#
# Usage: scripts/new-service-repo.sh <type> <name> <management-repo> [target-dir] [--allow-custom-name]
#        scripts/new-service-repo.sh --print-name <type> <name> <management-repo>
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ALLOW_CUSTOM=0
PRINT_NAME=0
ARGS=()
for a in "$@"; do
  case "$a" in
    --allow-custom-name) ALLOW_CUSTOM=1 ;;
    --print-name) PRINT_NAME=1 ;;
    *) ARGS+=("$a") ;;
  esac
done
TYPE="${ARGS[0]:-}"; NAME="${ARGS[1]:-}"; MGMT="${ARGS[2]:-}"; TARGET="${ARGS[3]:-}"

usage() {
  cat >&2 <<'EOF'
Usage: new-service-repo.sh <type> <name> <management-repo> [target-dir] [--allow-custom-name]
       new-service-repo.sh --print-name <type> <name> <management-repo>

Types and repo naming rules (<project> = control repo name minus "-control-plane"):
  business, frontend-vue  <project>-<service>-management     (<name> = service)
  gateway                 <project>-<usage>-gateway          (<name> = usage)
  infra                   <project>-<cloud>-infra            (<name> = cloud provider)
  config-server           <project>-config-server            (<name> = config-server)
  configuration-data      <project>-<prod|devops>-configuration-data
EOF
}

kebab() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'; }

# normalize <value> by stripping the project prefix and the type suffix.
normalize() { # <value> <project> <suffix>
  local v; v="$(kebab "$1")"
  local p; p="$(kebab "$2")"
  [ -n "$p" ] && v="${v#"$p"-}"
  [ -n "$3" ] && v="${v%-"$3"}"
  printf '%s' "$v"
}

repo_name() { # <type> <name> <project>
  case "$1" in
    business|frontend-vue) printf '%s-%s-management' "$3" "$(normalize "$2" "$3" management)" ;;
    gateway)               printf '%s-%s-gateway'    "$3" "$(normalize "$2" "$3" gateway)" ;;
    infra)                 printf '%s-%s-infra'      "$3" "$(normalize "$2" "$3" infra)" ;;
    config-server)         printf '%s-config-server' "$3" ;;
    configuration-data)    printf '%s-%s-configuration-data' "$3" "$(normalize "$2" "$3" configuration-data)" ;;
  esac
}

service_name() { # <type> <name> <project> — the logical service name used in reports/registry
  case "$1" in
    business|frontend-vue) normalize "$2" "$3" management ;;
    gateway)               normalize "$2" "$3" gateway ;;
    infra)                 normalize "$2" "$3" infra ;;
    config-server)         printf 'config-server' ;;
    configuration-data)    printf '%s-configuration-data' "$(normalize "$2" "$3" configuration-data)" ;;
  esac
}

[ -n "$TYPE" ] && [ -n "$NAME" ] && [ -n "$MGMT" ] || { usage; exit 1; }
[ -d "$ROOT/templates/service-types/$TYPE" ] || { echo "ERROR: no template for type '$TYPE'" >&2; usage; exit 1; }
[ -d "$MGMT" ] || { echo "ERROR: management repo not found: $MGMT" >&2; exit 1; }

MGMT_ABS="$(cd "$MGMT" && pwd)"
PROJECT="$(basename "$MGMT_ABS")"
case "$PROJECT" in
  *-control-plane) PROJECT="${PROJECT%-control-plane}" ;;
  *-management)    PROJECT="${PROJECT%-management}" ;;  # legacy control-plane names
esac

SERVICE_NAME="$(service_name "$TYPE" "$NAME" "$PROJECT")"
REPO_NAME="$(repo_name "$TYPE" "$NAME" "$PROJECT")"

[ "$SERVICE_NAME" = "control-plane" ] && {
  echo "ERROR: 'control-plane' is reserved for the project control repo; choose another service name" >&2; exit 1; }

case "$TYPE" in
  config-server)
    [ "$SERVICE_NAME" = "config-server" ] || {
      echo "ERROR: config-server repos are named <project>-config-server; pass name 'config-server' (got '$NAME')" >&2; exit 1; } ;;
  configuration-data)
    case "$SERVICE_NAME" in
      prod-configuration-data|devops-configuration-data) ;;
      *) echo "ERROR: configuration-data env must be 'prod' or 'devops' (got '$NAME')" >&2; exit 1; ;;
    esac ;;
esac
printf '%s' "$SERVICE_NAME" | grep -qE '^[a-z][a-z0-9-]*$' || { echo "ERROR: invalid service name: '$SERVICE_NAME'" >&2; exit 1; }
printf '%s' "$REPO_NAME" | grep -qE '^[a-z][a-z0-9-]*$' || { echo "ERROR: invalid repo name: '$REPO_NAME'" >&2; exit 1; }

if [ "$PRINT_NAME" = 1 ]; then
  printf '%s\n' "$REPO_NAME"
  exit 0
fi

TARGET="${TARGET:-./$REPO_NAME}"
TARGET_BASE="$(basename "$TARGET")"
if [ "$TARGET_BASE" != "$REPO_NAME" ] && [ "$ALLOW_CUSTOM" = 0 ]; then
  echo "ERROR: target dir '$TARGET_BASE' does not follow the naming rule for type '$TYPE' (expected '$REPO_NAME')." >&2
  echo "       Pass --allow-custom-name to override." >&2
  exit 1
fi
[ -e "$TARGET" ] && { echo "ERROR: target exists: $TARGET" >&2; exit 1; }

mkdir -p "$TARGET"
TARGET_ABS="$(cd "$TARGET" && pwd)"
# Standalone Java service repos vendor shared Gradle scaffolding (platform BOM, wrapper, checkstyle).
case " gateway config-server business " in
  *" $TYPE "*)
    cp -R "$ROOT/templates/service-types/_shared/." "$TARGET/"
    chmod +x "$TARGET/gradlew"
    ;;
esac
cp -R "$ROOT/templates/service-types/$TYPE/." "$TARGET/"

# Render placeholders across all text files (skip binaries such as the gradle wrapper jar).
find "$TARGET" -type f \
  \( -name '*.md' -o -name '*.json' -o -name '*.yml' -o -name '*.yaml' -o -name '*.kts' \
     -o -name '*.java' -o -name '*.tpl' -o -name '*.html' -o -name '*.ts' -o -name '*.js' -o -name '*.css' -o -name '*.vue' \
     -o -name 'Dockerfile' \) \
  -print0 | while IFS= read -r -d '' f; do
    perl -pi -e "s/\{\{SERVICE\}\}/${SERVICE_NAME}/g; s/\{\{PROJECT\}\}/${PROJECT}/g; s/\{\{TYPE\}\}/${TYPE}/g; s#\{\{MGMT_REPO\}\}#${MGMT_ABS}#g" "$f"
  done

mkdir -p "$TARGET/.sdlc" "$TARGET/sdlc/session-log" "$TARGET/sync/reports"
[ -f "$TARGET/settings.gradle.kts.tpl" ] && mv "$TARGET/settings.gradle.kts.tpl" "$TARGET/settings.gradle.kts"
[ -f "$TARGET/service.json.tpl" ] && mv "$TARGET/service.json.tpl" "$TARGET/service.json"
[ -f "$TARGET/config.json.tpl" ] && mv "$TARGET/config.json.tpl" "$TARGET/.sdlc/config.json"
jq -n --arg svc "$SERVICE_NAME" \
  '{apiVersion:"sdlc/v1",kind:"LocalCognition",service:$svc,items:[]}' \
  > "$TARGET/.sdlc/local-cognition.json"

# Wire collector.
cp "$ROOT/scripts/collect.sh" "$TARGET/.sdlc/collect.sh"
chmod +x "$TARGET/.sdlc/collect.sh"

# D8: multi-agent spec source (canonical .agents/skills + generated .claude/skills + subagents).
mkdir -p "$TARGET/.agents" "$TARGET/.claude" "$TARGET/scripts"
cp -R "$ROOT/.agents/skills" "$TARGET/.agents/" 2>/dev/null || true
cp -R "$ROOT/.claude/skills" "$TARGET/.claude/" 2>/dev/null || true
cp -R "$ROOT/.claude/agents" "$TARGET/.claude/" 2>/dev/null || true
# Agent wiring so a fresh clone installs the hooks on the first session.
cp "$ROOT/.claude/settings.json" "$TARGET/.claude/" 2>/dev/null || true
mkdir -p "$TARGET/.codex"
cp "$ROOT/.codex/hooks.json" "$TARGET/.codex/" 2>/dev/null || true
cp "$ROOT/scripts/validate-skills.sh" "$TARGET/scripts/" 2>/dev/null || true
cp "$ROOT/scripts/install-hooks.sh" "$TARGET/scripts/" 2>/dev/null || true
cp "$ROOT/scripts/debt.sh" "$ROOT/scripts/cognition.sh" "$ROOT/scripts/local-cognition.sh" "$TARGET/scripts/" 2>/dev/null || true
[ -f "$TARGET/scripts/validate-skills.sh" ] && chmod +x "$TARGET/scripts/validate-skills.sh"
[ -f "$TARGET/scripts/install-hooks.sh" ] && chmod +x "$TARGET/scripts/install-hooks.sh"
[ -f "$TARGET/scripts/debt.sh" ] && chmod +x "$TARGET/scripts/debt.sh"
[ -f "$TARGET/scripts/cognition.sh" ] && chmod +x "$TARGET/scripts/cognition.sh"
[ -f "$TARGET/scripts/local-cognition.sh" ] && chmod +x "$TARGET/scripts/local-cognition.sh"
# P2: remote push channel for reports.
cp "$ROOT/scripts/upload-report.sh" "$TARGET/scripts/" 2>/dev/null || true
[ -f "$TARGET/scripts/upload-report.sh" ] && chmod +x "$TARGET/scripts/upload-report.sh"
# Local backfill after an offline collect (management repo was absent).
cp "$ROOT/scripts/replay-reports.sh" "$TARGET/scripts/" 2>/dev/null || true
[ -f "$TARGET/scripts/replay-reports.sh" ] && chmod +x "$TARGET/scripts/replay-reports.sh"
# Verification-first: one reusable verification CLI for every agent.
cp "$ROOT/scripts/app-verify.sh" "$TARGET/scripts/" 2>/dev/null || true
[ -f "$TARGET/scripts/app-verify.sh" ] && chmod +x "$TARGET/scripts/app-verify.sh"
# Trust ladder + scanner queue tooling.
cp "$ROOT/scripts/autopilot-gate.sh" "$ROOT/scripts/scan-findings.sh" "$TARGET/scripts/" 2>/dev/null || true
chmod +x "$TARGET/scripts/autopilot-gate.sh" "$TARGET/scripts/scan-findings.sh" 2>/dev/null || true

# Deterministic guardrails: ship the universal hooks with the repo and enable
# them for every future commit/push (core.hooksPath is local config — a fresh
# clone must re-run `git config core.hooksPath .githooks`).
cp -R "$ROOT/hooks" "$TARGET/"
cp -R "$ROOT/.githooks" "$TARGET/"
chmod +x "$TARGET"/hooks/*.sh "$TARGET"/.githooks/*
mkdir -p "$TARGET/findings"
cat > "$TARGET/findings/README.md" <<EOF
# findings/ — scanner inbox (append-only)

Scanner agents and \`scripts/scan-findings.sh\` **append** findings here; they never fix.
Humans triage this queue periodically. Repeated findings reveal a root cause that should
become a guardrail (lint / ArchUnit / hook), not a per-instance fix.
EOF
[ -f "$TARGET/findings/inbox.md" ] || printf '%s\n\n' "# Findings inbox" "> Append-only. Generated by scanners; humans triage." > "$TARGET/findings/inbox.md"

# Verification-first: seed the feature map (feature -> requirement -> verification -> status).
cat > "$TARGET/feature-map.md" <<EOF
# Feature map — ${SERVICE_NAME}

> The single place to see what this service does, which requirement it serves, and whether it is
> verified. Update it when a feature is added or its verification changes. The tool is
> \`bash scripts/app-verify.sh\`; this file is the map.

| Feature | Requirement | Verification (command / evidence) | Status |
|---|---|---|---|
| _example: GET /api/hello_ | REQ-____ | \`bash scripts/app-verify.sh itest\` → AppEndpointIT | planned |
EOF

( cd "$TARGET" && git init -q && git add -A && git commit -q -m "[AI-Agent] #N/A chore: bootstrap ${SERVICE_NAME} (${TYPE}) from template" ) || true
# Enable the hooks only after the bootstrap commit: factory-generated content is
# trusted, while every human/agent commit from here on is gated.
( cd "$TARGET" && git config core.hooksPath .githooks ) || true

# Register in services.json.
REG="$MGMT_ABS/loop/04-build/services.json"
[ -f "$REG" ] || echo '{"apiVersion":"sdlc/v1","kind":"ServiceRegistry","project":"'"$PROJECT"'","services":[]}' > "$REG"
jq --arg name "$SERVICE_NAME" --arg type "$TYPE" --arg repo "$TARGET_ABS" --arg pack "${PROJECT}-cognition" '
  .services += [{
    name: $name, type: $type, repo: $repo, phase: "building",
    trustLevel: "L1",
    template: {name: $type, version: "0.1.0"},
    cognitionPack: {name: $pack, version: "0.0.0"},
    requirements: [], updatedAt: (now | todate)
  }]' "$REG" > "$REG.tmp" && mv "$REG.tmp" "$REG"
echo "Collected $SERVICE_NAME ($TYPE) -> $TARGET_ABS ($REPO_NAME) ; registered in $REG"
