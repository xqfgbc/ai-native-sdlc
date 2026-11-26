---
name: requirements-and-design
description: Turn an accepted intent.md into a spec.md, applying brand/security/compliance/UX policy while writing. Use at Stage 2 (Design) after the product owner accepts the intent.
---

# Requirements and design

Stage 2 (Design). Collapse requirements and design into one pass that produces
`intent/<folder>/spec.md` beside `intent.md`. Policy is applied *while* the spec
is written — not discovered weeks later in review.

## Steps

1. Read the accepted `intent.md` and the current codebase.
2. Produce `spec.md` from `docs/spec-template.md`: functional + non-functional
   requirements, service topology, API contracts, data model changes, policy
   application, and **flagged areas of concern**.
3. Apply the organization's skills while writing: `secure-api-review`,
   `resiliency-review`, `spring-service-conventions`, and any brand/UX policy.
   Note the skill versions in force inside the spec.
4. Flag every concern explicitly — especially policy conflicts that cannot all be
   satisfied — and name the policy owner who must resolve each before engineering
   sees the spec.
5. Commit `spec.md` next to `intent.md` (message `spec(<slug>): requirements and design`).
   The file pair records what was asked for and what was decided.

## Governance

- The spec, the prompt that produced it, and the skill versions in force are all in
  version control.
- **A human (product owner) signs the spec**; flagged concerns are resolved with
  named policy owners first. Accepting the spec starts Stage 3 (plan mode).

## Done when

`spec.md` is committed alongside `intent.md`, open questions are answered or
carried forward, and the product owner has signed. Metrics: elapsed intent→spec;
spec rework after build starts (spec commits dated after the first plan.md).
