---
name: review-code-quality
description: Review a diff against the clean-code floor and docs rules, using the repo's scripts first. Use when review's stages.sh turns it on, or alone for "clean code check".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-code-quality

One stage of [review](../review/review.md). Findings use the format in [review](../review/review.md): severity (bug · suggestion · nit), stage id, `file:line`, description, fix. Read-only: never edit code.

## Check

- Run `skills/setup-repo/assets/scripts/code-quality-check.sh --range <base>..HEAD` and `lint-docs.sh <base>` where installed; each error is a finding, warnings are suggestions
- No added comments; names and extracted functions carry the meaning ([ban-comments](../../rules/ban-comments.md))
- Size and shape: file, function, parameter, and nesting limits; early returns; named helpers for try/catch
- No parameter mutation, magic numbers, or duplicated rules; touched files end smaller and quieter
- Docs are current-state or dated snapshots ([docs-current-or-dated](../../rules/docs-current-or-dated.md))

## Not here

Behavior (review-logic).
