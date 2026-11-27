#!/usr/bin/env bash
# scripts/collect.sh — client-side collector. Runs inside a service repo at commit:
# collects the delta since lastCollectedSha (deterministic facts), turns [learn] markers
# into candidate knowledge, writes sync/reports/<toSha>.json, uploads it to the
# management repo (idempotent on toSha) and advances the hash chain.
# Usage: bash .sdlc/collect.sh [--resolve-mgmt]
#   --resolve-mgmt  print the resolved management repo and exit (exit 1 when not found)
set -euo pipefail
SVC_DIR="$(pwd)"
CONFIG="$SVC_DIR/.sdlc/config.json"
[ -f "$CONFIG" ] || { echo "ERROR: run inside a service repo with .sdlc/config.json" >&2; exit 1; }

SERVICE="$(jq -r .service "$CONFIG")"
TYPE="$(jq -r .type "$CONFIG")"
CFG_MGMT="$(jq -r '.managementRepo // empty' "$CONFIG")"
PROJECT="$(jq -r '.project // empty' "$CONFIG")"
if [ -z "$PROJECT" ] && [ -f "$SVC_DIR/service.json" ]; then
  PROJECT="$(jq -r '.project // empty' "$SVC_DIR/service.json" 2>/dev/null || true)"
fi
PARENT="$(cd "$SVC_DIR/.." && pwd)"
SIBLING=""
if [ -n "$PROJECT" ]; then SIBLING="$PARENT/$PROJECT-control-plane"; fi
if [ -z "$SIBLING" ] || [ ! -d "$SIBLING" ]; then
  shopt -s nullglob
  cands=("$PARENT"/*-control-plane)
  shopt -u nullglob
  if [ "${#cands[@]}" -eq 1 ]; then SIBLING="${cands[0]}"; fi
fi

# Resolution: SDL_MGMT_REPO (authoritative) -> sibling <project>-control-plane -> config.
# An explicit but wrong SDL_MGMT_REPO fails loudly instead of falling back, so an
# offline run can never upload into the wrong project.
MGMT=""
if [ -n "${SDL_MGMT_REPO:-}" ]; then
  MGMT="$SDL_MGMT_REPO"
  [ -d "$MGMT" ] || echo "collect: SDL_MGMT_REPO points to a missing directory: $MGMT" >&2
else
  if [ -n "$SIBLING" ] && [ -d "$SIBLING" ]; then
    MGMT="$SIBLING"
  elif [ -n "$CFG_MGMT" ] && [ -d "$CFG_MGMT" ]; then
    MGMT="$CFG_MGMT"
  fi
fi

if [ "${1:-}" = "--resolve-mgmt" ]; then
  if [ -n "$MGMT" ] && [ -d "$MGMT" ]; then echo "$MGMT"; exit 0; fi
  echo "collect: management repo not found (SDL_MGMT_REPO=${SDL_MGMT_REPO:-unset} sibling=${SIBLING:-none} config=${CFG_MGMT:-none})" >&2
  exit 1
fi

LAST="$(jq -r '.lastCollectedSha // ""' "$CONFIG")"
LAST_UP="$(jq -r '.lastUploadedSha // ""' "$CONFIG")"
# Upgrade path for repos created before lastUploadedSha existed: past collects
# were uploaded, so start the upload cursor at the collect cursor.
[ -n "$LAST_UP" ] || LAST_UP="$LAST"
TO="$(git rev-parse HEAD)"
if [ -n "$LAST" ] && [ "$LAST" = "$TO" ]; then
  echo "collect: no new commits (already at $TO)"; exit 0
fi
if [ -z "$LAST" ]; then
  FROM="$(git rev-list --max-parents=0 HEAD | tail -1)"
else
  FROM="$LAST"
fi

COMMITS="$(git log --format=%H "$FROM..$TO" 2>/dev/null | jq -R -s 'split("\n")|map(select(length>0))')"
FILES_RAW="$(git diff --name-status "$FROM" "$TO" 2>/dev/null | awk '{print $2}' | grep -vE '^(\.sdlc/|sync/)' || true)"
CHANGED="$(printf '%s\n' "$FILES_RAW" | jq -R -s 'split("\n")|map(select(length>0))')"
N_FILES="$(echo "$CHANGED" | jq 'length')"
REQS="$( { git log --format=%s "$FROM..$TO" 2>/dev/null | grep -oE 'REQ-[0-9]+' | sort -u | jq -R -s 'split("\n")|map(select(length>0))'; } 2>/dev/null || true )"
REQS="${REQS:-[]}"

# Layer inference from changed file paths.
LAYERS="$( { echo "$CHANGED" | jq -r '.[]' | grep -oE '/(api|core|adapters)/' | tr -d '/' | sort -u | jq -R -s 'split("\n")|map(select(length>0))'; } 2>/dev/null || true )"
LAYERS="${LAYERS:-[]}"

# A3: tests from Gradle reports (if a build ran), architecture signal, dependency files changed.
TESTS='{}'
if [ -d build/test-results ]; then
  T_TOTAL="$( { grep -rho 'tests="[0-9]*"' build/test-results 2>/dev/null | grep -oE '[0-9]+' | awk '{s+=$1} END{print s+0}'; } || true )"
  T_FAIL="$( { grep -rho 'failures="[0-9]*"' build/test-results 2>/dev/null | grep -oE '[0-9]+' | awk '{s+=$1} END{print s+0}'; } || true )"
  TESTS="$(jq -n --argjson t "${T_TOTAL:-0}" --argjson f "${T_FAIL:-0}" '{unit:{total:$t,failed:$f}}')"
fi
ARCH_PRESENT=false
[ -n "$(find . -name 'ArchitectureTest.java' -not -path './build/*' 2>/dev/null | head -1)" ] && ARCH_PRESENT=true
ARCH="$(jq -n --argjson p "$ARCH_PRESENT" '{archUnitTest:$p}')"
DEPS="$( { echo "$CHANGED" | jq -r '.[]' | grep -E 'libs\.versions\.toml|build\.gradle\.kts|pom\.xml' | jq -R -s 'split("\n")|map(select(length>0))'; } 2>/dev/null || true )"
DEPS="${DEPS:-[]}"

# Stage heuristic from commit subjects.
SUBJECTS="$(git log --format=%s "$FROM..$TO" 2>/dev/null || true)"
# Strip the "[name] #ticket " commit prefix before classifying the stage.
SUBJECT_BODY="$(echo "$SUBJECTS" | sed -E 's/^\[[^]]+\][[:space:]]+#[^[:space:]]+[[:space:]]+//')"
STAGE="build"
echo "$SUBJECT_BODY" | grep -qiE '^(test|测试)' && STAGE="test"
echo "$SUBJECT_BODY" | grep -qiE '^(deploy|发布)' && STAGE="deploy"
echo "$SUBJECT_BODY" | grep -qiE '^(chore|docs)' && STAGE="maintain"

# A4/D18: redact secret-looking content before persisting anything.
scrub() {
  sed -E 's/(AKIA[0-9A-Z]{16})/***REDACTED***/g; s/(ASIA[0-9A-Z]{16})/***REDACTED***/g; s/(ghp_[A-Za-z0-9]{20,})/***REDACTED***/g; s/(gho_[A-Za-z0-9]{20,})/***REDACTED***/g; s/(sk-[A-Za-z0-9]{20,})/***REDACTED***/g; s/(github_pat_[A-Za-z0-9_]+)/***REDACTED***/g; s/(xox[baprs]-[A-Za-z0-9-]+)/***REDACTED***/g; s/(-----BEGIN [A-Z ]*PRIVATE KEY-----).*/***REDACTED***/g'
}

