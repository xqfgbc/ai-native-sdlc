---
name: implement-change
description: Execute the accepted plan.md work items in order, verifying after each. Use at Stage 3b (Build) after the engineer accepts the plan.
---

# Implement change

Stage 3b (Build). Execute the accepted `plan.md` work items in order, verifying
after each, and commit so each commit names the plan work item it implements.

## Steps

1. Re-read the accepted `plan.md` and follow its file list and order exactly.
2. For a new module, run `scaffold-microservice` first (it wraps
   `scripts/new-service-repo.sh`).
3. Implement one work item at a time. Follow `spring-service-conventions`
   (api/ | core/ | adapters/ layering), `secure-api-review` (endpoints), and
   `resiliency-review` (outbound calls).
4. After every work item run the `verify-work` loop: `make build && make lint &&
   make test && make itest`, and paste the output into the commit body.
5. Commit per work item: `[AI-Agent] #<ticket|N/A> feat: <work item>` / `fix: <work item>`.
6. If reality departs from the plan, update `plan.md` in the same commit.
7. When done, open a PR titled `[<slug>] <title>`, linking the intent folder and
   pasting the verification output block.

## Guardrails (never violate)

- Do not edit `build/`, `.gradle/`, or generated schema classes.
- During a bug-fix task never edit `src/test/` or `src/itest/` after the failing
  test is committed.
- Do not bump dependency versions (platform-owned) or add dependencies outside
  the platform BOM without recording the reason in the PR description.

## Done when

All work items are committed, verification is green and pasted, and the PR is
open awaiting review.
