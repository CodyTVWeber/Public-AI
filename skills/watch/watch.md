---
name: watch
description: Watch a PR/MR until its pipeline is green and review threads are quiet; fix real failures, report threads, never merge. Use for "watch the MR/PR", /watch, or the final phase of plan-implement-review-watch.
argument-hint: "<number> [fix-comments=yes|no]"
---

# Watch

Self-paced loop on one PR/MR. Host CLI: `gh` or `glab`. Branch and clone path come from the orchestrator; verify `git branch --show-current` before any git write.

## Each tick (read-only)

GitLab: `glab mr view <n>`, `glab ci status --branch <b>`, `glab api "projects/:id/merge_requests/<n>/discussions"`.
GitHub: `gh pr view <n>`, `gh pr checks <n>`, `gh api repos/{owner}/{repo}/pulls/<n>/comments`.

Unresolved human threads only: system notes and bot summaries are not threads.

## React

| Seen | Do |
|---|---|
| Pipeline running | Wait |
| Failed, looks like a flake | Read the job log, retry once |
| Failed, real | Hand the log to the implementer (same agent), re-run the review regression gate, push. Counts as a fix round |
| New unresolved human thread | Tell the user: author, `file:line`, ask. Fix only with `fix-comments=yes` |
| Bot thread (security/quality scanners) | Report counts; fix only findings inside this diff |
| Push rejected / remote force-updated | Never force-push. Backup branch, reset to remote, cherry-pick new commits, recheck, push fast-forward |
| Evidence changed (new UI work) | Re-upload and refresh the description's Screenshots table |

## Cadence and budget

| Item | Rule |
|---|---|
| Running pipeline | Wake ~5 min later |
| Green, waiting on humans | ≥ 20 min |
| Fix rounds | Max 2, separate from the implement loop's 3. Still red → hand off with the failing log |
| Quiet ticks | Say nothing. Report only state changes, ≤ 3 lines |

## Stop when

Merged or closed · pipeline green and zero unresolved human threads (report "ready for review") · user says stop · budget spent. A wakeup that fires after the stop: one read-only check, end, don't reschedule.

## Never

- Merge, approve, mark ready, or force-push without being asked
- Resolve a thread a person opened unless asked
- Post externally without an attribution prefix (e.g. `🤖 _Posted by <AI assistant> (AI) on behalf of @<user>_`)
- Re-title with a second `Draft:` prefix (`--draft` already adds it)

## Report

PR/MR URL · last pipeline state · unresolved threads (count, who) · fix rounds used.