# [learn] markers -> candidate knowledge (deterministic extraction; evidenceRef = commit sha).
CANDIDATES="[]"
while IFS= read -r line; do
  [ -n "$line" ] || continue
  subject="$(echo "$line" | cut -d'|' -f2-)"
  sha="$(echo "$line" | cut -d'|' -f1)"
  # Only subjects that carry the explicit marker become candidates; a plain
  # commit is an execution fact, not knowledge.
  case "$subject" in *"[learn]"*) ;; *) continue ;; esac
  proposal="$(echo "$subject" | sed -E 's/.*\[learn\][[:space:]]*//' | scrub)"
  [ -n "$proposal" ] || continue
  CANDIDATES="$(echo "$CANDIDATES" | jq --arg p "$proposal" --arg s "$sha" \
    '. + [{type:"constraint", title:$p, proposal:$p, evidenceRefs:["commit:"+$s]}]')"
done <<< "$(git log --format='%H|%s' "$FROM..$TO" 2>/dev/null || true)"

# D1: derive candidate knowledge from committed session-log files (规则缺口 section).
SESSION_FILES="$(git log --name-only --format= "$FROM..$TO" 2>/dev/null | grep -E '^sdlc/session-log/.*\.md$' | sort -u || true)"
if [ -n "$SESSION_FILES" ]; then
  while IFS= read -r sl; do
    [ -z "$sl" ] && continue
    [ -f "$sl" ] || continue
    RULES="$(awk '/规则缺口|Rule gaps?/{f=1;next} /^## /{f=0} f && /^- /{sub(/^- /,""); print}' "$sl" 2>/dev/null | scrub || true)"
    while IFS= read -r rule; do
      [ -n "$rule" ] || continue
      CANDIDATES="$(echo "$CANDIDATES" | jq --arg p "$rule" --arg s "$sl" \
        '. + [{type:"constraint", title:$p, proposal:$p, evidenceRefs:[$s]}]')"
    done <<< "$RULES"
  done <<< "$SESSION_FILES"
