---
name: pr-review
description: Review a PR with the three-pass policy in REVIEW.md and address review comments on your own PRs. Use at Stage 5 (Deploy).
---

# PR review

Stage 5 (Deploy). Review runs in both directions: review incoming PRs, and handle
review feedback on your own PRs. Findings do **not** approve or block a PR by
themselves — branch protection still requires a code owner.

## Reviewing (incoming PR)

1. Load the `code-quality` skill for the checklist; follow `REVIEW.md` for what to
   report. Fix the scope: review `git diff <base>...HEAD` (default `main...HEAD`).
2. Run three passes and tag each finding:
   - **Bugs** — logic, edge cases, regressions, transactions/JPA/concurrency
     (`@Transactional` scope/self-invocation, entity leaks, N+1, `open-in-view`).
   - **Security** — injection, auth gaps, PII in logs, secrets, missing validation,
     agentic-app risks (untrusted input into a tool/agent — OWASP ASI01/ASI10).
   - **Compliance** — matches `spec.md`/`plan.md`, follows `CLAUDE.md` and the
     `spring-service-conventions`/`spring-data-jpa`/`spring-testing` skills,
     respects the generated `ArchitectureTest`, outbound calls meet
     `resiliency-review`, deployment changes follow `gitops-deploy`.
3. Every finding is citable: `File.java:line` + a quoted snippet + the rule it
   breaks. **Skip what linters/CI already enforce.**
4. Report **Important** for anything that breaks behavior, leaks data, or breaches
   policy; cap nits at five (summarize the rest as a count). Calibrated, concise.

## Handling review comments on your PR

Load `review-triage`. Remarks are hypotheses: verify each, then accept / partly
accept / reject / defer / answer with a one-sentence reason, and report point by
point. Do not implement every remark blindly, and do not raise the bar for
rejecting security/correctness remarks.

## Separation of duties

The agent that wrote the code never approves it.

## Feedback loop

When a review flags the same mistake twice, the correction goes into `CLAUDE.md`
(or the relevant skill) in the same review. Review also flags when a change has
made `CLAUDE.md` or a skill outdated.

## Done when

Findings are tagged and citable, Important items are addressed, and a human code
owner has approved (or the findings are logged on the PR).
