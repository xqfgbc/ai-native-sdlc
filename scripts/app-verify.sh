#!/usr/bin/env bash
# scripts/app-verify.sh — one verification CLI every agent in a service repo can reuse.
# Detects the stack and runs the cheap verification loop. This is the "knife" the skills
# (verify-work) point at instead of each agent inventing its own one-off scripts.
# Usage: bash scripts/app-verify.sh [build|test|lint|itest|all|smoke]
set -euo pipefail
CMD="${1:-all}"
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [ -f build.gradle.kts ] || [ -f build.gradle ]; then
  case "$CMD" in
    build) ./gradlew assemble ;;
    test) ./gradlew test ;;
    lint) ./gradlew checkstyleMain checkstyleTest ;;
    itest) ./gradlew check ;;
    all) ./gradlew check ;;
    smoke)
      # SERVER_PORT wins over the default written in application.yml.
      PORT="${SERVER_PORT:-$(grep -E '^\s*port:' src/main/resources/application.yml 2>/dev/null | head -1 | grep -oE '[0-9]+' | head -1 || true)}"
      PORT="${PORT:-8081}"
      echo "smoke: starting app (port $PORT) and polling /actuator/health ..."
      # Only force the local profile when the template ships one; config-server's
      # default profile (native) must not be overridden or it starts with no backend.
      PROFILE_ARG=""
      [ -f src/main/resources/application-local.yml ] && PROFILE_ARG="--args=--spring.profiles.active=local"
      # shellcheck disable=SC2086
      ./gradlew bootRun $PROFILE_ARG > /tmp/app-verify.log 2>&1 &
      PID=$!
      trap 'kill "$PID" 2>/dev/null || true' EXIT
      for _ in $(seq 1 60); do
        if curl -fsS "http://localhost:${PORT}/actuator/health" >/dev/null 2>&1; then
          echo "smoke: UP"; exit 0
        fi
        sleep 2
      done
      echo "smoke: app did not become healthy; see /tmp/app-verify.log" >&2; exit 1 ;;
    *) echo "usage: $0 [build|test|lint|itest|all|smoke]" >&2; exit 1 ;;
  esac
elif [ -f package.json ]; then
  case "$CMD" in
    build) npm run build ;;
    test) npm run test ;;
    lint) npm run build ;;
    itest) npm run test ;;
    all) npm run test && npm run build ;;
    smoke) echo "smoke: frontend has no runtime probe yet (add Playwright E2E)"; exit 0 ;;
    *) echo "usage: $0 [build|test|lint|itest|all|smoke]" >&2; exit 1 ;;
  esac
else
  echo "app-verify: unknown stack (no build.gradle.kts / package.json)" >&2
  exit 1
fi