fi

PREV_HASH="$(jq -r '.lastHash // ""' "$SVC_DIR/sync/state.json" 2>/dev/null || echo "")"
REVIEW="auto"
[ "$N_FILES" -gt 20 ] && REVIEW="needs_review"
[ -z "$(git log --format=%s "$FROM..$TO" 2>/dev/null | head -1)" ] && REVIEW="needs_review"

REPORT="$(jq -n \
  --arg svc "$SERVICE" --arg type "$TYPE" --arg stage "$STAGE" \
  --arg from "$FROM" --arg to "$TO" --arg review "$REVIEW" --arg prev "$PREV_HASH" \
  --argjson commits "$COMMITS" --argjson files "$CHANGED" --argjson reqs "$REQS" \
  --argjson layers "$LAYERS" --argjson cand "$CANDIDATES" --argjson tests "$TESTS" --argjson arch "$ARCH" --argjson deps "$DEPS" '
  {
    apiVersion: "sdlc/v1", kind: "ExecutionReport",
    metadata: { service:$svc, repo:"", type:$type, agent:"collector", trigger:"commit",
                fromSha:$from, toSha:$to, createdAt:(now|todate), prevHash:$prev },
    spec: { stage:$stage, requirementRefs:$reqs,
            facts: { commits:$commits, filesChanged:$files, layers:$layers,
                     tests:$tests, architectureSignals:$arch, dependencyFilesChanged:$deps },
            interactions: [], decisions: [], ruleViolations: [],
            candidateKnowledge: $cand, review: { status:$review } }
  }')"

HASH="$(printf '%s' "$REPORT" | (command -v sha256sum >/dev/null && sha256sum || shasum -a 256) | awk '{print $1}')"

mkdir -p "$SVC_DIR/sync/reports"
echo "$REPORT" > "$SVC_DIR/sync/reports/$TO.json"

UPLOADED=0
if [ -n "$MGMT" ] && [ -d "$MGMT" ]; then
  DEST="$MGMT/execution/$STAGE/$SERVICE/reports"
  mkdir -p "$DEST"
  if [ -f "$DEST/$TO.json" ]; then
    echo "collect: report already uploaded ($TO), idempotent skip"
  else
    cp "$SVC_DIR/sync/reports/$TO.json" "$DEST/$TO.json"
    echo "collect: uploaded $SERVICE $FROM..$TO -> $DEST/$TO.json"
  fi
  UPLOADED=1
else
  if [ -n "${SDL_MGMT_REPO:-}" ]; then
    echo "collect: management repo not found at $MGMT (SDL_MGMT_REPO); report kept at sync/reports/$TO.json" >&2
  elif [ -n "$MGMT" ]; then
    echo "collect: management repo is not a local directory ($MGMT); report kept at sync/reports/$TO.json (use scripts/replay-reports.sh or upload-report.sh)" >&2
  else
    echo "collect: management repo not found (SDL_MGMT_REPO=${SDL_MGMT_REPO:-unset} sibling=${SIBLING:-none} config=${CFG_MGMT:-none}); report kept at sync/reports/$TO.json" >&2
  fi
  echo "collect: run scripts/replay-reports.sh <management-repo> once it is available" >&2
fi

if [ "$UPLOADED" = "1" ]; then LAST_UP="$TO"; fi
jq --arg to "$TO" --arg up "$LAST_UP" '.lastCollectedSha=$to | .lastUploadedSha=$up' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
jq -n --arg h "$HASH" '{lastHash:$h}' > "$SVC_DIR/sync/state.json"
echo "collect: review=$REVIEW candidates=$(echo "$CANDIDATES" | jq 'length') prevHash=${PREV_HASH:0:12}"
