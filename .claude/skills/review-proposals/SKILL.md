---
name: review-proposals
description: Use before signing knowledge proposals or when reviewing the backlog. Produces an AI recommendation with reasons and confidence; a human still signs.
---

# Review knowledge proposals

AI never activates a proposal. This skill prepares a judgement so the human gate is fast
and the AI's agreement rate can be measured over time.

## Steps

1. Run the deterministic pre-judgement:

   ```bash
   bash scripts/review-proposals.sh .
   ```

   It writes `knowledge/reviews/<proposal-id>.json` and `knowledge/reviews/SUMMARY.md` with:
   `suggestion` (`promote-deterministic | promote-advisory | defer | reject-duplicate`),
   `confidence` (`high|medium|low`), `risk`, `reasons`, `gateHits`, `service`, `repeatCount`.

2. Present the suggestion **as a suggestion**: quote the reasons, the evidence
   (`provenance`, `repeatCount`) and whether an existing gate already implements it.
   Never say "approved".

3. Deferrals: when the human says "later", register a debt item instead of leaving the
   proposal to rot:

   ```bash
   bash scripts/debt.sh add --kind proposal --source proposal --ref <proposal-id> \
     --title "<title>" --owner <human> --priority P2 --due <date>
   ```

4. Record the human decision (the sign-off UI does this automatically):

   ```bash
   bash scripts/review-proposals.sh record <proposal-id> \
     --decision promote-deterministic|promote-advisory|debt|reject --owner <human> [--note "…"]
   bash scripts/review-proposals.sh stats     # agreement rate, including high-risk slice
   ```

5. The human signs with `python3 scripts/signoff.py` (or `promote-proposal.sh`).
   After the agreement rate is high for advisory/low-risk items, policy may allow
   pre-filled one-click approval — deterministic and security items stay manual.

## Do not

- do not call `promote-proposal.sh` yourself;
- do not edit `knowledge/pack.json`;
- do not mark a proposal rejected without a human decision.
