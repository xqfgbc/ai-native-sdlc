#!/usr/bin/env bash
# scripts/selftest.sh — end-to-end self-test of the framework.
# Generates a demo project + 2 service repos in a temp dir, runs the collect/analyze/promote/sync
# loop, and asserts the artifacts. Used by CI and humans. Does not touch the workspace.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0
ok() { echo "PASS: $1"; pass=$((pass+1)); }
bad() { echo "FAIL: $1"; fail=$((fail+1)); }

# 1. scaffold
"$ROOT/scripts/new-project.sh" demo "$WORK/demo-management" >/dev/null
[ -f "$WORK/demo-management/loop/04-build/services.json" ] && ok "new-project creates management repo" || bad "new-project"
[ -f "$WORK/demo-management/scripts/analyze-reports.sh" ] && ok "management repo is self-contained" || bad "self-contained"
( cd "$WORK/demo-management" && bash scripts/validate-project.sh . >/dev/null ) && ok "fresh management repo validates (empty registry, no reports)" || bad "validate empty project"

# 1b. repo naming rules (--print-name derives the repo dir without side effects)
name_of() { "$ROOT/scripts/new-service-repo.sh" --print-name "$1" "$2" "$WORK/demo-management" 2>/dev/null; }
[ "$(name_of business speaker)" = "demo-speaker-management" ] && ok "naming: business -> <project>-<service>-management" || bad "naming business"
[ "$(name_of gateway api)" = "demo-api-gateway" ] && ok "naming: gateway -> <project>-<usage>-gateway" || bad "naming gateway"
[ "$(name_of infra aws)" = "demo-aws-infra" ] && ok "naming: infra -> <project>-<cloud>-infra" || bad "naming infra"
[ "$(name_of config-server config-server)" = "demo-config-server" ] && ok "naming: config-server -> <project>-config-server" || bad "naming config-server"
[ "$(name_of configuration-data prod)" = "demo-prod-configuration-data" ] && ok "naming: configuration-data prod" || bad "naming prod config"
[ "$(name_of configuration-data devops)" = "demo-devops-configuration-data" ] && ok "naming: configuration-data devops" || bad "naming devops config"
if "$ROOT/scripts/new-service-repo.sh" business speaker "$WORK/demo-management" "$WORK/wrong-repo-name" >/dev/null 2>&1; then
  bad "naming gate rejects non-conforming target"
else
  ok "naming gate rejects non-conforming target"
fi

"$ROOT/scripts/new-service-repo.sh" business order-service "$WORK/demo-management" "$WORK/demo-order-service-management" >/dev/null
"$ROOT/scripts/new-service-repo.sh" frontend-vue web-portal "$WORK/demo-management" "$WORK/demo-web-portal-management" >/dev/null
"$ROOT/scripts/new-service-repo.sh" configuration-data devops "$WORK/demo-management" "$WORK/demo-devops-configuration-data" >/dev/null
[ -f "$WORK/demo-devops-configuration-data/service.json" ] && ok "configuration-data template generates a repo" || bad "configuration-data template"
[ "$(jq -r .type "$WORK/demo-devops-configuration-data/service.json")" = "configuration-data" ] && ok "configuration-data service.json type" || bad "configuration-data type"
[ -f "$WORK/demo-order-service-management/.sdlc/config.json" ] && ok "new-service-repo creates service repo" || bad "new-service-repo"
[ -d "$WORK/demo-order-service-management/.agents/skills" ] && ok "D8: .agents/skills present" || bad "D8 skills"
[ -f "$WORK/demo-order-service-management/.github/workflows/collect.yml" ] && ok "service repo collect workflow (C1)" || bad "collect workflow"
[ -f "$WORK/demo-order-service-management/scripts/upload-report.sh" ] && ok "service repo upload script (C2)" || bad "upload script"
[ -f "$WORK/demo-order-service-management/scripts/app-verify.sh" ] && ok "service repo unified verify CLI" || bad "app-verify"
[ -f "$WORK/demo-order-service-management/feature-map.md" ] && ok "feature map seeded" || bad "feature-map"
[ -f "$WORK/demo-order-service-management/scripts/autopilot-gate.sh" ] && ok "trust ladder autopilot gate" || bad "autopilot-gate"
[ -f "$WORK/demo-order-service-management/scripts/scan-findings.sh" ] && ok "scanner findings tooling" || bad "scan-findings"
[ -f "$WORK/demo-order-service-management/findings/inbox.md" ] && ok "findings inbox seeded" || bad "findings inbox"
[ -f "$WORK/demo-management/scripts/intake.sh" ] && ok "management intake script" || bad "intake script"
( cd "$WORK/demo-management" && bash scripts/intake.sh >/dev/null ) && \
  [ -n "$(ls "$WORK/demo-management/intake/candidates/"*.md 2>/dev/null || true)" ] && \
  ok "intake clusters signals into candidates" || bad "intake candidate"
( cd "$WORK/demo-management" && bash scripts/intake-signal.sh onboarding "Slack: signup slow" "body" >/dev/null )
sig="$(ls "$WORK/demo-management/intake/signals/"*.md 2>/dev/null | grep -v 'README.md' | grep -v 'example-signal' | head -1 || true)"
[ -n "$sig" ] && ok "intake-signal writes a channel signal" || bad "intake-signal"
[ -f "$WORK/demo-web-portal-management/package.json" ] && ok "frontend-vue template has build content" || bad "frontend-vue build"

