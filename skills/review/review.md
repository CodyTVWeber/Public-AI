---
name: review
description: Read-only review of an implement branch or PR/MR against its plan, then the final regression gate. Checks UI changes have before/after screenshots proving them. Use for "review this", /review, or the review phase of plan-implement-review-watch.
argument-hint: "[PR/MR number | branch] [plan path]"
---

# Review

Read-only. Never edit code here; findings go back to the implementer. Host CLI: `gh` or `glab`, whichever the repo uses.

## 1. Review

1. Diff the branch against the base (`git diff origin/<base>...HEAD`) and the plan's Concrete steps / Out of scope
2. Prefer a project review skill if one exists; else structured findings: severity (bug · suggestion · nit), `file:line`, description, fix
3. Check the repo's own rules files (contributor/agent guidelines, lint and style configs) against the diff
4. Styling-only change → snapshot/test diffs must be class-string or structure only

## 2. UI evidence check (blocking)

Diff touches UI (screens, styling, icons, copy, layout, motion)?

| Check | Fail when |
|---|---|
| Evidence exists | A changed screen/state has no before/after pair (and no stated reason) |
| It's real | An image is blank, errored, a login wall, or before = after |
| It proves the change | The changed element isn't visible, or the viewport isn't mobile for a mobile flow |
| Before is from base | Before already shows the new behaviour (captured from the feature branch) |
| Attached | The PR/MR description lacks a `## Screenshots` table |

- Open every image; judge by eye, not filenames
- Any fail → `fix required`; missing evidence is a bug-severity finding
- No UI change → note "no UI change" and skip

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
