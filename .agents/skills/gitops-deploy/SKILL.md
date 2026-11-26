---
name: gitops-deploy
description: Ship a change through Flux CD GitOps across dev/uat/prod, respecting environment autonomy tiers and the production gate. Use at Stage 5 (Deploy) for any deployment change.
---

# GitOps deploy (Flux CD)

Stage 5 (Deploy). Deployment is GitOps: the **infra repo** is the source of truth
for what runs on AWS EKS, and Flux CD reconciles it. CI never `kubectl apply`s.

## Dual-repo topology

| Repo | Holds | Reconciled by |
|---|---|---|
| **app repo** (this one) | services, CI (build/test/lint → push ECR), skills/agents/hooks | — |
| **infra repo** | Flux CD manifests, Spring Cloud Config source (`config/`), ESO secrets | Flux CD |

## What CI does

1. Build, test, lint (GitHub Actions `collect.yml`).
2. Tag + push the image to ECR with a **sortable semver tag** (`v1.2.3`) and a
   short-sha tag.
3. Dev auto-follows the new image via Flux `ImagePolicy` (timestamp/sha); UAT and
   prod promote only via a **merged PR** that bumps the image tag in the infra
   repo overlay (`ImageUpdateAutomation` or a human/agent-opened PR).

## Environment autonomy tiers

- **dev** — agent deploys freely (Flux reconciles automatically).
- **uat** — agent prepares the release; promotion requires a merged tag-bump PR.
- **prod** — agent prepares the release; the **release manager authorizes**, and
  the `production-gate` hook + branch protection enforce it.

## Rollback

`make rollback SERVICE=<name> TAG=<last-good-tag>` follows the pre-approved
runbook `docs/runbook-rollback-deploy.md` (Flux `kubectl rollout undo`). Rollback
is the most rehearsed path; it is the only action the maintenance loop may
trigger at 3σ without a human.

## The governing principle

**The agent may act up to the production gate and cannot pass it.**

## Done when

The change is reconciled in the target environment(s) by Flux, and (for prod)
the release manager has authorized it.
