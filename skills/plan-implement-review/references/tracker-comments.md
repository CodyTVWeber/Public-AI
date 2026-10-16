# Tracker progress comments

When the work came from a **tracker task** (e.g. Asana), post progress as comments on that task. **No task, no comments.**

This file is the canonical format and rules for Plan, Implement, and Review. Sibling skills ([write-plan](../../write-plan/write-plan.md), [implement](../../implement/implement.md), [code-review](../../code-review/SKILL.md)) **reference** this file — do not copy the rules into those skills.

## Rules

Identical in every phase:

- **Short and scannable:** max ~3–4 lines. No walls of AI text; the comment thread stays human-centric.
- **Format:** which step ran (`Plan` / `Implement rN` / `Review rN`), status (`done` / `blocked` / `needs review`), links (plan PR, implement PR), and anything a human must act on. Nothing else.
- **One comment per phase milestone**, never per command.
- **Comments are the source of truth** for progress and prior attempts. Read them before starting; reuse an existing plan/PR they point to rather than starting over.
- **Comments only.** Never otherwise edit, reassign, complete, or change the tracker task.

A single “AI first attempt done; needs review” comment after implement round 1 is **superseded** — post at each phase milestone instead.

## Example

```
Implement r1 — done, needs review
PR: <link>
Human action: confirm the vendor email for the site before merge.
```
