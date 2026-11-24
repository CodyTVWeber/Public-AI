---
name: watch-mr-pipeline
description: Watch a PR/MR pipeline on a schedule, auto-fix simple lint/format/test failures, report when the branch is behind its target, and stop when the pipeline is green or the PR/MR is merged or closed. Use for "watch this MR", "babysit the pipeline", /watch-mr-pipeline.
argument-hint: "<pr-or-mr number | branch>"
---

# Watch a PR/MR pipeline

Scheduled variant of [`watch`](../watch/watch.md). **Policy comes from `watch`**: never merge, approve, mark ready, or force-push; never push (fix commit or target merge-in) without user confirmation unless the run pre-authorized pushes. This file adds only scheduling and fix scope.

`$ARGUMENTS` = PR/MR number, or a branch name. Scripts live in `skills/plan-implement-review/scripts/` (repo-root-relative). Each run is cheap and ends with at most one line of report.

## Setup (once)

1. `forge-ctx.sh` → host, cli, project, `clean`, `branch`. Exit 3 → stop
2. Number: the argument, else `pr-find.sh <branch>` → `head_pr.number`; none → say so and stop
3. `mr-state.sh <n>` must exit 0 (3 = CLI missing or unauthenticated → stop)
4. Fixes need a clean local clone on the PR/MR branch; none → watch read-only and report only
5. Schedule a recurring job (every ~5 minutes, off the :00/:30 marks) running the loop below. Tell the user: job id, interval, that it deletes itself when done, and that it is session-only

## Each run

`mr-state.sh <n>`, then act on `next` (and `state`):

| Seen | Do |
|---|---|
| `state` merged or closed | Report once, delete the job, stop |
| `wait` | One-line status, end the run |
| `fix_ci` | `ci-failure-tail.sh <n>`; in scope (below) → fix, commit, push per policy, keep watching; else report once, keep watching |
| `reply_threads` | Report author and `file:line`; fix only if asked |
| `rebase_needed` | `git fetch origin <target>`, `branch-behind.sh origin/<target>`. Conflicts → "behind with conflicts: needs manual merge". Else report "behind N"; merge the target in only with confirmation (rules below). Keep watching |
| `done` (green, no human threads) | Run the quality gate check if the repo has one (static-analysis service with a PR gate: fix new in-scope issues, report the rest; none configured → skip silently), then delete the job and stop |

## Merge-in rules (target into the branch, after confirmation)

Always merge, never rebase: rebasing rewrites history and breaks stacked branches. Only when: `conflicts` is false; branch author is not a bot that owns its branch (e.g. a dependency updater: report "behind" instead); clean local clone; fewer than 3 merges by this watch; user did not say "no merge". Push normally, end the run (the push starts a new pipeline), report `merged <target> into <branch> (n of 3)`.

## Fix scope

Fix on your own: mechanical failures with an obvious cause (formatting, lint, unused or missing imports, stale snapshots, one-line type errors, trivial analyzer warnings). Leave for a human: anything needing design judgment, new behavior, security review, or access to CI infrastructure. Verify `git branch --show-current` before every git operation; push to the branch explicitly; never force-push.

## Housekeeping

Each run, delete leftover watch jobs for PRs/MRs that are merged or closed.
