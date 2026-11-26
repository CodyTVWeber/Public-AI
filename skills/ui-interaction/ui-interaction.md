---
name: ui-interaction
description: Shape how a person moves through a screen - one job, one primary action, feedback, undo, empty loading error and success, forms, hit targets, keyboard. Use from ui, or when a flow feels hard, confusing, or easy to mis-tap.
argument-hint: "[screen or flow]"
---

# Interaction

How a person finishes the job. Order of work: [ui](../ui/ui.md). Look and motion: [ui-craft](../ui-craft/ui-craft.md). Sources live on [ui](../ui/ui.md#sources).

## Job

- **One job** per screen, in a sentence a person would say
- Two jobs: split, or mark one primary and tuck the other
- **Their words**, not internal names

## Action

- **One primary.** The label is the verb of the outcome, sentence case: "Save and continue", "Pay". Not "Submit" or "OK"
- **Large and close** to where the thumb or pointer already is. Full width on a narrow screen. On a wide form, align it with the fields
- Secondary actions stay quiet. A warning style is only for serious harm that is hard to undo, plus a confirm step that names the object. Do not rely on color alone
- **Press state** on every custom control. That control shows pending at once. Ignore a second press while the first is in flight, and still guard the server
- Prefer a sentence that says why an action is unavailable over a disabled control that says nothing

## Path

- **Show the options.** Recognition, not memory. The label stays visible. A placeholder is a hint, not the label
- **The control sits by the thing it changes**
- **Chunk** with headings. A rare path stays closed until asked
- **A familiar control** for a familiar job. Invent one only when the platform has none
- Put unavoidable complexity in the system: defaults, computed values, fewer questions. Do not ask for a fact the screen already holds
- **Accept messy input** when it is unambiguous. Be strict about what is stored and shown
- A shortcut may exist for the expert. The visible path stays
- **Keep what they typed** if they leave and come back
- A job with steps shows progress

## Feedback

- **Status is visible** without a hunt
- Acknowledge the press immediately. If the work outlasts a short beat, show progress on that control. The back-and-forth stays under 400 ms, or the screen shows that it is working
- **Undo** for a reversible act. A clear exit for a flow. Confirm only when undo cannot repair it
- **The peak and the ending** are designed. The strongest moment and the done state are calm and specific, then still

## Errors

- **Prevent** the costly miss: constraints, good defaults, a confirm on the act that cannot be undone
- Plain language: what went wrong, how to fix it. A code is not the message
- A form shows a summary at the top and the same words beside the field. Focus moves to the summary. Their answers stay filled in
- Color is not the only signal

## States

Also cover long text, a narrow width, and a reason when an action is unavailable.

| State | Shows |
|---|---|
| empty | what is missing, why, and the one action that fills it |
| loading | a skeleton in the shape of the content when that shape is known; a spinner only when it is not |
| error | what failed, how to retry, input kept |
| success | the outcome, then a still state. One burst is enough. It does not loop |
| long text | wraps. It does not spill off the screen |
| narrow | the primary job is reachable without horizontal scroll |

## Access

- **Keyboard** reaches every control. Focus order matches the visual order. The focus ring is visible
- **Name, role, and a text alternative** on controls and on images that carry meaning
- **Contrast:** text at least 4.5 to 1 against its background. Large text, and the boundary or icon that identifies a control, at least 3 to 1. Inactive controls and logos are exempt
- **Hit area** at least 44 px on a side. 48 when the project follows Material. Space between neighbors so the areas do not overlap
- **Reduced motion:** honor the OS setting. The budget is in [ui-craft](../ui-craft/ui-craft.md). Meaning never depends on motion alone
- Help sits beside the field, only where the job is unfamiliar, and lists the steps
