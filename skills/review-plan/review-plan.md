---
name: review-plan
description: Review a branch against its plan: scope, unplanned files, plan steps done, out-of-scope respected, repo rules. Always runs as the first stage of review.
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-plan

One stage of [review](../review/review.md). Findings use the format in [review](../review/review.md): severity (bug · suggestion · nit), stage id, `file:line`, description, fix. Read-only: never edit code.

## Check

- Diff `git diff origin/<base>...HEAD` against the plan's Concrete steps and Out of scope
- Every plan step has code or a stated reason; every changed file maps to a step
- Unplanned files, drive-by refactors, and mixed concerns are findings (suggest a split when over the small-MR budget)
- The repo's own rules files (contributor and agent guidelines, lint and style configs) hold for the diff
- Docs touched are current-state or dated, per the repo's docs rule

## Not here

Correctness inside the code (review-logic) or proof (review-proof).
