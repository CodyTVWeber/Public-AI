---
name: review-code-quality
description: Review a diff against the clean-code floor and docs rules, using the repo's scripts first. Use when review's stages.sh turns it on, or alone for "clean code check".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-code-quality

One stage of [review](../review/review.md). Findings: format per [review](../review/review.md) (severity bug · suggestion · nit, stage id, `file:line`, description, fix). Read-only. Never edit code.

## Check

- Run `skills/setup-repo/assets/scripts/code-quality-check.sh --range <base>..HEAD` and `lint-docs.sh <base>` where installed. Error → finding. Warning → suggestion. That script owns file size, function order, length, params, nesting, guard wraps, comments, magic numbers, mutation
- AI judges only the gaps the script leaves: one definition per business rule, names that match docs, which extraction is the right boundary ([clean-code](../../rules/clean-code.md))
- Docs: current-state or dated snapshot ([docs-current-or-dated](../../rules/docs-current-or-dated.md))

## Not here

Behavior → review-logic.
