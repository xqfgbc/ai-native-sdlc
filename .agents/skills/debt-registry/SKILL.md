---
name: debt-registry
description: Use when work is deferred (busy, blocked, out of scope) or a retro/review leaves an action. Records, lists and closes project debt across intent, design, build, test, deploy, ops and security.
---

# Debt registry

The project keeps one debt registry in the control plane:

```
<control-plane>/loop/07-maintain/debt/debt.json
```

A service repo resolves the control plane from `.sdlc/config.json` (`managementRepo`),
so the same command works everywhere.

## When to add debt

- a proposal you cannot decide on now (kind `proposal`, source `proposal`, ref = proposal id);
- an unresolved retro action (kind by area, source `retro`);
- a known gap you deliberately postpone (kind `tech|test|ops|security|intent|...`, source `manual|incident|review`);
- work that is out of scope but must not be forgotten.

Do **not** use debt as a parking lot for active work: if it is being done now, it is a task, not debt.

## Rules

- Every item has `kind`, `title`, `priority (P1|P2|P3)`, `owner`, `due`.
- `P1` = correctness/security/production risk; `P2` = planned improvement; `P3` = nice to have.
- AI may `add`, `note`, `start`. **Closing or dropping requires evidence** (linked check/commit) or a human.
- Re-check `due` every session and at retro; overdue P1 must be escalated, not silently extended.

## Commands

```bash
bash scripts/debt.sh add --kind tech --title "…" --priority P2 --owner <you> \
  --due YYYY-MM-DD --source retro|proposal|incident|review|manual --ref <id> --detail "…"
bash scripts/debt.sh list [--status open] [--kind tech] [--json]
bash scripts/debt.sh due [--days 7] [--json]
bash scripts/debt.sh start <id> [--owner <you>]
bash scripts/debt.sh note <id> --text "…"
bash scripts/debt.sh close <id> --note "evidence: <commit/check>"
bash scripts/debt.sh drop <id> --why "…"
bash scripts/debt.sh report [--out loop/07-maintain/debt/DUE.md]
```

Run `debt.sh due` at the start of maintenance work and at every retro; the scheduled
`knowledge-review` workflow also writes `loop/07-maintain/debt/DUE.md`.
