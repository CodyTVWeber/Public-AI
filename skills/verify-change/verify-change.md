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

Before opening or updating the pull request, run `skills/verify-change/scripts/check-pr-body.sh <body-file>`.
It checks the body against `assets/pr-body.md` (headers, tier, merge policy line, Review guide and Build
labels, leftover placeholders, rollback for high tier, length). Exit 1 prints the `missing` list: fix it.

Who may merge is a separate decision: the repo's merge policy (`skills/ai-risk/rules/merge-policy.md`).
Proof in the description does not change it. Under `conservative` and `balanced`, a person
approves before anything but a low-tier change merges.

## Make the review a piece of cake

A reviewer should be able to say yes or no after reading the description and one pass through the
diff. The author does the orienting. Before asking for review:

1. **Lead with the answer.** What changed and why, in two sentences. Link the task for the full
   story; do not retell it
2. **Say where to start and where to look hard.** Fill **Review guide**: the one file that
   explains the change, the hunks that deserve care (`file:line` and why), and what to skim
   (generated, mechanical, moved). A reviewer should never have to guess where the risk is
3. **Say what is not here.** Out-of-scope items, follow-up MRs, and where they go, so nobody
   reviews for something that is deliberately absent
4. **Review your own diff first.** Read it as the reviewer, then fix or explain. Leave an inline
   comment on every hunk whose reason is not obvious from the code ("moved from X, no logic
   change", "this guard handles the empty case")
5. **Commits tell the story.** One logical change per commit, message says why. Mechanical
   moves and renames get their own commit so the reviewer can skim them
6. **Keep it small.** Over the budget in `small-mrs.md`: split first. A stack is ordered
   safest-first so the risky slice is the last and the smallest thing to read
7. **Name the risk and the exit.** Tier, who approves under the merge policy, and a rollback line.
   High tier without a rollback plan is not ready
8. **Make the proof runnable.** A reviewer who follows **Try it** and sees the stated result is done
   with behavior and can spend the rest of their time on design
9. **Ask a real question.** Under **Decisions to check**, put the one or two judgment calls you
   want a second opinion on. Reviewers engage more with a question than with a wall of code
10. **Keep the description short.** About 25 lines before the evidence. Put long output in
    `<details>` blocks. No narration of the diff: the diff shows that

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
- On GitLab, upload with `skills/implement/scripts/upload-evidence.py <project-id> <files>` (`--dry-run` validates first; exit 2 bad file, 4 upload failed). On other forges, attach in the description.
- Run `skills/implement/scripts/evidence-check.sh <files> --before <b> --after <a>` first: exit 1 (zero-byte, tiny, before = after) is a failed capture.
- Then open every image and play every video. A blank frame, an error page, or a login wall is a failed capture. Capture again.
- Before comes from a checkout of the base branch, built on its own. Not from this branch.
- Use fake or local data. Leave production rows, secrets, and real personal data out of the description.
- When the app cannot run in this environment, say so in the pull request and still leave Try it. Do not omit the section.

## Not ready for review

`skills/implement/scripts/proof-check.sh <body-file> <scope.json>` reports the mechanical items below (exit 1 lists `missing[]`).

- A behavior the diff touches with no proof row
- A still image standing in for a behavior
- A curl, query, or script the reviewer cannot run as written
- A deep change with no diagram of the path
- No **Review guide**: no start file, no look-hard hunks, or no out-of-scope line
- No tier, no merge policy quoted, or a high-tier change with no rollback line
- Proof that shows a failure. Fix the product and capture again.

## Reviewing

Read **What changed**, **Risk** and **Review guide**, then **Proof**, then run **Try it**. Open
the images and play the video. When Try it matches the claim, the behavior is shown. Then read the
diff in the order the guide gives, spending your time on the "look hard" hunks and skimming the
rest. Missing proof or a missing guide is a fix, not a nit.
