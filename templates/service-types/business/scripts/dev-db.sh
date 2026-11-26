#!/usr/bin/env bash
# scripts/dev-db.sh — local PostgreSQL for this service (Podman).
# Usage: dev-db.sh [up|status|down|reset|logs]
# Env: DB_NAME DB_USER DB_PASSWORD DB_PORT POSTGRES_IMAGE (defaults: <service>/<service>/<service>/5432/postgres:17)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SERVICE="$(jq -r '.name // .service // "app"' service.json 2>/dev/null || echo app)"
DB_NAME="${DB_NAME:-$SERVICE}"
DB_USER="${DB_USER:-$SERVICE}"
DB_PASSWORD="${DB_PASSWORD:-$SERVICE}"
DB_PORT="${DB_PORT:-5432}"
POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:17}"
CONTAINER="${SERVICE}-db"
VOLUME="${SERVICE}-pgdata"
CMD="${1:-up}"

podman_ok() { podman info >/dev/null 2>&1; }

need_podman() {
  podman_ok && return 0
  echo "dev-db: podman not reachable; trying to start a machine ..." >&2
  podman machine start >/dev/null 2>&1 || true
  for _ in $(seq 1 60); do podman_ok && return 0; sleep 1; done
  echo "dev-db: ERROR podman is not usable. Check 'podman machine list' / 'podman system connection list'." >&2
  return 1
}

container_running() {
  podman container exists "$CONTAINER" 2>/dev/null \
    && [ "$(podman inspect -f '{{.State.Running}}' "$CONTAINER")" = "true" ]
}

wait_ready() {
  for _ in $(seq 1 60); do
    podman exec "$CONTAINER" pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1 && return 0
    sleep 1
  done
  echo "dev-db: ERROR database did not become ready; see 'bash scripts/dev-db.sh logs'" >&2
  return 1
}

case "$CMD" in
  up)
    need_podman
    if podman container exists "$CONTAINER" 2>/dev/null; then
      container_running || podman start "$CONTAINER" >/dev/null
    else
      if lsof -nP -iTCP:"$DB_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
        echo "dev-db: ERROR port $DB_PORT is already in use by another process" >&2
        exit 1
      fi
      podman volume exists "$VOLUME" 2>/dev/null || podman volume create "$VOLUME" >/dev/null
      podman run -d --name "$CONTAINER" \
        -e POSTGRES_DB="$DB_NAME" -e POSTGRES_USER="$DB_USER" -e POSTGRES_PASSWORD="$DB_PASSWORD" \
        -p "${DB_PORT}:5432" -v "${VOLUME}:/var/lib/postgresql/data" \
        --restart unless-stopped "$POSTGRES_IMAGE" >/dev/null
    fi
    wait_ready
    echo "dev-db: ready jdbc:postgresql://localhost:${DB_PORT}/${DB_NAME} user=${DB_USER} password=${DB_PASSWORD}"
    ;;
  status)
    need_podman
    echo "machine:   $(podman machine list --format '{{.Name}} {{.LastUp}}' 2>/dev/null | head -5)"
    echo "container: $(podman inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo absent)"
    if container_running; then
      podman exec "$CONTAINER" pg_isready -U "$DB_USER" -d "$DB_NAME" || true
      echo "jdbc:      jdbc:postgresql://localhost:${DB_PORT}/${DB_NAME}"
      echo "socket:    $(podman system connection list --format '{{.URI}}' | head -1)"
    fi
    ;;
  down)
    need_podman
    container_running && podman stop "$CONTAINER" >/dev/null && echo "dev-db: stopped $CONTAINER" || echo "dev-db: $CONTAINER not running"
    ;;
  reset)
    need_podman
    podman rm -f "$CONTAINER" >/dev/null 2>&1 || true
    podman volume rm "$VOLUME" >/dev/null 2>&1 || true
    echo "dev-db: removed container and volume"
    ;;
  logs)
    need_podman
    podman logs --tail 80 "$CONTAINER"
    ;;
  *)
    echo "usage: $0 [up|status|down|reset|logs]" >&2
    exit 1
    ;;
esac
