---
name: watch-mr-pipeline
description: Watch a PR/MR pipeline on a schedule, auto-fix simple lint/format/test failures, merge the target branch in when behind, and stop when the pipeline is green or the PR/MR is merged or closed. Use for "watch this MR", "babysit the pipeline", /watch-mr-pipeline.
argument-hint: "<pr-or-mr number | branch>"
---

# Watch a PR/MR pipeline

`$ARGUMENTS` = PR/MR number, or a branch name to resolve to one. Host CLI: `gh` (GitHub) or `glab`
(GitLab), whichever the repo's `origin` uses. Runs as a recurring job; each run is cheap and ends
with at most one line of report.

## Setup (once)

1. Detect host and project from `git remote get-url origin`
2. Resolve the argument to a PR/MR number; none found → say so and stop
3. Confirm the CLI works (`gh pr view <n>` / `glab mr view <n>`); missing or unauthenticated → stop
4. Find a local clean clone on the PR/MR branch for fixes; none → watch read-only and report only
5. Schedule a recurring job (every ~5 minutes, off the :00/:30 marks) running the loop below. Tell
   the user: job id, interval, that it deletes itself when done, and that it is session-only

## Each run

1. **State.** Merged or closed → report once, delete the job, stop
2. **Behind target.** If the branch is behind and has no conflicts (see Merge rules): merge the
   target in, push normally, report one line, end this run (the push starts a new pipeline)
3. **Pipeline.**
   - running or pending → one-line status, end the run
   - success → run the quality gate check if the repo has one configured, then **delete the job
     and stop**; the work is done
   - failed → read the failed job logs, decide if the fix is in scope (below); fix, commit, push
     and keep watching, or report the failure once and keep watching
4. **Quality gate (optional).** If the repo uses a static-analysis service with a PR gate, read the
   gate result; fix new in-scope issues, report the rest. No service configured → skip silently

## Merge rules (target into the branch)

Always merge, never rebase: rebasing rewrites history and breaks stacked branches. Merge only when
all hold: behind target; no conflicts; author is not a bot that owns its branch (e.g. a dependency
updater: report "behind" instead); clean local clone; fewer than 3 merges by this watch; user did
not say "no merge". Conflicts → `git merge --abort`, report "behind with conflicts: needs manual
merge", keep watching. After a merge+push: `merged <target> into <branch> (n of 3)`.

## Fix scope

Fix on your own: mechanical failures with an obvious cause (formatting, lint, unused or missing
imports, stale snapshots, one-line type errors, trivial analyzer warnings). Leave for a human:
anything that needs design judgment, new behavior, security review, or access to CI infrastructure.
Verify the branch (`git branch --show-current`) before every git operation; push to the branch
explicitly; never force-push.

## Housekeeping

Each run, delete leftover watch jobs for PRs/MRs that are merged or closed.
