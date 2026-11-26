# Figma fidelity

Frame = evidence, not contract. Check fit before coding against it. Used by [`align`](../align.md) and [`write-plan`](../../write-plan/write-plan.md).

## Ask

- UI task (`assess.sh` says `ui: true`, or ticket is UI work): ask one question: "Which Figma link(s) or frame(s) should this be coded against? `none` is fine."
- Spec Design sources already lists frames: reuse, don't re-ask.

## Read each frame

- Figma MCP tools present (`get_design_context`, `get_screenshot`, `get_metadata`): read every frame.
- Absent: ask human for each frame's key facts (layout, states, copy, components); mark authority anyway.

## Fidelity check (before planning)

List what frame shows vs ticket text:

| Look for | Examples |
|---|---|
| Missing states | empty, error, loading, disabled, hover, focus, mobile, long text |
| Copy | wording differs from ticket |
| Behavior not drawn | validation, navigation, persistence, analytics |
| Design system | tokens and components vs what repo ships |
| Staleness | frame looks like a different iteration |

Per frame, ask: **exactly right** · **right except `<items>`** · **reference only**. Unanswered → `partial`. Never assume `exact`.

## Record

Table in spec's Design sources; copy into plan as **Design source of truth**:

| Source | Authority | Agreed deviations | Open questions |
|---|---|---|---|
| frame link | exact, partial or reference | list or none | list or none |

| Authority | Implementer and reviewer |
|---|---|
| `exact` | pixel-authority |
| `partial` | follow agreed parts; ask about rest |
| `reference` | context only; ticket text and design system decide |

No design: write `None.` and drop the table.
