---
name: review
description: Read-only review of an implement branch or PR/MR against its plan, then the final regression gate. Checks the description proves the change (images, video, curls, queries, Try it steps) per verify-change. Use for "review this", /review, or the review phase of plan-implement-review-watch.
argument-hint: "[PR/MR number | branch] [plan path]"
---

# Review

Read-only. Never edit code here; findings go back to the implementer. Host CLI: `gh` or `glab`, whichever the repo uses.

## 1. Review

1. Diff the branch against the base (`git diff origin/<base>...HEAD`) and the plan's Concrete steps / Out of scope
2. Prefer a project review skill if one exists; else structured findings: severity (bug · suggestion · nit), `file:line`, description, fix
3. Check the repo's own rules files (contributor/agent guidelines, lint and style configs) against the diff
4. Styling-only change → snapshot/test diffs must be class-string or structure only

## 2. Proof check (blocking)

Follow [`verify-change`](../verify-change/verify-change.md). The description is the review.

| Check | Fail when |
|---|---|
| Build | No check command, no CI link for this commit, or the run is red |
| Look of a screen | A changed screen has no before/after pair, the image is blank or a login wall, before matches after, or before was captured on the feature branch |
| Behavior | A click, type, motion, or sequence has no short video |
| Backend | No copy-paste curl (and HTTP file when the call has a body or headers), no response snippet, no trace or log |
| Database | No read-only query and result, or the database isn't named |
| Deep change | No diagram of the path |
| Try it | A reviewer cannot re-run the proof from the description in a few minutes |
| Review guide | The description has no start file, no look-hard hunks, no out-of-scope line, no tier with the merge policy quoted, or (high tier) no rollback line |
| Attached | Proof is missing from the PR/MR description |

- Open every image and play every video. Judge by eye, not filenames
- Any fail → `fix required`; missing proof is a bug-severity finding
- Docs-only with no runtime behavior → Build plus "no behavior change", and skip the media rows

## 3. Verdict

| Verdict | Next |
|---|---|
| approve | Regression gate (§4) |
| fix required, rounds left | Write `/tmp/pir-<topic>/review-roundN.md`; orchestrator resumes the same implementer agent |
| fix required, rounds spent | Stop; hand findings + implementer id to the user; skip §4 |

## 4. Regression gate (after approve; required)

1. Command: the repo's documented system-regression / end gate. None exists → `regression: skipped (no script)`; run lint + typecheck + unit tests on the branch tip instead
2. Run on the branch tip, clean tree. Fail → `regression: failed`; treat as `fix required` with the log tail
3. Never call a run merge-ready without a pass or an explicit user skip
4. Failures identical on the base branch are pre-existing: report, don't block

## Output

Verdict · findings table · evidence check result · regression status. ≤ 15 lines unless findings need more.
