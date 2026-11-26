---
name: verify-work
description: Run the build/test/lint feedback loop and paste the output before reporting any work item done. Use at Stage 4 (Test), after every work item.
---

# Verify work

Stage 4 (Test). Every session checks its own work before a human sees it. Run
the loop after **every** work item, not once at the end, and paste the literal
toolchain output.

## Commands (from Makefile / CLAUDE.md)

- Build: `make build` — must finish `BUILD SUCCESSFUL`.
- Test: `make test` — all green.
- Integration tests: `make itest` — `./gradlew check` (runs `src/itest/java`;
  Testcontainers PostgreSQL needs Docker).
- Lint: `make lint` — `./gradlew checkstyleMain checkstyleTest`; zero violations.

Run all four before reporting a task complete and paste the output into the
commit/PR summary.

## One verification CLI (reuse it, don't rebuild per session)

- `bash scripts/app-verify.sh all` — build + unit + integration + checkstyle (Java),
  or `npm test && npm run build` (frontend). Also `make verify`.
- `bash scripts/app-verify.sh smoke` — start the app and probe `/actuator/health`.
- Keep `feature-map.md` current: feature → requirement → verification → status.

## Bug fixes — the failing test comes first

1. Reproduce the bug as a test, run it, confirm it fails for the expected reason,
   and commit that test.
2. Then make it pass **without editing the test**. During a fix task a hook blocks
   edits to `src/test/` and `src/itest/`. A test that existed before the fix and
   the agent could not rewrite is the proof the bug is gone.

## Never

- Skip, delete, or weaken a check to make it pass. **Fix the code, not the test.**
- Report "done" without the pasted output.

## Done when

Build/test/lint/itest are green and their output is pasted. Metrics: first-pass
CI success rate for agent-written changes.
