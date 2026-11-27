#!/usr/bin/env bash
# scripts/validate-project.sh — validate a management repo's registry, reports, and pack.
# Usage: scripts/validate-project.sh [management-repo-dir]
set -euo pipefail
MGMT="."; STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --strict) STRICT=1; shift ;;
    *) MGMT="$1"; shift ;;
  esac
done
cd "$MGMT"
fail=0
fail_msg() { echo "VALIDATE: $1" >&2; fail=1; }

# 1. services.json
REG="loop/04-build/services.json"
if [ ! -f "$REG" ]; then fail_msg "missing $REG"; else
  jq -e '.apiVersion == "sdlc/v1" and .kind == "ServiceRegistry" and (.services|type=="array")' "$REG" >/dev/null \
    || fail_msg "services.json invalid (apiVersion/kind/services)"
  jq -e '.services | all(has("name") and has("type") and has("repo") and has("phase") and has("requirements"))' "$REG" >/dev/null 2>&1 \
    || fail_msg "services.json: entry missing required fields"
fi

# 2. cognition pack
PACK="knowledge/pack.json"
if [ ! -f "$PACK" ]; then fail_msg "missing $PACK"; else
  jq -e '.apiVersion == "sdlc/v1" and .kind == "CognitionPack" and (.items|type=="array")' "$PACK" >/dev/null \
    || fail_msg "pack.json invalid"
  # S1 (service-local) rules must never be promoted into the project pack.
  jq -e '[.items[]|select(.scope? != null and .scope != "project")]|length==0' "$PACK" >/dev/null 2>&1 \
    || fail_msg "pack.json contains non-project scope (S1 stays in the service repo)"
fi

# 2b. cognition adoption consistency
#     services.json.cognitionPack.version is the version the service actually adopted
#     (0.0.0 = never synced). sync-cognition.sh updates it; fail on registry/pack or
#     registry/local-clone drift so a stale entry cannot look like a delivered rule.
if [ -f "$REG" ] && [ -f "$PACK" ]; then
  PACK_VER="$(jq -r '.metadata.version // empty' "$PACK")"
  if [ -n "$PACK_VER" ]; then
    while IFS=$'\t' read -r svc ver; do
      [ -n "$svc" ] || continue
      highest="$(printf '%s\n%s\n' "$ver" "$PACK_VER" | sort -V | tail -1)"
      if [ "$highest" = "$ver" ] && [ "$ver" != "$PACK_VER" ]; then
        fail_msg "services.json: $svc records pack v$ver but the control plane is at v$PACK_VER"
      fi

      repo="$(jq -r --arg n "$svc" '.services[]|select(.name==$n)|.repo' "$REG")"
      local_dir=""
      [ -d "$repo" ] && [ -f "$repo/service.json" ] && local_dir="$repo"
      if [ -z "$local_dir" ]; then
        sibling="$(dirname "$(pwd)")/${repo##*/}"
        [ -f "$sibling/service.json" ] && local_dir="$sibling"
      fi
      [ -n "$local_dir" ] || continue
      pinned="$(jq -r '.cognitionPack.version // empty' "$local_dir/service.json")"
      if [ -n "$pinned" ] && [ "$pinned" != "$ver" ]; then
        fail_msg "services.json: $svc records pack v$ver but $local_dir pins v$pinned (re-run sync-cognition.sh)"
      fi
    done <<< "$(jq -r '.services[]? | select(.cognitionPack.version? != null) | "\(.name)\t\(.cognitionPack.version)"' "$REG" 2>/dev/null || true)"
  fi
fi

