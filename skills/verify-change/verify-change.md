---
name: verify-change
description: Prove a change in the pull request so a person or an agent can review it quickly. Use when opening or updating a PR or MR, when the user asks to verify the build, or when attaching screenshots, videos, traces, queries, or repro steps.
argument-hint: "[PR/MR number or branch]"
---

# Verify the change

The PR is the review. Reader sees the change works from the description, then re-runs it in minutes. Diff = how it is built. Description = proof of behavior.

- Fill `assets/pr-body.md`. Every **What changed** sentence → a **Proof** row. Every Proof row → a **Try it** step (one paste or one click)
- Before opening or updating the PR: `skills/verify-change/scripts/check-pr-body.sh <body-file>`
  - Checks headers, tier, merge-policy line, Review guide and Build labels, leftover placeholders, rollback for high tier, length
  - Exit 1 prints the `missing` list → fix it
- Who may merge: separate decision under the merge policy (`skills/ai-risk/rules/merge-policy.md`). Proof does not change it
- `conservative` and `balanced`: a person approves before anything but a low-tier change merges

## Make the review a piece of cake

Reviewer says yes or no after the description and one pass through the diff. Author does the orienting. Before asking for review:

1. **Lead with the answer.** What changed and why, in two sentences. Link the task for the full story; do not retell it
2. **Say where to start and where to look hard.** Fill **Review guide**: the one file that explains the change, hunks that deserve care (`file:line` and why), what to skim (generated, mechanical, moved). Reviewer never guesses where the risk is
3. **Say what is not here.** Out-of-scope items, follow-up MRs, and where they go
4. **Review your own diff first.** Read it as the reviewer, then fix or explain. Inline comment on every hunk whose reason is not obvious from the code ("moved from X, no logic change")
5. **Commits tell the story.** One logical change per commit; message says why. Mechanical moves and renames get their own commit
6. **Keep it small.** Over budget in `small-mrs.md`: split first. A stack is safest-first, so the risky slice is last and smallest to read
7. **Name the risk and the exit.** Tier, who approves under the merge policy, rollback line. High tier without rollback plan is not ready
8. **Make the proof runnable.** Reviewer who follows **Try it** and sees the stated result is done with behavior
9. **Ask a real question.** Under **Decisions to check**: one or two judgment calls you want a second opinion on
10. **Keep the description short.** ~25 lines before evidence. Long output in `<details>` blocks. No diff narration

## Build

Always include, even for a docs-only change that has a check command.

- The one command the project uses (`npm test`, or what the repo documents)
- Link to the CI run for this commit
- One line of green output

Reviewer re-runs that command. Red or missing run = not ready.

## What to attach

Match proof to the kind of change. Use every row the diff touches.

| Kind | In the pull request |
| --- | --- |
| How a screen looks | Before and after images. Before = build of the base branch; after = this branch. Changed element in frame. Mobile width unless desktop-only |
| How a screen behaves | Short video. Click, type, motion, multi-step flows are behavior. Start at the action, stop at the result. An image does not cover a behavior |
| Backend | The call that hits the change: curl, and the same request in an HTTP file a client can import (Postman, Bruno, or project's own). Status and response fragment showing the changed behavior. Trace or log line with correlation id. When a screen calls it, that screen's video too |
| Database | Read-only query the reviewer pastes, and the result showing the added row or shape. Migration or function name. Before and after of those rows when data changes. Which database: local or preview, named in the step |
| Deep or wide system change | Diagram of the request path with the changed hop marked. Mermaid is enough. Sequence path: short video or stepped diagram walking the same steps as Try it. One short paragraph: what moved, what stayed |

Backend or database change a person reaches through the product also uses the screen video. Video shows the trigger; call, log, or query shows the effect.

## Try it

Numbered steps. Copy-paste. Each step says what the reviewer should see.

- Preview link, or the one command that starts the app locally
- The curl for each changed request
- The HTTP file, inlined or attached
- The read-only SQL, and which database it runs against
- More than one command: one script in the PR and the single line that runs it

Reviewer who follows Try it and sees the stated result has verified the behavior. No invented setup, port hunting, or guessed payloads.

## Capture

- Keep evidence files out of the git tree. Attach to the PR so the forge hosts them
- GitLab: `skills/implement/scripts/upload-evidence.mjs <project-id> <files>` (`--dry-run` validates first; exit 2 bad file, 4 upload failed). Other forges: attach in the description
- Run `skills/implement/scripts/evidence-check.sh <files> --before <b> --after <a>` first. Exit 1 (zero-byte, tiny, before = after) = failed capture
- Open every image and play every video. Blank frame, error page, or login wall = failed capture; capture again
- Before = checkout of the base branch, built on its own. Not this branch
- Fake or local data only. No production rows, secrets, or real personal data
- App cannot run here: say so in the PR and still leave Try it. Do not omit the section

## Not ready for review

`skills/implement/scripts/proof-check.sh <body-file> <scope.json>` reports these mechanically (exit 1 lists `missing[]`):

- Behavior the diff touches with no proof row
- Still image standing in for a behavior
- Curl, query, or script the reviewer cannot run as written
- Deep change with no path diagram
- No **Review guide**: no start file, no look-hard hunks, or no out-of-scope line
- No tier, no merge policy quoted, or high tier with no rollback line
- Proof showing a failure: fix the product, capture again

## Reviewing

Read **What changed**, **Risk**, **Review guide**, then **Proof**, then run **Try it**. Open the images, play the video. When Try it matches the claim, behavior is shown. Read the diff in guide order: "look hard" hunks get the time, the rest is skimmed. Missing proof or guide = fix, not nit.
