---
name: ai-risk
description: Classify a change by risk, decide who may merge it, and when an agent must stop. AI auto-merge is off unless the repo, team, or org explicitly turns it on. Use when an agent is about to ship, merge, apply a database, open a follow-up pull request, or keep working past the asked slice.
---

# AI risk

Who may merge, who may apply a database, and when an agent stops. AI auto-merge is off unless the repo, team, or org turns it on.
A pull request takes the **highest** tier it touches.

These files are the rules. Read the one that decides the question. Do not restate it from memory,
and do not let a plan, a chat, or a "ship it" override them.

| Decision | File |
| --- | --- |
| Tier of each path, who may merge, who may apply the database | `rules/risk-tiers.md` |
| Who may ask an agent to continue, and when the agent stops | `rules/agent-stops.md` |
| Whether an agent may auto-merge (default off) | `rules/automerge.md` |
| How an agent ships, and what it leaves alone on a live system | `rules/shipping.md` |

Stack order (safest slice first) lives in `skills/setup-clean-code/assets/rules/small-mrs.md`.
That file orders the stack. This skill decides who may merge each slice. An additive migration
can sit in the middle of a stack and still be high for who-merges, because the migrator applies it.

## Before editing

1. List the paths the task will touch.
2. Give each path a tier from `rules/risk-tiers.md`. The pull request's tier is the highest.
3. If the ask is owner-only and the person asking is not the owner, stop. `rules/agent-stops.md`.
4. Do that one slice. Open one pull request. Stop.
5. Leave the pull request for a person to merge. An agent auto-merges only when `rules/automerge.md` is explicitly on.
6. Put the proof in the pull request with the `verify-change` skill.

## Adopt in another repo

Copy `rules/` to `docs/rules/` and `assets/ai-automerge.md` to `docs/rules/ai-automerge.md`.
That file ships as `AI auto-merge: off`. Point the project's agent guide at those files.
Where the project already has a stricter rule, keep the stricter one.
