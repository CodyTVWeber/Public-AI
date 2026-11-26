# Figma fidelity

A design frame is evidence, not a contract. Check how far it is right before anyone codes against it. Used by [`align`](../align.md) and [`write-plan`](../../write-plan/write-plan.md).

## Ask

UI task (`assess.sh` says `ui: true`, or the ticket is UI work): one question, "Which Figma link(s) or frame(s) should this be coded against? `none` is fine." Spec Design sources already lists frames: reuse, do not ask again.

## Read each frame

Figma MCP tools present (`get_design_context`, `get_screenshot`, `get_metadata`): read every frame. Absent: ask the human for each frame's key facts (layout, states, copy, components) and mark authority anyway.

## Fidelity check (before planning)

List what the frame shows against the ticket text:

| Look for | Examples |
|---|---|
| Missing states | empty, error, loading, disabled, hover, focus, mobile, long text |
| Copy | wording that differs from the ticket |
| Behavior not drawn | validation, navigation, persistence, analytics |
| Design system | tokens and components versus what the repo ships |
| Staleness | a frame that looks like a different iteration |

Per frame, ask: **exactly right** · **right except `<items>`** · **reference only**. Unanswered means `partial`; never assume `exact`.

## Record

Table in the spec's Design sources, copied into the plan as **Design source of truth**:

| Source | Authority | Agreed deviations | Open questions |
|---|---|---|---|
| frame link | exact, partial or reference | list or none | list or none |

| Authority | Implementer and reviewer |
|---|---|
| `exact` | pixel-authority |
| `partial` | follow the agreed parts; ask about the rest |
| `reference` | context only; ticket text and the design system decide |

No design: write `None.` and drop the table.
