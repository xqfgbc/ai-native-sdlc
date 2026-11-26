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
"$ROOT/scripts/new-project.sh" demo "$WORK/demo-control-plane" >/dev/null
[ -f "$WORK/demo-control-plane/loop/04-build/services.json" ] && ok "new-project creates control-plane repo" || bad "new-project"
[ -f "$WORK/demo-control-plane/scripts/analyze-reports.sh" ] && ok "control-plane repo is self-contained" || bad "self-contained"
[ -f "$WORK/demo-control-plane/scripts/signoff.py" ] && ok "control-plane ships the sign-off web tool" || bad "signoff tool"
( cd "$WORK/demo-control-plane" && bash scripts/validate-project.sh . >/dev/null ) && ok "fresh control-plane repo validates (empty registry, no reports)" || bad "validate empty project"
[ -f "$WORK/demo-control-plane/.githooks/pre-commit" ] && [ -f "$WORK/demo-control-plane/hooks/no-secrets.sh" ] \
  && ok "control-plane repo ships the git hooks" || bad "control-plane hooks shipped"
[ "$(git -C "$WORK/demo-control-plane" config core.hooksPath 2>/dev/null)" = ".githooks" ] \
  && ok "control-plane repo enables core.hooksPath" || bad "control-plane core.hooksPath"
[ -f "$WORK/demo-control-plane/scripts/install-hooks.sh" ] && [ -f "$WORK/demo-control-plane/.claude/settings.json" ] \
  && ok "control-plane repo ships install-hooks.sh and agent settings" || bad "control-plane agent wiring"
mkdir -p "$WORK/demo-control-plane/execution/build/speaker"
printf '{}\n' > "$WORK/demo-control-plane/execution/build/speaker/report.json"
if ( cd "$WORK/demo-control-plane" && printf '{"tool_input":{"file_path":"%s"}}' \
    "execution/build/speaker/report.json" | bash hooks/protect-paths.sh ) >/dev/null 2>&1; then
  ok "protect-paths allows execution/<stage> artifacts"
else
  bad "protect-paths allows execution artifacts"
fi
[ "$("$ROOT/scripts/new-project.sh" --print-name demo)" = "demo-control-plane" ] && ok "naming: project control repo -> <project>-control-plane" || bad "naming control-plane"
if "$ROOT/scripts/new-project.sh" demo "$WORK/wrong-control-name" >/dev/null 2>&1; then
  bad "control-plane naming gate rejects non-conforming target"
else
  ok "control-plane naming gate rejects non-conforming target"
fi

# 1b. repo naming rules (--print-name derives the repo dir without side effects)
name_of() { "$ROOT/scripts/new-service-repo.sh" --print-name "$1" "$2" "$WORK/demo-control-plane" 2>/dev/null; }
[ "$(name_of business speaker)" = "demo-speaker-management" ] && ok "naming: business -> <project>-<service>-management" || bad "naming business"
[ "$(name_of gateway api)" = "demo-api-gateway" ] && ok "naming: gateway -> <project>-<usage>-gateway" || bad "naming gateway"
[ "$(name_of infra aws)" = "demo-aws-infra" ] && ok "naming: infra -> <project>-<cloud>-infra" || bad "naming infra"
[ "$(name_of config-server config-server)" = "demo-config-server" ] && ok "naming: config-server -> <project>-config-server" || bad "naming config-server"
[ "$(name_of configuration-data prod)" = "demo-prod-configuration-data" ] && ok "naming: configuration-data prod" || bad "naming prod config"
[ "$(name_of configuration-data devops)" = "demo-devops-configuration-data" ] && ok "naming: configuration-data devops" || bad "naming devops config"
if "$ROOT/scripts/new-service-repo.sh" business speaker "$WORK/demo-control-plane" "$WORK/wrong-repo-name" >/dev/null 2>&1; then
  bad "naming gate rejects non-conforming target"
else
  ok "naming gate rejects non-conforming target"
fi

