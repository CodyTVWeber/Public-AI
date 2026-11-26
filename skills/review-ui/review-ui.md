---
name: review-ui
description: Review a UI diff: fidelity to the agreed design, accessibility, and states. Use when review's stages.sh turns it on (UI files), or alone for "review the UI".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-ui

One stage of [review](../review/review.md). Findings: format per [review](../review/review.md) (severity bug · suggestion · nit, stage id, `file:line`, description, fix). Read-only. Never edit code.

## Check

- Pixel authority only for frames the plan's Design source of truth marks `exact` ([figma-fidelity](../align/references/figma-fidelity.md)). Matching a `partial` or `reference` frame beyond agreed parts = finding
- Keyboard reachability, focus order and visibility, labels, roles, alt text, contrast
- Empty, loading, error, long-text, narrow-screen states exist
- Copy and tokens from the design system, not literals
- Making bar for the same diff: [ui-interaction](../ui-interaction/ui-interaction.md) and [ui-craft](../ui-craft/ui-craft.md). A miss is a suggestion unless it blocks the job or fails a check above
- Interactions that move or animate have a video in the description (review-proof checks it)

## Not here

Backend behavior behind the screen → review-logic.