# 2c. deterministic gates: a signed rule without evidence is a claim, not a gate.
#     Default = warning (legacy packs would otherwise block every push); --strict fails.
have_gate() { # <item-id>
  local id="$1" m
  if [ -f loop/04-build/gates/queue.json ] && \
     jq -e --arg id "$id" '[.items[]|select(.proposalId==$id and .status=="done")]|length>0' \
       loop/04-build/gates/queue.json >/dev/null 2>&1; then return 0; fi
  for m in $(ls guardrails/*/manifest.json 2>/dev/null || true); do
    jq -e --arg id "$id" '(.proposalId==$id or .id==$id)' "$m" >/dev/null 2>&1 && return 0
  done
  jq -e --arg id "$id" '.items[]|select(.id==$id and (.implementation.status // "") == "synced")' \
    knowledge/pack.json >/dev/null 2>&1 && return 0
  return 1
}
if [ -f "$PACK" ]; then
  gate_missing=0
  while IFS= read -r gid; do
    [ -n "$gid" ] || continue
    have_gate "$gid" || gate_missing=$((gate_missing+1))
  done <<< "$(jq -r '.items[]|select(.status=="active" and .enforcement=="deterministic")|.id' "$PACK")"
  if [ "$gate_missing" -gt 0 ]; then
    echo "VALIDATE: WARN: $gate_missing deterministic item(s) have no gate evidence (bash scripts/gate-queue.sh list)" >&2
    if [ "$STRICT" = 1 ]; then fail_msg "strict: deterministic items without gate evidence"; fi
  fi
fi

# 2d. project gate manifests must be applied to every appliesTo service.
if [ -d guardrails ]; then
  sync_missing=0
  for m in $(ls guardrails/*/manifest.json 2>/dev/null || true); do
    gid="$(jq -r '.id // ""' "$m" 2>/dev/null || true)"
    [ -n "$gid" ] || gid="$(basename "$(dirname "$m")")"
    while IFS= read -r svc; do
      [ -n "$svc" ] || continue
      repo="$(jq -r --arg n "$svc" '.services[]|select(.name==$n)|.repo // empty' "$REG" 2>/dev/null || true)"
      path=""
      if [ -n "$repo" ] && [ -d "$repo" ] && [ -f "$repo/service.json" ]; then path="$repo"
      elif [ -n "$repo" ]; then
        cand="$(dirname "$(pwd)")/${repo##*/}"
        [ -d "$cand" ] && [ -f "$cand/service.json" ] && path="$cand"
      fi
      if [ -z "$path" ]; then
        echo "VALIDATE: WARN: gate $gid cannot verify $svc (no local clone)" >&2
        sync_missing=$((sync_missing+1)); continue
      fi
      while IFS=$'\t' read -r src dest; do
        [ -n "$src" ] || continue
        if ! cmp -s "$(dirname "$m")/$src" "$path/$dest"; then
          echo "VALIDATE: WARN: gate $gid not synced to $svc: $dest" >&2
          sync_missing=$((sync_missing+1))
        fi
      done <<< "$(jq -r '.files[]? | [.src,.dest]|@tsv' "$m")"
    done <<< "$(jq -r '.appliesTo[]?' "$m")"
  done
  if [ "$sync_missing" -gt 0 ] && [ "$STRICT" = 1 ]; then
    fail_msg "strict: project gates are not synced to every appliesTo service"
  fi
fi

# 3. execution reports
REPORTS="$(find execution -path '*/reports/*.json' -type f 2>/dev/null || true)"
for f in $REPORTS; do
  jq -e '.apiVersion == "sdlc/v1" and .kind == "ExecutionReport" and (.metadata.service|length>0) and (.spec.stage|length>0)' "$f" >/dev/null \
    || fail_msg "report invalid: $f"
  # Local cognition is reported as evidence/context only; a statement here is a leak.
  jq -e '[.spec.localCognition[]? | select(has("statement"))] | length == 0' "$f" >/dev/null 2>&1 \
    || fail_msg "report leaks a local cognition statement: $f"
done

# 4. wiki generated (the wiki is derived from reports; with none, there is nothing to derive)
if [ -n "$REPORTS" ] && [ ! -f wiki/index.md ]; then
  fail_msg "missing wiki/index.md (run analyze-reports.sh)"
fi

if [ "$fail" -eq 0 ]; then
  echo "validate-project: OK ($(jq '.services|length' "$REG" 2>/dev/null || echo 0) services, $(echo "$REPORTS" | grep -c . || true) reports)"
else
  echo "validate-project: FAILED" >&2
fi
exit "$fail"
