---
name: review-code-quality
description: Review a diff against the clean-code floor and docs rules, using the repo's scripts first. Use when review's stages.sh turns it on, or alone for "clean code check".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-code-quality

One stage of [review](../review/review.md). Findings: format per [review](../review/review.md) (severity bug · suggestion · nit, stage id, `file:line`, description, fix). Read-only. Never edit code.

## Check

- Run `skills/setup-repo/assets/scripts/code-quality-check.sh --range <base>..HEAD` and `lint-docs.sh <base>` where installed. Error → finding. Warning → suggestion
- No added comments. Names and extracted functions carry meaning ([ban-comments](../../rules/ban-comments.md))
- Size and shape: file, function, parameter, nesting limits. Early returns. Named helpers for try/catch
- No parameter mutation, magic numbers, duplicated rules. Touched files end smaller and quieter
- Docs: current-state or dated snapshot ([docs-current-or-dated](../../rules/docs-current-or-dated.md))

## Not here

Behavior → review-logic.
