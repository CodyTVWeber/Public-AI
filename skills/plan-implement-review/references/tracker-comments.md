# Tracker progress comments

Work from **tracker task** (Asana or equivalent): post progress as **comments on that task**. No task, no comments.

**Task-tracker comments are source of truth** for progress and prior attempts. Read before starting. Reuse existing plan/PR they point to.

write-plan, implement, code-review **reference this file**. Don't fork a second format.

## Rules (identical for Plan, Implement, Review)

- **Short:** max ~3–4 lines. No walls of AI text. Thread stays human-centric.
- **Format:** step (`Plan` / `Implement rN` / `Review rN`), status (`done` / `blocked` / `needs review`), links (plan PR, implement PR), anything a human must act on. Nothing else.
- **One comment per phase milestone**, never per command.
- **Comments only.** Never otherwise edit, reassign, complete, or change tracker task.

The skill that **finishes** the milestone posts the comment. Parent `/plan-implement-review` orchestrator posts only if child skill didn't. Never two comments for same milestone.

## When to comment

| Milestone | Who | First line (example) |
|-----------|-----|----------------------|
| Plan PR exists | write-plan / PIR Phase A | `Plan — done` |
| Implement round N finished | implement / PIR Phase B | `Implement r1 — done, needs review` |
| Review round N finished | code-review / PIR Phase C | `Review r1 — done` |

Blocked work: status `blocked`, names the human action. No tracker task → skip comment.

Body: `skills/plan-implement-review/scripts/tracker-comment.sh <Plan|Implement rN|Review rN> <status> <url> [human-action]` prints lines below (never posts). Exit 2 = bad step/status/url, or `blocked` without human action.

## Example

```
Implement r1 — done, needs review
PR: <link>
Human action: confirm the store email before merge.
```
