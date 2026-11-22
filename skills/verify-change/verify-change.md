---
name: verify-change
description: Prove a change in the pull request so a person or an agent can review it quickly. Use when opening or updating a PR or MR, when the user asks to verify the build, or when attaching screenshots, videos, traces, queries, or repro steps.
argument-hint: "[PR/MR number or branch]"
---

# Verify the change

The pull request is the review. A person or an agent should be able to see that the change works
from the description, then re-run it in a few minutes. The diff explains how it is built. The
description proves the behavior.

Fill `assets/pr-body.md`. Every sentence in **What changed** has a row in **Proof**. Every Proof
row has a **Try it** step that is one paste or one click.

AI auto-merge is a separate switch and defaults to off. Proof in the description does not turn
it on. `skills/ai-risk/rules/automerge.md`.

## Build

Always include this, including for a docs-only change that has a check command.

- The one command the project uses (`npm test`, or whatever the repo documents)
- The link to the CI run for this commit
- One line of green output

The reviewer re-runs that command. A red or missing run is not ready.

## What to attach

Match the proof to the kind of change. Use every row the diff touches.

| Kind | In the pull request |
| --- | --- |
| How a screen looks | Before and after images. Before is a build of the base branch. After is this branch. The changed element is in the frame. Mobile width unless the screen is desktop-only. |
| How a screen behaves | A short video. Click, type, motion, and any multi-step flow are behavior. Start at the action and stop at the result. An image does not cover a behavior. |
| Backend | The call that hits the change, as a curl and as the same request in an HTTP file a client can import (Postman, Bruno, or the project's own). The status and the response fragment that show the new behavior. A trace or log line with its correlation id. When a screen calls it, the video of that screen too. |
| Database | A read-only query the reviewer pastes, and the result that shows the new row or shape. The migration or function name. Before and after of those rows when data changes. Which database: local or the preview, named in the step. |
| Deep or wide system change | A diagram in the description of the path the request takes, with the new hop marked. Mermaid is enough. When the path is a sequence, a short video or a stepped diagram that walks the same steps as Try it. One short paragraph: what moved, what stayed. |

A backend or database change that a person can reach through the product uses the screen video
as well as the call, the log, or the query. The video shows the trigger. The call, log, or query
shows the effect.

## Try it

Numbered steps. Copy-paste. Each step says what the reviewer should see.

- The preview link, or the one command that starts the app locally
- The curl for each changed request
- The HTTP file, inlined or attached
- The read-only SQL, and which database it runs against
- When the proof is more than one command, one script in the PR and the single line that runs it

A reviewer who follows Try it and sees the stated result has verified the behavior. They should
not have to invent setup, find a port, or guess a payload.

## Capture

- Keep evidence files out of the git tree. Attach them to the pull request so the forge hosts them.
- On GitLab, upload with `skills/implement/scripts/upload-evidence.py`. On other forges, attach in the description.
- Open every image and play every video before uploading. A blank frame, an error page, a login wall, or a before that matches the after is a failed capture. Capture again.
- Before comes from a checkout of the base branch, built on its own. Not from this branch.
- Use fake or local data. Leave production rows, secrets, and real personal data out of the description.
- When the app cannot run in this environment, say so in the pull request and still leave Try it. Do not omit the section.

## Not ready for review

- A behavior the diff touches with no proof row
- A still image standing in for a behavior
- A curl, query, or script the reviewer cannot run as written
- A deep change with no diagram of the path
- Proof that shows a failure. Fix the product and capture again.

## Reviewing

Read **What changed**, then **Proof**, then run **Try it**. Open the images and play the video.
When Try it matches the claim, the behavior is shown. Then read the diff for how it is built.
Missing proof is a fix, not a nit.
