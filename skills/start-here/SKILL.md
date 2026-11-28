---
name: start-here
description: Route a task to the skill that fits. Use when the user says "start here", /start-here, "which skill", or is unsure which skill to run.
argument-hint: "[task]"
---

# Start here

Front door: root [README](../../README.md). Read it first. This skill routes.

Say `/idea-to-production` and the idea. That name spells the whole range. `/idea-to-prod` is the short form.

| You want | Say |
| --- | --- |
| Nothing on the line yet, and you want it working | `/build` |
| A run that ends with something shipped | `/deliver` |
| This run to move one station forward | `/advance` |

Stations one at a time: `/align` (A), `/plan` (P), `/implement` (I), `/review` (R), `/verify` (V), `/watch` (W), `/monitor` (M). String the letters for a range (`/apirvw` is A through W).

Then run one skill.

| Situation | Skill |
| --- | --- |
| Repo has no guardrails | `setup-repo` |
| Task is vague or large | `align` |
| Task is agreed | `write-plan`, then `implement` |
| Diff needs a verdict | `review` |
| PR is open | `watch` |
| Bug will not stay reproduced | `diagnosing-bugs` |
| Behavior change needs tests | `tdd` |
| Module shape is the question | `codebase-design` |
| The idea should ride the whole line | `/idea-to-production` |
| User typed a chain alias (`apir`, `pirvw`) | That alias, unchanged |

Aliases only select stations. The long skill is the procedure. Default install: manifest `core` plus `support`. Design skills link when named, or with `--skills all`. Full list: [CATALOG.md](../CATALOG.md).