"$ROOT/scripts/new-service-repo.sh" business order-service "$WORK/demo-control-plane" "$WORK/demo-order-service-management" >/dev/null
"$ROOT/scripts/new-service-repo.sh" frontend-vue web-portal "$WORK/demo-control-plane" "$WORK/demo-web-portal-management" >/dev/null
"$ROOT/scripts/new-service-repo.sh" configuration-data devops "$WORK/demo-control-plane" "$WORK/demo-devops-configuration-data" >/dev/null
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
[ -f "$WORK/demo-order-service-management/.githooks/pre-commit" ] && [ -f "$WORK/demo-order-service-management/hooks/no-secrets.sh" ] \
  && ok "service repo ships the git hooks" || bad "git hooks shipped"
[ "$(git -C "$WORK/demo-order-service-management" config core.hooksPath 2>/dev/null)" = ".githooks" ] \
  && ok "service repo enables core.hooksPath" || bad "core.hooksPath"
if ns_out="$( cd "$WORK/demo-order-service-management" \
    && printf 'AKIA%s\n' 'ABCDEFGHIJKLMNOP' > leak.txt \
    && git add leak.txt && git commit -q -m "leak" 2>&1 )"; then
  bad "installed pre-commit blocks a secret"
else
  printf '%s' "$ns_out" | grep -q 'no-secrets' && ok "installed pre-commit blocks a secret" || bad "installed pre-commit blocks a secret"
fi
( cd "$WORK/demo-order-service-management" && git reset -q && rm -f leak.txt )
[ -f "$WORK/demo-order-service-management/scripts/install-hooks.sh" ] && [ -f "$WORK/demo-order-service-management/.claude/settings.json" ] \
  && ok "service repo ships install-hooks.sh and agent settings" || bad "service repo agent wiring"
git -C "$WORK/demo-order-service-management" config --unset core.hooksPath 2>/dev/null || true
( cd "$WORK/demo-order-service-management" && bash scripts/install-hooks.sh >/dev/null ) \
  && [ "$(git -C "$WORK/demo-order-service-management" config core.hooksPath 2>/dev/null)" = ".githooks" ] \
  && ok "install-hooks.sh enables the hooks" || bad "install-hooks.sh"
( cd "$WORK/demo-order-service-management" && bash scripts/install-hooks.sh >/dev/null ) \
  && ok "install-hooks.sh is idempotent" || bad "install-hooks.sh idempotent"
jq -e '.hooks.SessionStart[0].hooks[0].command | test("install-hooks")' \
  "$WORK/demo-order-service-management/.claude/settings.json" >/dev/null 2>&1 \
  && ok "agent settings install the hooks on session start" || bad "session-start wiring"
[ -x "$WORK/demo-order-service-management/.githooks/commit-msg" ] \
  && ok "service repo ships the commit-msg gate" || bad "commit-msg shipped"
printf 'nope\n' > "$WORK/msg-bad.txt"
if ( cd "$WORK/demo-order-service-management" && bash .githooks/commit-msg "$WORK/msg-bad.txt" ) >/dev/null 2>&1; then
  bad "commit-msg rejects an untyped message"
else
  ok "commit-msg rejects an untyped message"
fi
printf '[AI-Agent] #N/A feat: add endpoint\n' > "$WORK/msg-good.txt"
( cd "$WORK/demo-order-service-management" && bash .githooks/commit-msg "$WORK/msg-good.txt" >/dev/null 2>&1 ) \
  && ok "commit-msg accepts the ticket-based format" || bad "commit-msg accepts the ticket-based format"
printf 'feat(speaker): legacy format\n' > "$WORK/msg-legacy.txt"
if ( cd "$WORK/demo-order-service-management" && bash .githooks/commit-msg "$WORK/msg-legacy.txt" ) >/dev/null 2>&1; then
  bad "commit-msg rejects the legacy type(scope) format"
else
  ok "commit-msg rejects the legacy type(scope) format"
fi
if printf '{"tool_input":{"command":"git commit -m \\"bad message\\""}}' | bash "$ROOT/hooks/commit-guard.sh" >/dev/null 2>&1; then
  bad "commit-guard blocks a bad subject before execution"
