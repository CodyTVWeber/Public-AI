---
name: review-ui
description: Review a UI diff: fidelity to the agreed design, accessibility, and states. Use when review's stages.sh turns it on (UI files), or alone for "review the UI".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-ui

One stage of [review](../review/review.md). Findings use the format in [review](../review/review.md): severity (bug · suggestion · nit), stage id, `file:line`, description, fix. Read-only: never edit code.

## Check

- Pixel-authority only for frames the plan's Design source of truth marks `exact` ([figma-fidelity](../align/references/figma-fidelity.md)); matching a `partial` or `reference` frame beyond the agreed parts is a finding
- Keyboard reachability, focus order and visibility, labels, roles, alt text, contrast
- Empty, loading, error, long-text, and narrow-screen states exist
- Copy and tokens come from the design system, not literals
- Interactions that move or animate have a video in the description (review-proof checks it)

## Not here

Backend behavior behind the screen (review-logic).
