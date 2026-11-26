---
name: review-triage
description: Respond to code review feedback (PR comments, review threads, bot/code-reviewer findings) without implementing everything blindly — verify each remark, accept/partly accept/reject/defer it with a reason, then report point by point. Use when asked to address review comments.
---

# Review triage

Review remarks are **hypotheses, not orders**. Before changing code in response to
feedback, decide for each remark whether it is right, and say so. This skill holds
the decision rules and the reply format. The review itself is the `pr-review`
skill; project rules are `AGENTS.md` / `CLAUDE.md` / the skills.

## When to use

- "address the review comments" / "fix the PR feedback".
- A new comment, review, or inline remark on a pull request.
- Findings from the `pr-reviewer`/`security-auditor` agents about to be implemented.

## Process

1. **Split** the feedback into separate points. One remark = one decision.
   Questions are answered, not implemented.
2. **Verify** each point in the code before judging: read the cited file and line
   and the change (`git diff <base>...HEAD`). Check the problem exists, that a
   later commit has not fixed it, and that the suggestion does what the reviewer thinks.
3. **Check the rules.** The repo wins: `AGENTS.md`, `CLAUDE.md`, `REVIEW.md`, and the
   skills override a generic suggestion.
4. **Decide** with one of the outcomes below.
5. **Report** in the format below. Implement only what was accepted.

## Outcomes

| Outcome | When |
|---|---|
| **Accept** | The problem is real, in scope, and the fix is consistent with repo rules |
| **Partly accept** | Part of the remark holds; do that part and name what you left |
| **Reject** | Factually wrong, already handled, contradicts a repo rule, out of scope, or cost far above gain |
| **Defer** | Valid but out of scope: no code change; suggest a follow-up issue |
| **Answer** | A question or request for explanation: reply, no code change |

## Rules

- **Evidence over deference.** Reject only with a one-sentence reason you can
  point to in the code or a rule. If unsure, say what you checked and what is unclear.
- **Raise the bar for rejecting safety.** Security, data-loss and correctness
  remarks need concrete evidence to reject; when in doubt, take the careful fix.
- **Keep to scope.** Do not widen the change for a hint of a larger refactor; use Defer.
- **Humans can overrule.** If a human explicitly repeats a rejected request,
  implement it unless it breaks security or a hard rule; then say which rule.
- **Bots are no more authoritative than humans.** Verify them the same way.
- **Do not argue.** Reasons are one factual sentence; no defensiveness or filler.
- **Tests follow the change.** An accepted remark that changes behavior updates its test.

## Output format

When the caller prescribes a format, use it. Otherwise:

**Plan (before implementing):**

```markdown
### Implementation plan
- [ ] concrete step, in order (code, tests)

### Not doing
- "short name" — reason in one sentence
```

Write `_No code changes._` when nothing was accepted, `_Nothing skipped._` when
nothing was left out.

**Reply (after implementing), one bullet per remark:**

```markdown
- **Done** — "remark": what changed
- **Partly done** — "remark": what changed, what was left and why
- **Not done** — "remark": reason
- **Follow-up** — "remark": suggested issue title
```

Finish with the test result and anything a reviewer should look at.
