---
name: ai-risk
description: Classify a change by risk, decide who may merge it, when an agent must stop, and which changes may auto-merge. Use when an agent is about to ship, merge, apply a database, open a follow-up pull request, or keep working past the asked slice.
---

# AI risk

Who may merge, who may apply a database, when an agent stops, and what may auto-merge.
A pull request takes the **highest** tier it touches.

These files are the rules. Read the one that decides the question. Do not restate it from memory,
and do not let a plan, a chat, or a "ship it" override them.

| Decision | File |
| --- | --- |
| Tier of each path, who may merge, who may apply the database | `rules/risk-tiers.md` |
| Who may ask an agent to continue, and when the agent stops | `rules/agent-stops.md` |
| What may merge with no second person, and when host auto-merge is real | `rules/automerge.md` |
| How an agent ships, and what it leaves alone on a live system | `rules/shipping.md` |

Stack order (safest slice first) lives in `skills/setup-clean-code/assets/rules/small-mrs.md`.
That file orders the stack. This skill decides who may merge each slice. An additive migration
can sit in the middle of a stack and still be high for who-merges, because the migrator applies it.

## Before editing

1. List the paths the task will touch.
2. Give each path a tier from `rules/risk-tiers.md`. The pull request's tier is the highest.
3. If the ask is owner-only and the person asking is not the owner, stop. `rules/agent-stops.md`.
4. Do that one slice. Open one pull request. Stop.
5. Merge only when `rules/automerge.md` or the tier's approver allows it.

## Adopt in another repo

Copy `rules/` to `docs/rules/` and point the project's agent guide at those four files.
Where the project already has a stricter rule, keep the stricter one.