# 2. registry
[ "$(jq '.services|length' "$WORK/demo-management/loop/04-build/services.json")" = "3" ] && ok "registry has 3 services" || bad "registry"

# 3. commit + collect twice (hash chain + candidates + session-log)
( cd "$WORK/demo-order-service-management" && mkdir -p sdlc/session-log \
  && printf '%s\n' '# session 20260101-0000' '' '## 人的指令' '- build the order status endpoint' '' '## 规则缺口' '- prefer RestClient over RestTemplate' > sdlc/session-log/20260101-0000.md \
  && echo "# demo" >> README.md && git add -A \
  && git commit -q -m "feat: order status [learn] prefer @ServiceConnection" \
  && bash .sdlc/collect.sh >/dev/null )
( cd "$WORK/demo-order-service-management" && echo "more" >> README.md && git add -A \
  && git commit -q -m "fix: null status [learn] prefer @ServiceConnection" && bash .sdlc/collect.sh >/dev/null )
REPORTS=( "$WORK/demo-management/execution/build/order-service/reports/"*.json )
[ "${#REPORTS[@]}" -eq 2 ] && ok "two reports uploaded (idempotent)" || bad "reports count"
chain_ok=0
for f in "${REPORTS[@]}"; do [ -n "$(jq -r '.metadata.prevHash' "$f")" ] && chain_ok=1; done
[ "$chain_ok" -eq 1 ] && ok "hash chain: prevHash set" || bad "hash chain"
cand_total="$(jq '.spec.candidateKnowledge|length' "${REPORTS[@]}" | awk '{s+=$1} END{print s+0}')"
[ "$cand_total" -ge 1 ] && ok "candidate knowledge extracted" || bad "candidate knowledge"
session_ok=0
for f in "${REPORTS[@]}"; do
  jq -e '.spec.candidateKnowledge[]? | select(.evidenceRefs[]? | contains("session-log"))' "$f" >/dev/null 2>&1 && session_ok=1
done
[ "$session_ok" -eq 1 ] && ok "session-log derived candidate (D1)" || bad "session-log candidate"

# 4. analyze + validate
( cd "$WORK/demo-management" && bash scripts/analyze-reports.sh . >/dev/null )
[ -f "$WORK/demo-management/wiki/index.md" ] && ok "analyzer generates wiki" || bad "wiki"
prop="$(cd "$WORK/demo-management" && ls knowledge/proposals/*.json 2>/dev/null | head -1 | xargs -n1 basename 2>/dev/null | sed 's/\.json$//' || true)"
[ -n "$prop" ] && ok "analyzer creates proposal (proposed, not active)" || bad "proposal"
rep_ok=0
for p in "$WORK/demo-management/knowledge/proposals/"*.json; do
  [ -f "$p" ] || continue
  [ "$(jq -r '.repeat // false' "$p")" = "true" ] && rep_ok=1
done
[ "$rep_ok" -eq 1 ] && ok "distillation repeat detection (D4)" || bad "D4 repeat detection"
( cd "$WORK/demo-management" && bash scripts/validate-project.sh . >/dev/null ) && ok "validate-project passes" || bad "validate-project"
[ -f "$WORK/demo-management/loop/05-test/results.md" ] && ok "test management results (E1)" || bad "test results (E1)"
[ -f "$WORK/demo-management/wiki/dora.md" ] && ok "DORA metrics (E2)" || bad "dora (E2)"
# Simulate a deploy report to exercise DORA lead-time computation.
DEP_DIR="$WORK/demo-management/execution/deploy/order-service/reports"
mkdir -p "$DEP_DIR"
cp "$(ls "$WORK/demo-management/execution/build/order-service/reports/"*.json | head -1)" "$DEP_DIR/deploy.json"
( cd "$WORK/demo-management" && bash scripts/analyze-reports.sh . >/dev/null )
grep -qE 'Lead time for changes \| [0-9]' "$WORK/demo-management/wiki/dora.md" && ok "DORA lead time computed (P2)" || bad "dora lead time"

# 5. cognition closed loop (D2/D3)
if [ -n "$prop" ]; then
  ( cd "$WORK/demo-management" && bash scripts/promote-proposal.sh . "$prop" tester@example.com deterministic >/dev/null )
  ver="$(jq -r '.metadata.version' "$WORK/demo-management/knowledge/pack.json")"
  [ "$ver" != "0.1.0" ] && ok "promote-proposal bumps pack version ($ver)" || bad "pack version bump"
  [ -f "$WORK/demo-management/knowledge/guardrails/$prop.md" ] && ok "deterministic guardrail stub" || bad "guardrail stub"
  ( cd "$WORK/demo-management" && bash scripts/sync-cognition.sh . "$WORK/demo-order-service-management" >/dev/null )
  [ -f "$WORK/demo-order-service-management/.sdlc/cognition-pack.json" ] && ok "sync-cognition distributes pack" || bad "sync-cognition"
else
  bad "no proposal to promote"
fi

# 6. framework skills config
"$ROOT/scripts/validate-skills.sh" >/dev/null && ok "validate-skills passes" || bad "validate-skills"

echo ""
echo "selftest: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
