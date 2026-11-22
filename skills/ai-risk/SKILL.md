---
name: ai-risk
description: Classify a change by risk, apply the organization's chosen merge policy (conservative, balanced or yolo), and know when an agent must stop. Use when an agent is about to ship, merge, open a pull request, or touch migrations, CI, auth, dependencies or agent rules.
---

# AI risk

Three questions, three files. The organization picks the answer to the middle one.

| Decision | File |
| --- | --- |
| How risky is each path, and which change steps are safe | `rules/risk-tiers.md` |
| Who may merge each tier, and who may apply to a live data store. **The organization's choice** | `rules/merge-policy.md` |
| When the agent stops, and what it leaves alone | `rules/agent-stops.md`, `rules/shipping.md` |

A pull request takes the **highest** tier it touches. Do not restate these files from memory, and
do not let a plan, a chat, or a "ship it" override them.

## Merge policy in one table

| Profile | Approval |
| --- | --- |
| `conservative` (default) | Another person approves every change, at every tier. Agents never merge on their own |
| `balanced` | Low: a person merges. Medium: a second person approves. High: the designated owner only |
| `yolo` | None. The agent merges |

The repo declares it in `docs/rules/ai-merge-policy.md` (`Merge policy: <profile>`). No file, an
unknown value, or a policy the agent cannot quote means `conservative`.

Stack order (safest slice first) lives in `../setup-clean-code/assets/rules/small-mrs.md`. That
file orders the stack; the tier and the policy decide who merges each slice.

## Before editing

1. Read the repo's merge policy. Quote its source in the pull request
2. List the paths the task will touch and give each a tier. The pull request's tier is the highest
3. If the ask needs the designated owner and they did not make it, stop (`rules/agent-stops.md`)
4. Do that one slice. Open one pull request with the `verify-change` body. Stop
5. Merge only as the active policy allows. Under `conservative` that means never alone

## Adopt in another repo

Copy `rules/` to `docs/rules/` and `assets/ai-merge-policy.md` to `docs/rules/ai-merge-policy.md`,
then set the profile. Point the project's agent guide at those files. Where the project already
has a stricter rule, keep the stricter one.
