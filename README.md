# Public AI

Personal public pack of agent skills, plus the scripts and hooks that enforce the floors. Generic tech only. [MIT](LICENSE).

Skills tell an agent when to run and how to read a result. Scripts decide the checks they implement.

## Install

| Goal | Do |
| --- | --- |
| Rules on your own machine | Follow [AI-setup](AI-setup/README.md) |
| Floors in another repo | `skills/setup-repo/scripts/detect-repo.sh <repo>`, then `bootstrap.sh <repo>` |

Omit `--skills` and the links are manifest `core` plus `support`. Aliases and design skills stay opt-in: `--skills core+aliases`, `--skills all`, or a comma list.

## Start

`/start-here`, or align, then plan, then implement, then review.

## Failure modes

| Failure | Skill |
| --- | --- |
| Agent and human disagree | [align](skills/align/SKILL.md) |
| The change has no checked plan | [write-plan](skills/write-plan/SKILL.md), [implement](skills/implement/SKILL.md), [review](skills/review/SKILL.md) |
| The code works and the shape is mud | [codebase-design](skills/codebase-design/SKILL.md) and `code-quality-check.sh` |
| Tests lock the wrong thing | [tdd](skills/tdd/SKILL.md) |
| A bug has no loop | [diagnosing-bugs](skills/diagnosing-bugs/SKILL.md) |
| The repo has no floor | [setup-repo](skills/setup-repo/SKILL.md) |

## Catalog

[skills/CATALOG.md](skills/CATALOG.md) lists every skill once. `scripts/lint/check-skill-catalog.sh` fails when that list, the manifest, and `SKILL.md` names disagree.

## Operator manual

[AGENTS.md](AGENTS.md). Rules: [rules/](rules/README.md).