else
  ok "commit-guard blocks a bad subject before execution"
fi
printf '{"tool_input":{"command":"git commit -m \\"[AI-Agent] #N/A feat: ok\\""}}' | bash "$ROOT/hooks/commit-guard.sh" >/dev/null 2>&1 \
  && ok "commit-guard allows a conforming subject" || bad "commit-guard allows a conforming subject"
# Branch policy: release* requires a PR; every other branch may be pushed directly.
mkdir -p "$WORK/gate-repo/.githooks"
cp "$ROOT/.githooks/pre-push" "$WORK/gate-repo/.githooks/pre-push"
( cd "$WORK/gate-repo" && git init -q && git checkout -q -b main \
  && git -c user.name=gate -c user.email=gate@example.com commit -q --allow-empty -m "chore: init" )
( cd "$WORK/gate-repo" && SDL_SKIP_VERIFY=1 bash .githooks/pre-push >/dev/null 2>&1 ) \
  && ok "pre-push allows a direct push to main" || bad "pre-push direct push to main"
( cd "$WORK/gate-repo" && git checkout -q -b release/1.0 )
if ( cd "$WORK/gate-repo" && SDL_SKIP_VERIFY=1 bash .githooks/pre-push >/dev/null 2>&1 ); then
  bad "pre-push requires a PR for release branches"
else
  ok "pre-push requires a PR for release branches"
fi
git -C "$WORK/gate-repo" checkout -q main
if ( cd "$WORK/gate-repo" && printf 'refs/heads/release/9.9 %s refs/heads/release/9.9 %s\n' \
    "$(git rev-parse main)" "" | SDL_SKIP_VERIFY=1 bash .githooks/pre-push ) >/dev/null 2>&1; then
  bad "pre-push blocks a release ref pushed from another branch"
else
  ok "pre-push blocks a release ref pushed from another branch"
fi
[ -f "$WORK/demo-control-plane/scripts/intake.sh" ] && ok "management intake script" || bad "intake script"
( cd "$WORK/demo-control-plane" && bash scripts/intake.sh >/dev/null ) && \
  [ -n "$(ls "$WORK/demo-control-plane/intake/candidates/"*.md 2>/dev/null || true)" ] && \
  ok "intake clusters signals into candidates" || bad "intake candidate"
( cd "$WORK/demo-control-plane" && bash scripts/intake-signal.sh onboarding "Slack: signup slow" "body" >/dev/null )
sig="$(ls "$WORK/demo-control-plane/intake/signals/"*.md 2>/dev/null | grep -v 'README.md' | grep -v 'example-signal' | head -1 || true)"
[ -n "$sig" ] && ok "intake-signal writes a channel signal" || bad "intake-signal"
[ -f "$WORK/demo-web-portal-management/package.json" ] && ok "frontend-vue template has build content" || bad "frontend-vue build"

# 2. registry
[ "$(jq '.services|length' "$WORK/demo-control-plane/loop/04-build/services.json")" = "3" ] && ok "registry has 3 services" || bad "registry"

# 3. commit + collect twice (hash chain + candidates + session-log)
( cd "$WORK/demo-order-service-management" && mkdir -p sdlc/session-log \
  && printf '%s\n' '# session 20260101-0000' '' '## 人的指令' '- build the order status endpoint' '' '## 规则缺口' '- prefer RestClient over RestTemplate' > sdlc/session-log/20260101-0000.md \
  && echo "# demo" >> README.md && git add -A \
  && git commit -q -m "[AI-Agent] #N/A feat: order status [learn] prefer @ServiceConnection" \
  && bash .sdlc/collect.sh >/dev/null )
( cd "$WORK/demo-order-service-management" && echo "more" >> README.md && git add -A \
  && git commit -q -m "[AI-Agent] #N/A fix: null status [learn] prefer @ServiceConnection" && bash .sdlc/collect.sh >/dev/null )
