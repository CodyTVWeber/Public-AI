---
name: review-logic
description: Review the main-path logic of a diff: does the code do what the plan and acceptance criteria say. Use when review's stages.sh turns it on (enough added non-test code), or alone for "check the logic".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-logic

One stage of [review](../review/review.md). Findings: format per [review](../review/review.md) (severity bug · suggestion · nit, stage id, `file:line`, description, fix). Read-only. Never edit code.

## Check

- Each acceptance criterion → code that satisfies it
- Control flow, conditions, off-by-one, ordering, state transitions, return values correct
- Names match behavior. One definition per business rule; no duplicated predicates
- Changed signatures, defaults, shared helpers: every caller still holds
- Remove dead code, unreachable branches, leftovers from earlier approaches

## Not here

Error paths and boundaries → review-non-happy-logic. Tests → review-tests.
