---
name: review-logic
description: Review the main-path logic of a diff: does the code do what the plan and acceptance criteria say. Use when review's stages.sh turns it on (enough added non-test code), or alone for "check the logic".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-logic

One stage of [review](../review/review.md). Findings use the format in [review](../review/review.md): severity (bug · suggestion · nit), stage id, `file:line`, description, fix. Read-only: never edit code.

## Check

- Each acceptance criterion maps to code that satisfies it
- Control flow, conditions, off-by-one, ordering, state transitions, and return values are right
- Names match behavior; one definition per business rule; no duplicated predicates
- Changed signatures, defaults, and shared helpers: every caller still holds
- Dead code, unreachable branches, and leftovers from earlier approaches are removed

## Not here

Error paths and boundaries (review-non-happy-logic), tests (review-tests).
