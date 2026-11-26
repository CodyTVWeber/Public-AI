---
name: review-proof
description: Review whether a PR/MR description proves the change (build, screenshots, video, curls, queries, Try it steps) per verify-change. Always runs as the last stage of review; usable alone for "does this PR prove itself".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-proof

One stage of [review](../review/review.md). Findings: format per [review](../review/review.md). Read-only.

## Check (blocking)

Follow [`verify-change`](../verify-change/verify-change.md). Description = the review.

1. `skills/plan-implement-review/scripts/diff-scope.sh <base> > scope.json`, then `skills/implement/scripts/proof-check.sh <body-file> scope.json`. Exit 1 → each `missing[]` item = bug-severity finding (headings, build, review guide, tier, rollback, curl/http/query/image/diagram counts)
2. Evidence files on disk → `skills/implement/scripts/evidence-check.sh <files> --before <b> --after <a>`. Exit 1 → failed capture

Judge by eye what scripts can't:

| Check | Fail when |
|---|---|
| Build | The run is red |
| Look of a screen | Image blank or login wall, or before captured on the feature branch |
| Behavior | A click, type, motion, or sequence has no short video |
| Backend, Database | Response, trace, or result doesn't show the change, or database not named |
| Try it | Reviewer cannot re-run the proof from the description in a few minutes |

- Open every image. Play every video. Judge by eye, not filenames
- Any fail → `fix required`. Missing proof = bug-severity finding
