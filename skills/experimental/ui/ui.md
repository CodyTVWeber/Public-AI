---
name: ui
description: Experimental. Build or change a screen so a person can finish one job and the screen looks considered. Use when adding or changing UI, polishing a page, or when the user says /ui, beautiful, lovable, or design this screen. Hands the path to ui-interaction and ui-craft. Lives in skills/experimental.
argument-hint: "[screen or component]"
---

# UI

A person can finish one job. The screen looks considered.

## When

- A screen, component, or flow is added or changed
- Polish, "beautiful", "lovable", `/ui`
- A read-only pass is [review-ui](../../review-ui/review-ui.md)

## Order

1. **Read the project.** Primitives, tokens, theme. Name two or three similar pieces and compose from them. The second copy of a block becomes a shared primitive
2. **[Interaction](../ui-interaction/ui-interaction.md).** Job, primary action, feedback, errors, states, access
3. **[Craft](../ui-craft/ui-craft.md).** Hierarchy, space, color, motion
4. **Fidelity.** A frame is pixel authority only when the plan marks it `exact` ([figma-fidelity](../../align/references/figma-fidelity.md)). `partial` and `reference` do not override the project system
5. **Proof.** Motion that travels gets a short recording ([verify-change](../../verify-change/verify-change.md))

## Screen note

End the reply with every line filled.

```
Job:
Primary:
States:
Motion:
Refused:
Primitives:
```

## Sources

Project tokens and components win when they conflict with the defaults below. The defaults are the public bars, plus a motion budget taken from a production gallery (shipped motion kept, rejected motion written down) and stated here without that product's names.

| Bar | From |
|---|---|
| Status, real-world words, undo and a clear exit, consistency, prevention, recognition, shortcuts, only what the job needs, errors a person can fix, help beside the task | [Nielsen, 10 heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/) |
| Familiar patterns, large close targets, fewer choices, chunking, reply under 400 ms, the peak and the ending, beauty felt as usability, complexity kept in the system, accept messy input, one thing that stands out, grouping | [Laws of UX](https://lawsofux.com/) |
| One primary verb in sentence case, warning style only for serious irreversible harm plus a confirm, keep answers, error summary and the same words beside the field, focus on the summary | [GOV.UK button](https://design-system.service.gov.uk/components/button/), [error summary](https://design-system.service.gov.uk/components/error-summary/), [validation](https://design-system.service.gov.uk/patterns/validation/) |
| Text contrast 4.5 to 1. Large text, and the mark that identifies a control, 3 to 1 | [WCAG contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum), [non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast) |
| Hit area at least 44 pt, and a press state on every custom control | [Apple HIG, buttons](https://developer.apple.com/design/human-interface-guidelines/buttons) |
| Hit area at least 48 dp, with space between targets | [Android touch targets](https://support.google.com/accessibility/android/answer/7101858) |
| Hierarchy, a spacing scale, quiet chrome, few borders, one light | [Refactoring UI](https://www.refactoringui.com/), Wathan and Schoger |
| Affordance, signifier, mapping, feedback, constraint | Don Norman, The Design of Everyday Things |
