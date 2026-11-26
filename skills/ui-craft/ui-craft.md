---
name: ui-craft
description: Shape how a screen looks and moves - hierarchy, space, type, color, elevation, and a short motion budget. Use from ui, or when polishing look, motion, or visual consistency. Prefer the project's tokens.
argument-hint: "[screen or component]"
---

# Craft

How the screen looks and moves. The path is [ui-interaction](../ui-interaction/ui-interaction.md). A considered screen is treated as more usable. Decoration that does not serve the job comes off. Sources: [ui](../ui/ui.md#sources).

## Before drawing

- **Tokens and primitives first.** Read the project's components, type, color, space, radius, shadow, and motion. Compose from them
- Match two or three pieces on nearby screens
- A block in two places becomes a shared primitive. Pass the record. Use slots for chrome
- Theme is data. A color, radius, or duration that belongs to the theme is not a literal on the page
- A flourish lives on the component. Add a shared motion utility only when several components use that motion

## Hierarchy

- **One focal point.** Emphasize with two of size, weight, and color, not all three on every element
- To feature one thing, quiet the rest
- Body text is near-black on a near-white surface unless the tokens say otherwise. Gray text does not sit on a saturated fill
- Reading text stays in a measure of about 45 to 75 characters, and stays left aligned
- Large type uses a tighter line height. Small type uses a looser one

## Space and surface

- **Space from the project's scale.** With no scale, step by 4: 4, 8, 12, 16, 24, 32, 48, 64. Related items sit closer than unrelated groups
- Separate with space or a shift of surface. A border is the exception
- **One or two radii** on a screen. **One light direction** for shadow: resting, raised, overlay. A heavy shadow does not sit on every card

## Color

- **One accent** for the primary action and for links. Status colors are signals: success, warning, danger
- Contrast floors are in [ui-interaction](../ui-interaction/ui-interaction.md)
- Color is never the only signal

## Motion

Project tokens win. With none, use this budget.

| Token | Value | Use |
|---|---|---|
| fast | 150 ms | hover, press, color |
| base | 300 ms | panels, rows |
| slow | 500 ms | modal, sheet |
| standard | cubic-bezier(0.4, 0, 0.2, 1) | almost all motion |
| bounce | cubic-bezier(0.34, 1.56, 0.64, 1) | one celebratory pulse. Never a loop |

| Intent | Do | Skip |
|---|---|---|
| press | scale to about 0.98 and a small shadow | a ripple on every row, an icon that morphs for show |
| enter | fade, or fade plus about 8 px up | a fly-in from off screen, stagger delays as decoration |
| overlay | fade plus scale from about 0.95. A sheet has padding, radius, and shadow | frosted glass as the default |
| success | a soft color wash that settles | a row that flies to a distant icon |
| undo | a short reverse: fade and a few px back | a second celebration |
| negative | one brief flash, then a steady mark | shaking the page |
| celebration | one burst, then still. The outcome, or a short phrase, is the hero | a loop: wiggle, bounce, spin, or confetti that does not end |
| at a limit | one glow, only for that limit | glow on ordinary success |
| loading | skeleton shimmer in the content's shape | a spinner where the shape is known |
| primary moment | one shine, or a light bloom, on the single main control. Rare | shine on every button |
| reduced motion | durations collapse to a near-instant single pass | ignoring `prefers-reduced-motion` |

Meaning stays clear with motion off.

## When the look is a guess

Put two or three options in front of a person. Keep the pick. Write down the refusals so the next pass does not rebuild them.

## Self-check

- [ ] Tokens and nearby primitives, not a one-off look
- [ ] One focal point, one accent
- [ ] Space from the scale, one light, one or two radii
- [ ] Motion from the table. Reduced motion still communicates