REPORTS=( "$WORK/demo-control-plane/execution/build/order-service/reports/"*.json )
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
( cd "$WORK/demo-order-service-management" && echo "no-learn" >> README.md && git add -A \
  && git commit -q -m "[AI-Agent] #N/A chore: no knowledge marker" && bash .sdlc/collect.sh >/dev/null )
no_learn_sha="$(git -C "$WORK/demo-order-service-management" rev-parse HEAD)"
no_learn_report="$(find "$WORK/demo-control-plane/execution" -name "$no_learn_sha.json" | head -1)"
[ -n "$no_learn_report" ] && [ "$(jq -r '.spec.stage' "$no_learn_report")" = "maintain" ] \
  && [ "$(jq '.candidateKnowledge|length' "$no_learn_report")" = "0" ] \
  && ok "commits without [learn] produce no candidate" || bad "candidate filter (no [learn])"

# 4. analyze + validate
( cd "$WORK/demo-control-plane" && bash scripts/analyze-reports.sh . >/dev/null )
[ -f "$WORK/demo-control-plane/wiki/index.md" ] && ok "analyzer generates wiki" || bad "wiki"
prop="$(cd "$WORK/demo-control-plane" && ls knowledge/proposals/*.json 2>/dev/null | head -1 | xargs -n1 basename 2>/dev/null | sed 's/\.json$//' || true)"
[ -n "$prop" ] && ok "analyzer creates proposal (proposed, not active)" || bad "proposal"
rep_ok=0
for p in "$WORK/demo-control-plane/knowledge/proposals/"*.json; do
  [ -f "$p" ] || continue
  [ "$(jq -r '.repeat // false' "$p")" = "true" ] && rep_ok=1
done
[ "$rep_ok" -eq 1 ] && ok "distillation repeat detection (D4)" || bad "D4 repeat detection"
( cd "$WORK/demo-control-plane" && bash scripts/review-proposals.sh . >/dev/null )
review_file="$WORK/demo-control-plane/knowledge/reviews/$prop.json"
[ -f "$review_file" ] && [ -n "$(jq -r '.ai.suggestion // ""' "$review_file")" ] \
  && ok "AI proposal review generated" || bad "proposal review"
stats_out="$( cd "$WORK/demo-control-plane" && bash scripts/review-proposals.sh record "$prop" --decision promote-advisory --owner tester@example.com >/dev/null 2>&1; bash scripts/review-proposals.sh stats 2>&1 )"
printf '%s' "$stats_out" | grep -q "reviews with human decision: 1" \
  && ok "review decision recorded (agreement stats)" || { echo "  stats: $stats_out"; bad "review decision"; }
debt_id="$( cd "$WORK/demo-control-plane" && bash scripts/debt.sh add --kind tech --title "selftest debt" --priority P2 --due 2026-12-01 --owner tester --json | jq -r .id )"
( cd "$WORK/demo-control-plane" && bash scripts/debt.sh due --days 30 --json | jq -e --arg id "$debt_id" '.[]|select(.id==$id)' >/dev/null \
  && bash scripts/debt.sh close "$debt_id" --note selftest >/dev/null \
  && [ "$(jq -r --arg id "$debt_id" '.items[]|select(.id==$id)|.status' loop/07-maintain/debt/debt.json)" = "done" ] ) \
  && ok "debt registry add/due/close" || bad "debt registry"
( cd "$WORK/demo-control-plane" && bash scripts/validate-project.sh . >/dev/null ) && ok "validate-project passes" || bad "validate-project"
[ -f "$WORK/demo-control-plane/loop/05-test/results.md" ] && ok "test management results (E1)" || bad "test results (E1)"
[ -f "$WORK/demo-control-plane/wiki/dora.md" ] && ok "DORA metrics (E2)" || bad "dora (E2)"
# Simulate a deploy report to exercise DORA lead-time computation.
DEP_DIR="$WORK/demo-control-plane/execution/deploy/order-service/reports"
mkdir -p "$DEP_DIR"
cp "$(ls "$WORK/demo-control-plane/execution/build/order-service/reports/"*.json | head -1)" "$DEP_DIR/deploy.json"
( cd "$WORK/demo-control-plane" && bash scripts/analyze-reports.sh . >/dev/null )
grep -qE 'Lead time for changes \| [0-9]' "$WORK/demo-control-plane/wiki/dora.md" && ok "DORA lead time computed (P2)" || bad "dora lead time"

