#!/usr/bin/env bash
# scripts/sync-cognition.sh — distribute the project's cognition pack to a service repo
# (local simulation of the P3 "cognition pack version lock" flow).
# Usage: scripts/sync-cognition.sh <management-repo> <service-repo>
set -euo pipefail
MGMT="${1:-}"; SVC="${2:-}"
[ -n "$MGMT" ] && [ -n "$SVC" ] && [ -d "$SVC" ] || {
  echo "Usage: $0 <management-repo> <service-repo>" >&2; exit 1; }
PACK="$(cd "$MGMT" && pwd)/knowledge/pack.json"
[ -f "$PACK" ] || { echo "ERROR: missing $PACK" >&2; exit 1; }
[ -f "$SVC/service.json" ] || { echo "ERROR: $SVC is not a service repo (no service.json)" >&2; exit 1; }

mkdir -p "$SVC/.sdlc"
cp "$PACK" "$SVC/.sdlc/cognition-pack.json"
VER="$(jq -r '.metadata.version' "$PACK")"
jq --arg v "$VER" '.cognitionPack.version = $v' "$SVC/service.json" > "$SVC/service.json.tmp"
mv "$SVC/service.json.tmp" "$SVC/service.json"
echo "synced cognition pack v$VER -> $SVC/.sdlc/cognition-pack.json (service.json pinned)"
