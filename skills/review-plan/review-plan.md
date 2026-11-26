---
name: review-plan
description: Review a branch against its plan: scope, unplanned files, plan steps done, out-of-scope respected, repo rules. Always runs as the first stage of review.
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-plan

One stage of [review](../review/review.md). Findings: format per [review](../review/review.md) (severity bug · suggestion · nit, stage id, `file:line`, description, fix). Read-only. Never edit code.

## Check

- Diff `git diff origin/<base>...HEAD` against the plan's Concrete steps and Out of scope
- Every plan step has code or a stated reason. Every changed file maps to a step
- Unplanned files, drive-by refactors, mixed concerns → findings (suggest split when over small-MR budget)
- Repo rules files (contributor and agent guidelines, lint and style configs) hold for the diff
- Docs touched: current-state or dated, per repo docs rule

## Not here

Correctness in code → review-logic. Proof → review-proof.
