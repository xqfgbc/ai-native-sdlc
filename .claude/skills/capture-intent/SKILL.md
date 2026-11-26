---
name: capture-intent
description: Capture a new idea, ticket, or incident as intent.md in the originator's own words. Use at Stage 1 (Plan) whenever a change is requested but has no committed intent yet.
---

# Capture intent

Stage 1 (Plan). Produce the first artifact of the loop: `intent/<date>-<slug>/intent.md`,
written from the originator's own words — never invented or padded.

## Steps

1. Ask the analyst questions, in plain language: what can't be done today, who is
   affected, what "better" looks like, and what is explicitly out of scope.
2. Brainstorm until the idea is concrete: scope, users, constraints, success criteria.
3. Write `intent.md` from `intent/TEMPLATE.md`, preserving the originator's own
   constraints. Do not add constraints the originator or policy did not state.
4. Ask the originator to correct anything misunderstood before commit.
5. Commit `intent/<YYYY-MM-DD>-<slug>/intent.md` with message
   `intent(<slug>): capture <title>`. The slug is kebab-case and stable — it is
   the change ID used in every later commit.

## House rules (intent/README.md)

- Anyone may file an intent; non-engineers commit through an agent connector or a PR.
- A **product owner** accepts or rejects; the decision is the merge or the closing
  review. Accepted intent triggers Stage 2.
- Maintenance findings enter here too with `Source: maintenance-loop`.

## Done when

The intent is committed, the author and timestamp are in git history, and the
product owner has accepted it. Metrics: time first-conversation → committed
intent.md (hours, not weeks).
