# Verify the change

Put the proof in the pull request so a person or an agent can review it without reconstructing
the behavior from the diff.

## Use as a skill

Symlink or copy this directory to the agent's skills folder, then ask it to verify the change
or to open the pull request. The description template is `assets/pr-body.md`.

## What the reviewer gets

| Change | Proof |
| --- | --- |
| Build | The check command, the CI link for that commit, one green line |
| Screen, look | Before and after images |
| Screen, behavior | A short video |
| Backend | A curl, the same request as an HTTP file, the response, a trace or log |
| Database | A read-only query, the result, the migration or function name |
| Deep system change | A diagram of the path, and a video or stepped walkthrough when it is a sequence |

**Try it** is a numbered list the reviewer pastes or clicks. Each step says what they should see.

AI auto-merge stays off unless the repo, team, or org turns it on. Proof in the description is
not that switch.
