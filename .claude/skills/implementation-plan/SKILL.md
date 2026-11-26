---
name: implementation-plan
description: Produce an accepted plan.md from spec.md before writing any code. Use at Stage 3a (Build), in plan mode, for every change that will touch code.
---

# Implementation plan

Stage 3a (Build). Nothing is implemented without an accepted plan. Start in plan
mode (read-only) so the plan is corrected while changing course is still just
editing a document.

## Steps

1. Read `intent.md` + `spec.md` for the change.
2. Draft `plan.md` from `docs/plan-template.md`: the exact files that change
   (including tests and gateway routes), the order of work, risks, and the proof
   that defines done.
3. Make the order of work **dependency-ordered and parallelizable** (spec-kit's
   `tasks.md` idea): tasks that share files run sequentially in one session;
   independent tasks may run in parallel worktrees.
4. Interrogate the plan: what could it break, which step is most risky, and what
   alternatives were rejected.
5. Iterate until an engineer who never saw the conversation could implement from
   the plan alone.
6. Commit `plan.md` (message `plan(<slug>): implementation plan`). The accepted
   plan joins the audit trail and the PR review later checks the diff against it.
7. When implementation departs from the plan, update `plan.md` in the same commit.

## Governance

Routine changes are approved by the engineer. Higher-risk changes (schema
migration, auth model, money handling, cross-service contract) escalate to a
tech lead/architect (see AGENTS.md §7).

## Done when

`plan.md` is committed and accepted by an engineer. Metrics: first-pass merge
share; rework cycles; merged-diff ↔ plan.md match.
