---
name: watch-mr-pipeline
description: Watch a PR/MR pipeline on a schedule, auto-fix simple lint/format/test failures, report when the branch is behind its target, and stop when the pipeline is green or the PR/MR is merged or closed. Use for "watch this MR", "babysit the pipeline", /watch-mr-pipeline.
argument-hint: "<pr-or-mr number | branch>"
---

# Watch a PR/MR pipeline

Scheduled variant of [`watch`](../watch/watch.md). **Policy from `watch`**: never merge, approve, mark ready, or force-push; never push (fix commit or target merge-in) without user confirmation unless the run pre-authorized pushes. This file adds only scheduling and fix scope.

`$ARGUMENTS` = PR/MR number or branch name. Scripts: `skills/plan-implement-review/scripts/` (repo-root-relative). Each run is cheap; ends with ≤1 report line.

## Setup (once)

1. `forge-ctx.sh` → host, cli, project, `clean`, `branch`. Exit 3 → stop
2. Number: the argument, else `pr-find.sh <branch>` → `head_pr.number`. None → say so, stop
3. `mr-state.sh <n>` must exit 0 (3 = CLI missing or unauthenticated → stop)
4. Fixes need a clean local clone on the PR/MR branch. None → watch read-only, report only
5. Schedule a recurring job (~5 min, off the :00/:30 marks) running the loop below. Tell the user: job id, interval, deletes itself when done, session-only

## Each run

`mr-state.sh <n>`, then act on `next` (and `state`):

| Seen | Do |
|---|---|
| `state` merged or closed | Report once, delete job, stop |
| `wait` | One-line status, end run |
| `fix_ci` | `ci-failure-tail.sh <n>`. In scope (below) → fix, commit, push per policy, keep watching. Else report once, keep watching |
| `reply_threads` | Report author and `file:line`. Fix only if asked |
| `rebase_needed` | `git fetch origin <target>`, `branch-behind.sh origin/<target>`. Conflicts → "behind with conflicts: needs manual merge". Else report "behind N"; merge the target in only with confirmation (rules below). Keep watching |
| `done` (green, no human threads) | Run quality gate check if the repo has one (static-analysis service with a PR gate: fix new in-scope issues, report the rest; none configured → skip silently). Then delete job, stop |

## Merge-in rules (target into branch, after confirmation)

- Always merge, never rebase: rebase rewrites history and breaks stacked branches
- Only when all hold: `conflicts` false; branch author not a bot owning its branch (e.g. dependency updater: report "behind" instead); clean local clone; fewer than 3 merges by this watch; user did not say "no merge"
- Push normally. The push starts a new pipeline; end run. Report `merged <target> into <branch> (n of 3)`

## Fix scope

- Fix alone: mechanical failures with an obvious cause (formatting, lint, unused or missing imports, stale snapshots, one-line type errors, trivial analyzer warnings)
- Leave for a human: design judgment, behavior change, security review, CI infrastructure access
- Verify `git branch --show-current` before every git operation. Push to the branch explicitly. Never force-push

## Housekeeping

Each run: delete leftover watch jobs for PRs/MRs that are merged or closed.
