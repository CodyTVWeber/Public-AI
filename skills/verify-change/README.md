# Verify the change

Put the proof in the pull request so a person or an agent can look at it and say yes
without reconstructing the behavior from the diff. Own stage after review, before watch
(PIRVW / APIRVW). A sibling folder next to the plan holds the recipe (scripts) and a
short index of links. Binaries stay off git.

## Use as a skill

Symlink or copy this directory to the agent's skills folder, then ask it to verify the change
or to open the pull request. Alias: `/verify`. The description template is `assets/pr-body.md`.

Phase of the plan-implement-review chain: inserted after review (`/pir`, `/apir`, `/pirw`,
`/pirvw`, …). Not a review stage.

## What the reviewer gets

Lead with evidence. Then one or two lines that point at how to re-run. Nothing more.

| Change | Proof |
| --- | --- |
| No runtime behavior (docs, comments, rename, formatting) | Build, and a **no behavior change** line. No screenshots or scripts |
| Build | The check command, the CI link for that commit, one green line |
| Screen, look | Before and after images |
| Screen, behavior | A short video |
| Backend | Script or command output (status, response fragment) |
| Database | A read-only query and the result |
| Anything a command can show | A script next to the plan; stdout on the PR |

Pick the rows that prove this solution. Empty kinds is a pick, not a miss.

**Try it** points at the scenario: run this script, or go to this URL and click these buttons.
It does not dump every step.

The **Review guide** tells the reviewer where to start, where to look hard, what to skim and what
is deliberately missing. Who may merge is the repo's merge policy (`ai-risk`); proof in the
description does not change it.
