---
name: incident-to-intent
description: Turn a control-band breach or incident into a diagnosis and a new intent.md, routing through the loop. Use at Stage 6 (Maintain).
---

# Incident to intent

Stage 6 (Maintain). The loop closes: a control-band breach (or ticket/channel
alert) invokes the agent headlessly, and the finding re-enters the pipeline as a
new `intent.md`.

## Detection is deterministic (no model)

- A version-controlled script watches metrics with a rolling baseline (mean +
  stddev, Western Electric rules) — `config/bands.yaml` defines the tiers:
  - **1σ** — log only.
  - **2σ** — invoke the agent read-only to diagnose.
  - **3σ** — the agent may act only by opening a PR into the review gate or
    triggering a pre-approved runbook (`runbook:rollback-deploy`).

## Steps

1. Diagnose: gather the anomaly + evidence, affected systems, and open questions.
2. Write the finding as `intent/<YYYY-MM-DD>-<slug>/intent.md` with
   `Source: maintenance-loop`, using the Stage 1 format.
3. Route: product-facing findings go to the product owner; the service owner
   triages (fix now / schedule / dismiss). Dismissals tune the bands.
4. When the fix ships, add an **eval case** for this incident class
   (`evals/tasks/`) so the same class is protected going forward.

## Guardrails

- The agent never applies a production fix outside the review gate.
- Runbooks the agent may trigger were pre-approved; rollback is the only 3σ
  action without a human.

## Done when

The diagnosis is committed as `intent.md`, triaged, and (when fixed) backed by a
new eval case. Metrics: breach→intent time; findings→merged fixes; repeat
incidents of the same class.
