# Tracker progress comments

When the work came from a **tracker task** (Asana or equivalent), post progress as **comments on that task**. No task, no comments.

**Task-tracker comments are the source of truth** for progress and prior attempts. Read them **before starting**. Reuse an existing plan/PR they point to rather than starting over.

The old single “AI first attempt done; needs review” comment after implement round 1 is **superseded**. Post **one comment per phase milestone** instead.

write-plan, implement, and code-review **reference this file**. Do not fork a second format.

## Rules (identical for Plan, Implement, Review)

- **Short:** max ~3–4 lines. No walls of AI text; the thread stays human-centric.
- **Format:** which step ran (`Plan` / `Implement rN` / `Review rN`), status (`done` / `blocked` / `needs review`), links (plan PR, implement PR), and anything a human must act on. Nothing else.
- **One comment per phase milestone**, never per command.
- **Comments only.** Never otherwise edit, reassign, complete, or change the tracker task.

The skill that **finishes** the milestone posts the comment. A parent `/plan-implement-review` orchestrator posts only if the child skill did not. Never two comments for the same milestone.

## When to comment

| Milestone | Who | First line (example) |
|-----------|-----|----------------------|
| Plan PR exists | write-plan / PIR Phase A | `Plan — done` |
| Implement round N finished | implement / PIR Phase B | `Implement r1 — done, needs review` |
| Review round N finished | code-review / PIR Phase C | `Review r1 — done` |

Blocked work uses `blocked` and names the human action. Skip the comment if there is no tracker task.

## Example

```
Implement r1 — done, needs review
PR: <link>
Human action: confirm the store email before merge.
```
