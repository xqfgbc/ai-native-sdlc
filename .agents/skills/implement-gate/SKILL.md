---
name: implement-gate
description: Use in the control plane when a signed deterministic rule needs a gate. Claims the queue task, writes the one implementation under guardrails/, syncs it to appliesTo services, and closes with evidence.
---

# Implement a deterministic gate

A signed deterministic rule is a claim until a gate exists. The work lives in the control plane queue:
one task per rule, not one per service.

```bash
bash scripts/gate-queue.sh list --status open --json
bash scripts/gate-queue.sh claim G-<proposal-id> --owner ai-agent
```

## Write one implementation

Put the gate under `guardrails/<gate-id>/` with a manifest:

```json
{"id":"gate-<proposal-id>","proposalId":"<proposal-id>","appliesTo":["speaker"],
 "files":[{"src":"files/ProjectGateTest.java","dest":"src/test/java/.../ProjectGateTest.java"}],
 "evidence":"bash scripts/app-verify.sh test"}
```

Do **not** implement the same rule separately in each service. A project rule is authored once here;
services receive it through sync.

## Sync and close

```bash
bash scripts/sync-project-gates.sh . --check     # or --write
bash scripts/gate-queue.sh done G-<proposal-id> --evidence "ArchUnit ... + app-verify test"
bash scripts/validate-project.sh . --strict
```

`done` refuses while project gates are out of sync; `--strict` fails when a deterministic item has no
gate evidence or a manifest is not applied to every `appliesTo` service.
