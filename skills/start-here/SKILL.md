---
name: start-here
description: Route a task to the skill that fits. Use when the user says "start here", /start-here, "which skill", or is unsure which skill to run.
argument-hint: "[task]"
---

# Start here

Read [CATALOG.md](../CATALOG.md). Run one skill.

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
| The idea should ride the whole line | `apirvw` |
| User typed a chain alias (`apir`, `pirvw`) | That alias, unchanged |

`/apirvw` runs align through watch. `/apir` stops after verify. `/monitor` starts after production. Aliases only select stations. The long skill is the procedure. The default install is manifest `core` plus `support`. Design skills link when named, or with `--skills all`.
