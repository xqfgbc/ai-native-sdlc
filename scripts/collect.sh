#!/usr/bin/env bash
# scripts/collect.sh — client-side collector. Runs inside a service repo at commit:
# collects the delta since lastCollectedSha (deterministic facts), turns [learn] markers
# into candidate knowledge, writes sync/reports/<toSha>.json, uploads it to the
# management repo (idempotent on toSha) and advances the hash chain.
# Usage: bash .sdlc/collect.sh   (or scripts/collect.sh when cwd is the service repo)
set -euo pipefail
SVC_DIR="$(pwd)"
CONFIG="$SVC_DIR/.sdlc/config.json"
[ -f "$CONFIG" ] || { echo "ERROR: run inside a service repo with .sdlc/config.json" >&2; exit 1; }

SERVICE="$(jq -r .service "$CONFIG")"
TYPE="$(jq -r .type "$CONFIG")"
MGMT="$(jq -r .managementRepo "$CONFIG")"
LAST="$(jq -r '.lastCollectedSha // ""' "$CONFIG")"
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
STAGE="build"
echo "$SUBJECTS" | grep -qiE '^(test|测试)' && STAGE="test"
echo "$SUBJECTS" | grep -qiE '^(deploy|发布)' && STAGE="deploy"
echo "$SUBJECTS" | grep -qiE '^(chore|docs)' && STAGE="maintain"

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

if [ -d "$MGMT" ]; then
  DEST="$MGMT/execution/$STAGE/$SERVICE/reports"
  mkdir -p "$DEST"
  if [ -f "$DEST/$TO.json" ]; then
    echo "collect: report already uploaded ($TO), idempotent skip"
  else
    cp "$SVC_DIR/sync/reports/$TO.json" "$DEST/$TO.json"
    echo "collect: uploaded $SERVICE $FROM..$TO -> $DEST/$TO.json"
  fi
else
  echo "collect: remote management repo ($MGMT); report left at sync/reports/$TO.json for scripts/upload-report.sh"
fi

jq --arg to "$TO" '.lastCollectedSha=$to' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
jq -n --arg h "$HASH" '{lastHash:$h}' > "$SVC_DIR/sync/state.json"
echo "collect: review=$REVIEW candidates=$(echo "$CANDIDATES" | jq 'length') prevHash=${PREV_HASH:0:12}"
