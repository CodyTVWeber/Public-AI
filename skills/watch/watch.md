---
name: watch
description: Watch a PR/MR until its pipeline is green and review threads are quiet; fix real failures, report threads, never merge. Use for "watch the MR/PR", /watch, or the final phase of plan-implement-review-watch.
argument-hint: "<number> [fix-comments=yes|no]"
---

# Watch

Self-paced loop on one PR/MR. Host CLI: `gh` or `glab`. Branch and clone path come from the orchestrator; verify `git branch --show-current` before any git write.

## Each tick (read-only)

`skills/plan-implement-review/scripts/mr-state.sh <n>` → JSON; act on `next`. `threads.human_unresolved` already drops system notes and bot summaries. Helpers: `ci-failure-tail.sh <n> [job]` (failed job log tail), `branch-behind.sh origin/<target>` (after `git fetch origin <target>`). Exit 3 = CLI missing or unauthenticated: stop and tell the user.

## React

| `next` / seen | Do |
|---|---|
| `wait` | Wait |
| `fix_ci`, looks like a flake | Read `ci-failure-tail.sh`, retry once |
| `fix_ci`, real | Hand the log to the implementer (same agent), re-run the review regression gate, push. Counts as a fix round |
| `reply_threads` | Tell the user: author, `file:line`, ask. Fix only with `fix-comments=yes` |
| `threads.bot_count` > 0 | Report counts; fix only findings inside this diff |
| `rebase_needed` | Report behind N / conflicts (`branch-behind.sh`). Never merge the target in or push without user confirmation. If confirmed: merge, never rebase |
| Push rejected / remote force-updated | Never force-push. Backup branch, reset to remote, cherry-pick new commits, recheck, push fast-forward |
| Evidence changed | Re-upload and refresh Build, Proof, and Try it in the description |
| `done` | Stop (below) |

## Cadence and budget

| Item | Rule |
|---|---|
| Running pipeline | Wake ~5 min later |
| Green, waiting on humans | ≥ 20 min |
| Fix rounds | Max 2, separate from the implement loop's 3. Still red → hand off with the failing log |
| Quiet ticks | Say nothing. Report only state changes, ≤ 3 lines |

## Stop when

`next` is `done`: merged or closed, or pipeline green with zero unresolved human threads (report "ready for review") · user says stop · budget spent. A wakeup that fires after the stop: one read-only check, end, don't reschedule.

## Never

- Merge, approve, mark ready, force-push, or push a target merge-in without being asked
- Resolve a thread a person opened unless asked
- Post externally without an attribution prefix (e.g. `🤖 _Posted by <AI assistant> (AI) on behalf of @<user>_`)
- Re-title with a second `Draft:` prefix (`--draft` already adds it)

## Report

PR/MR URL · last pipeline state · unresolved threads (count, who) · fix rounds used.