# 5. cognition closed loop (D2/D3)
if [ -n "$prop" ]; then
  ( cd "$WORK/demo-control-plane" && bash scripts/promote-proposal.sh . "$prop" tester@example.com deterministic >/dev/null )
  ver="$(jq -r '.metadata.version' "$WORK/demo-control-plane/knowledge/pack.json")"
  [ "$ver" != "0.1.0" ] && ok "promote-proposal bumps pack version ($ver)" || bad "pack version bump"
  [ -f "$WORK/demo-control-plane/knowledge/guardrails/$prop.md" ] && ok "deterministic guardrail stub" || bad "guardrail stub"
  [ -f "$WORK/demo-control-plane/knowledge/constraints/$prop.json" ] && ok "promoted item lands in knowledge/constraints" || bad "constraint directory"
  ( cd "$WORK/demo-control-plane" && bash scripts/sync-cognition.sh . "$WORK/demo-order-service-management" >/dev/null )
  [ -f "$WORK/demo-order-service-management/.sdlc/cognition-pack.json" ] && ok "sync-cognition distributes pack" || bad "sync-cognition"
  grep -q "$prop" "$WORK/demo-order-service-management/CLAUDE.md" && ok "sync renders active cognition into CLAUDE.md" || bad "cognition block"
  hook_out="$( cd "$WORK/demo-order-service-management" && bash hooks/cognition-context.sh 2>&1 )"
  printf '%s' "$hook_out" | grep -q "$prop" \
    && ok "session hook surfaces active cognition" || { echo "  hook: $hook_out"; bad "cognition hook"; }
else
  bad "no proposal to promote"
fi

# 6. deterministic guard hooks (agent mode works; stdin can never hang them)
printf 'clean\n' > "$WORK/clean.txt"
if ns_out="$(printf '{"tool_input":{"file_path":"%s"}}' "$WORK/clean.txt" | "$ROOT/hooks/no-secrets.sh" 2>&1)"; then
  printf '%s\n' "$ns_out" | grep -qx 'no-secrets: clean' && ok "no-secrets hook scans agent stdin JSON" || bad "no-secrets agent mode"
else
  bad "no-secrets agent mode"
fi
# Build the fake secret at runtime so this fixture does not trip the hook itself.
printf 'AKIA%s\n' 'ABCDEFGHIJKLMNOP' > "$WORK/leak.txt"
if ns_out="$(printf '{"tool_input":{"file_path":"%s"}}' "$WORK/leak.txt" | "$ROOT/hooks/no-secrets.sh" 2>&1)"; then
  bad "no-secrets blocks a secret from agent stdin"
else
  printf '%s' "$ns_out" | grep -q 'AKIA' && ok "no-secrets blocks a secret from agent stdin" || bad "no-secrets blocks a secret from agent stdin"
fi
# An open pipe with no data must not block the hook (watchdog kills it otherwise).
( "$ROOT/hooks/no-secrets.sh" < <(sleep 5) >"$WORK/no-secrets.out" 2>&1 ) & ns_pid=$!
( for _ in 1 2 3 4 5 6 7 8; do sleep 1; kill -0 "$ns_pid" 2>/dev/null || exit 0; done; kill "$ns_pid" 2>/dev/null ) &
if wait "$ns_pid" 2>/dev/null; then ns_rc=0; else ns_rc=$?; fi
[ "$ns_rc" -le 1 ] && [ -s "$WORK/no-secrets.out" ] && ok "no-secrets hook does not block on an open stdin pipe" || bad "no-secrets stdin hang"

# 7. framework skills config
"$ROOT/scripts/validate-skills.sh" >/dev/null && ok "validate-skills passes" || bad "validate-skills"

echo ""
echo "selftest: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
