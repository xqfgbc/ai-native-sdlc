---
name: retro-to-rule
description: Use after a retro, incident or repeated finding to turn conclusions into checkable rules, gates, tests or debt — not just another paragraph of prose.
---

# Retro → rule

A retro outcome is only done when it is checkable or registered. Use
`loop/07-maintain/retro-template.md`.

## Classify each finding

| Finding | Artifact |
|---|---|
| Hard invariant (security, architecture, contract, compliance) | hook / ArchUnit / lint / CI / policy-as-code |
| Process requirement | skill + `CLAUDE.md`/`AGENTS.md`, escalate to a gate if repeated |
| Fact/context | `knowledge/context` or wiki (not enforceable) |
| Regression | failing test first, then fix; keep the test |
| Unresolved action | debt registry item with owner and due date |

## Turn it into a check

1. Rewrite as falsifiable: "X must fail" — if you cannot describe the detection, it is advice, not a rule.
2. Choose the cheapest effective layer: `PreToolUse → pre-commit → pre-push → CI → runtime`.
3. Implement the check and **two tests**: a violating fixture must be blocked, a valid one must pass
   (add them to `scripts/selftest.sh`, `evals/`, or the repo's test suite).
4. Wire it into `hooks/`, `.githooks/`, `templates/` so new repos inherit it; sync existing repos.
5. Record `knowledge/guardrails/<id>.md` via a deterministic promotion; remove the stub once the gate exists.
6. Measure: hits, false positives, bypasses. Retire noisy gates.

## Output (per finding)

```
finding:
evidence:        commit/report/log links
rule:            "must/never …"
check:           command or gate that fails on violation
layer:           PreToolUse|pre-commit|pre-push|CI|runtime
owner:
debt (if any):   debt id + due
verification:    positive + negative fixture output
```
