# Verify the change

Put the proof in the pull request so a person or an agent can review it without reconstructing
the behavior from the diff. A sibling folder next to the plan holds the recipe (scripts) and a
short index of links. Binaries stay off git.

## Use as a skill

Symlink or copy this directory to the agent's skills folder, then ask it to verify the change
or to open the pull request. Alias: `/verify`. The description template is `assets/pr-body.md`.

Phase of the plan-implement-review chain: inserted between implement and review (`/pir`, `/apir`,
`/pirw`, …).

## What the reviewer gets

| Change | Proof |
| --- | --- |
| No runtime behavior (docs, comments, rename, formatting) | Build, and a **no behavior change** line. No screenshots or scripts |
| Build | The check command, the CI link for that commit, one green line |
| Screen, look | Before and after images |
| Screen, behavior | A short video |
| Backend | A curl, the same request as an HTTP file, the response, a trace or log |
| Database | A read-only query, the result, the migration or function name |
| Deep system change | A diagram of the path, and a video or stepped walkthrough when it is a sequence |
| Anything a command can show | A script next to the plan; stdout on the PR |

Pick the rows that prove this solution. Empty kinds is a pick, not a miss.

**Try it** is a numbered list the reviewer pastes or clicks. Each step says what they should see.

The **Review guide** tells the reviewer where to start, where to look hard, what to skim and what
is deliberately missing. Who may merge is the repo's merge policy (`ai-risk`); proof in the
description does not change it.
