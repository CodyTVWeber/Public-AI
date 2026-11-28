---
name: review-proof
description: Check whether a PR/MR description proves the change (screenshots, video, script or query output, a short Try it pointer) per verify-change. Used by the verify phase, not a review stage. Usable alone for "does this PR prove itself".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-proof

Check for the [verify](../verify-change/verify-change.md) phase. Not a stage of [review](../review/review.md). Findings: format per [review](../review/review.md). Read-only.

## Check (blocking)

Follow [`verify-change`](../verify-change/verify-change.md). Description = the proof. Goal: a reviewer can look at it and say yes.

1. Plan path given → `skills/verify-change/scripts/check-pyramid.sh <plan>`. Exit 1 → each violation = bug-severity finding
2. `skills/plan-implement-review/scripts/diff-scope.sh <base> > scope.json`. Plan path given and sibling dir exists: merge `kinds.json` into scope (`jq --slurpfile k kinds.json '. + {kinds: $k[0].kinds}'`)
3. `skills/implement/scripts/proof-check.sh <body-file> scope.json`. Exit 1 → each `missing[]` item = bug-severity finding
4. Sibling dir exists → `skills/verify-change/scripts/check-evidence-dir.sh <dir>`. Exit 1 → each `missing[]` = bug. Docs-only or empty kinds with no dir is a pass
5. Evidence files on disk → `skills/implement/scripts/evidence-check.sh <files> --before <b> --after <a>`. Exit 1 → failed capture

Judge by eye what scripts can't:

| Check | Fail when |
|---|---|
| Build | The run is red |
| No product evidence | Diff has runtime behavior, or the "no behavior change" line is a lie |
| Look of a screen | Image blank or login wall, or before captured on the feature branch |
| Behavior | A click, type, motion, or sequence has no short video |
| Backend, Database | Response, trace, or result doesn't show the change, or database not named |
| Try it | More than two steps, or a walkthrough instead of a pointer (run this script; go to this URL and click these buttons) |

- Open every image. Play every video. Judge by eye, not filenames
- Any fail → `fix required`. Missing proof for a runtime change = bug-severity finding
- Empty `kinds` on a docs, comment, rename, or formatting diff is a pass
